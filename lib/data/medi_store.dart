import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';

/// Local-only persistence for Medi Tracker, backed by Hive.
///
/// One process-wide instance ([MediStore.instance]). Boxes are exposed so the
/// UI can rebuild reactively via `box.listenable()`; the helper methods hold
/// the small amount of query logic that benefits from a single home.
class MediStore {
  MediStore._();
  static final MediStore instance = MediStore._();

  static const _medsBoxName = 'medications';
  static const _logsBoxName = 'dose_logs';

  late final Box<Medication> _meds;
  late final Box<DoseLog> _logs;

  bool _ready = false;

  Box<Medication> get medicationsBox => _meds;
  Box<DoseLog> get logsBox => _logs;

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MedicationAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(DoseLogAdapter());
  }

  /// Opens Hive and the typed boxes. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _registerAdapters();
    _meds = await Hive.openBox<Medication>(_medsBoxName);
    _logs = await Hive.openBox<DoseLog>(_logsBoxName);
    _ready = true;
  }

  /// Test-only init: uses an explicit on-disk [path] instead of the
  /// platform path_provider plugin (unavailable in the test VM).
  Future<void> initForTesting(String path) async {
    if (_ready) return;
    Hive.init(path);
    _registerAdapters();
    _meds = await Hive.openBox<Medication>(_medsBoxName);
    _logs = await Hive.openBox<DoseLog>(_logsBoxName);
    _ready = true;
  }

  // --- Medications -------------------------------------------------------

  List<Medication> get medications => _meds.values.toList(growable: false);

  Future<void> saveMedication(Medication m) => _meds.put(m.id, m);

  Future<void> deleteMedication(String id) async {
    await _meds.delete(id);
    // Drop this med's logs too so history/adherence stays consistent.
    final stale = _logs.values
        .where((l) => l.medicationId == id)
        .map((l) => l.id)
        .toList(growable: false);
    await _logs.deleteAll(stale);
  }

  // --- Dose logs ---------------------------------------------------------

  /// The recorded log for a specific scheduled occurrence, if any.
  DoseLog? logFor(String medicationId, DateTime scheduledTime) {
    final key = DoseLog.occurrenceKey(medicationId, scheduledTime);
    for (final l in _logs.values) {
      if (l.key == key) return l;
    }
    return null;
  }

  /// How long after the scheduled time a "taken" log is considered Late
  /// rather than on-time. Matches the spec's distinction between Taken and
  /// Late and keeps the rule in one place.
  static const lateGrace = Duration(minutes: 30);

  Future<void> recordDose({
    required String medicationId,
    required DateTime scheduledTime,
    required DoseStatus status,
    DoseSource source = DoseSource.manual,
  }) async {
    final now = DateTime.now();
    // Auto-upgrade a "taken" log past the grace period to "late". The caller
    // tells us the user's intent (taken/skipped); we apply the timing rule.
    var effective = status;
    if (status == DoseStatus.taken &&
        now.difference(scheduledTime) > lateGrace) {
      effective = DoseStatus.late;
    }

    final existing = logFor(medicationId, scheduledTime);
    if (existing != null) {
      existing
        ..status = effective
        ..actualTime = now
        ..source = source;
      await _logs.put(existing.id, existing);
      return;
    }
    final log = DoseLog(
      id: '${medicationId}_${scheduledTime.millisecondsSinceEpoch}',
      medicationId: medicationId,
      scheduledTime: scheduledTime,
      status: effective,
      actualTime: now,
      source: source,
    );
    await _logs.put(log.id, log);
  }

  Future<void> clearDose(String medicationId, DateTime scheduledTime) async {
    final existing = logFor(medicationId, scheduledTime);
    if (existing != null) await _logs.delete(existing.id);
  }
}
