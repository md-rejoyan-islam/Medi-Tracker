import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/medi_store.dart';
import '../models/dose_log.dart';
import '../models/medication.dart';

/// BLE bridge between the phone and the MediTracker hardware device.
///
/// **What it sends** (spec §3 Data Synchronization): per-medication schedule
/// JSON like `{"drawer":3,"medicine":"Metformin","times":["08:00","20:00"],
/// "meal":"after_meal"}` to a write characteristic on the nRF52832.
///
/// **What it receives** (spec §6 Drawer Verification): drawer-open events
/// `{"timestamp":"...","drawer":N,"status":"opened"}` on a notify
/// characteristic, which are auto-logged as taken-by-device.
///
/// The service is **inert until configured** with the real GATT UUIDs for
/// the device. Until then, calls are safe no-ops so the UI doesn't need
/// special cases — manual logging continues to work end-to-end.
class DispenserConfig {
  const DispenserConfig({
    required this.serviceUuid,
    required this.scheduleWriteUuid,
    required this.eventNotifyUuid,
    this.controlWriteUuid,
  });

  /// Primary GATT service exposed by the device.
  final String serviceUuid;

  /// Write characteristic the phone uses to push schedule JSON.
  final String scheduleWriteUuid;

  /// Notify characteristic that fires on drawer-open events (JSON).
  final String eventNotifyUuid;

  /// Optional control characteristic for non-schedule commands (time sync,
  /// rename, volume, language). Falls back to [scheduleWriteUuid] if null.
  final String? controlWriteUuid;
}

class PillDispenserService {
  PillDispenserService._();
  static final PillDispenserService instance = PillDispenserService._();

  DispenserConfig? _config;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _controlChar;
  StreamSubscription<List<int>>? _eventSub;

  bool get isConfigured => _config != null;
  bool get isAttached => _writeChar != null;

  void configure(DispenserConfig config) => _config = config;

  /// Discovers services on a connected [device] and binds the write +
  /// notify characteristics. No-ops if unconfigured.
  Future<void> attach(BluetoothDevice device) async {
    final config = _config;
    if (config == null) return;

    final services = await device.discoverServices(
      subscribeToServicesChanged: false,
    );
    BluetoothCharacteristic? write;
    BluetoothCharacteristic? control;
    BluetoothCharacteristic? notify;
    for (final s in services) {
      if (s.uuid.str.toLowerCase() != config.serviceUuid.toLowerCase()) {
        continue;
      }
      for (final c in s.characteristics) {
        final u = c.uuid.str.toLowerCase();
        if (u == config.scheduleWriteUuid.toLowerCase()) write = c;
        if (u == config.eventNotifyUuid.toLowerCase()) notify = c;
        if (config.controlWriteUuid != null &&
            u == config.controlWriteUuid!.toLowerCase()) {
          control = c;
        }
      }
    }
    _writeChar = write;
    _controlChar = control ?? write;

    if (notify != null) {
      await notify.setNotifyValue(true);
      await _eventSub?.cancel();
      _eventSub = notify.lastValueStream.listen(_onEventBytes);
    }
  }

  Future<void> detach() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _writeChar = null;
    _controlChar = null;
  }

  /// Push a non-schedule command to the device (spec §9 Settings flows).
  /// Wraps payload in a `{cmd, ...}` envelope so the firmware can dispatch.
  Future<bool> _sendCommand(Map<String, dynamic> payload) async {
    final ch = _controlChar;
    if (ch == null) return false;
    try {
      await ch.write(utf8.encode(jsonEncode(payload)));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Spec §9 → Device → Sync time. Sends the phone's current epoch (ms) so
  /// the device's RTC stays aligned.
  Future<bool> syncTime() => _sendCommand({
        'cmd': 'sync_time',
        'epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'tz_offset_min': DateTime.now().timeZoneOffset.inMinutes,
      });

  /// Spec §9 → Device → Rename.
  Future<bool> renameDevice(String name) =>
      _sendCommand({'cmd': 'rename', 'name': name});

  /// Spec §9 → Reminder volume (0..100) and language.
  Future<bool> setVolume(int volume) =>
      _sendCommand({'cmd': 'volume', 'value': volume.clamp(0, 100)});

  Future<bool> setLanguage(String code) =>
      _sendCommand({'cmd': 'language', 'value': code});

  /// Push a single medication's schedule to the device.
  Future<bool> syncMedication(Medication m) async {
    final w = _writeChar;
    if (w == null) return false;
    try {
      final bytes = utf8.encode(jsonEncode(m.toDeviceJson()));
      await w.write(bytes, withoutResponse: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Push every active medication to the device.
  Future<void> syncAll() async {
    if (_writeChar == null) return;
    for (final m in MediStore.instance.medications) {
      if (m.active && m.drawer != null) await syncMedication(m);
    }
  }

  void _onEventBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      final raw = utf8.decode(bytes);
      final obj = jsonDecode(raw);
      if (obj is! Map<String, dynamic>) return;
      if (obj['status'] != 'opened') return;
      final drawer = obj['drawer'];
      if (drawer is! int) return;
      unawaited(_recordOpened(drawer));
    } catch (_) {
      // Malformed payload — ignore rather than crash the notify stream.
    }
  }

  /// A drawer was opened on the device — find its medication and log the
  /// closest scheduled dose for today as taken-by-device.
  Future<void> _recordOpened(int drawer) async {
    final store = MediStore.instance;
    Medication? med;
    for (final m in store.medications) {
      if (m.drawer == drawer && m.active) {
        med = m;
        break;
      }
    }
    if (med == null) return;

    final now = DateTime.now();
    final times = med.doseTimesOn(now);
    if (times.isEmpty) return;

    times.sort((a, b) => (a.difference(now)).abs().compareTo(
          (b.difference(now)).abs(),
        ));
    await store.recordDose(
      medicationId: med.id,
      scheduledTime: times.first,
      status: DoseStatus.taken,
      source: DoseSource.device,
    );
  }
}
