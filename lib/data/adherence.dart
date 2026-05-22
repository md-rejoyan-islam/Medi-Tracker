import '../models/dose_log.dart';
import '../models/medication.dart';

/// One scheduled dose occurrence with its resolved status.
///
/// Pure value type produced by combining a [Medication] schedule with the
/// stored [DoseLog]s — no Hive, no platform calls, fully unit-testable.
class DoseOccurrence {
  DoseOccurrence({
    required this.medication,
    required this.scheduledTime,
    required this.status,
    this.log,
  });

  final Medication medication;
  final DateTime scheduledTime;
  final DoseStatus status;
  final DoseLog? log;

  /// No decision recorded yet (neither taken nor skipped).
  bool get isPending => log == null;
}

/// Builds the day's occurrences for [day], sorted by time then med name.
///
/// `pending` future doses are returned with `log == null` and a status that
/// is *not* missed, so the UI can show an actionable row. Use
/// [DoseOccurrence.log] == null to detect "no decision recorded yet".
List<DoseOccurrence> occurrencesForDay({
  required List<Medication> medications,
  required DoseLog? Function(String medId, DateTime scheduled) lookupLog,
  required DateTime day,
  required DateTime now,
}) {
  final out = <DoseOccurrence>[];
  for (final m in medications) {
    for (final t in m.doseTimesOn(day)) {
      final log = lookupLog(m.id, t);
      final status = log?.status ??
          (t.isBefore(now) ? DoseStatus.missed : DoseStatus.taken);
      out.add(DoseOccurrence(
        medication: m,
        scheduledTime: t,
        status: status,
        log: log,
      ));
    }
  }
  out.sort((a, b) {
    final c = a.scheduledTime.compareTo(b.scheduledTime);
    return c != 0 ? c : a.medication.name.compareTo(b.medication.name);
  });
  return out;
}

/// Adherence over the inclusive date range [from]..[to].
class AdherenceStats {
  AdherenceStats({
    required this.scheduled,
    required this.taken,
    required this.late,
    required this.skipped,
    required this.missed,
  });

  final int scheduled;
  final int taken;
  final int late;
  final int skipped;
  final int missed;

  /// (taken + late) / decided doses. Late counts as adherent because the
  /// medication WAS taken, just outside the on-time window.
  double get rate {
    final decided = taken + late + skipped + missed;
    if (decided == 0) return 0;
    return (taken + late) / decided;
  }
}

AdherenceStats computeAdherence({
  required List<Medication> medications,
  required DoseLog? Function(String medId, DateTime scheduled) lookupLog,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  var scheduled = 0, taken = 0, late = 0, skipped = 0, missed = 0;
  var day = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);
  while (!day.isAfter(last)) {
    for (final m in medications) {
      for (final t in m.doseTimesOn(day)) {
        scheduled++;
        final log = lookupLog(m.id, t);
        if (log != null) {
          switch (log.status) {
            case DoseStatus.taken:
              taken++;
            case DoseStatus.late:
              late++;
            case DoseStatus.skipped:
              skipped++;
            case DoseStatus.missed:
              missed++;
          }
        } else if (t.isBefore(now)) {
          missed++;
        }
      }
    }
    day = day.add(const Duration(days: 1));
  }
  return AdherenceStats(
    scheduled: scheduled,
    taken: taken,
    late: late,
    skipped: skipped,
    missed: missed,
  );
}
