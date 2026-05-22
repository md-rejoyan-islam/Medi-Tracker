import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Voice language used by the device for reminder prompts (spec §9).
enum ReminderLanguage { english, bengali, bilingual }

/// App + device settings, persisted locally.
///
/// Exposed as a [ValueListenable] so widgets can rebuild reactively without
/// pulling in a state-management package. Keys are plain strings inside one
/// Hive box; values are primitives so no extra adapters are needed.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _boxName = 'settings';
  late final Box _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox(_boxName);
    _ready = true;
  }

  // --- Voice / reminder behaviour ---------------------------------------

  ReminderLanguage get language => ReminderLanguage
      .values[(_box.get('language', defaultValue: 2) as int)
          .clamp(0, ReminderLanguage.values.length - 1)];
  set language(ReminderLanguage v) {
    _box.put('language', v.index);
    notifyListeners();
  }

  /// 0..100 volume the device should use for the audio reminder.
  int get volume => (_box.get('volume', defaultValue: 80) as int).clamp(0, 100);
  set volume(int v) {
    _box.put('volume', v.clamp(0, 100));
    notifyListeners();
  }

  /// Minutes between repeat chimes if the drawer isn't opened.
  int get repeatIntervalMinutes =>
      (_box.get('repeat_min', defaultValue: 5) as int).clamp(1, 60);
  set repeatIntervalMinutes(int v) {
    _box.put('repeat_min', v.clamp(1, 60));
    notifyListeners();
  }

  // --- Paired device ----------------------------------------------------

  /// Human-friendly device name shown on the dashboard.
  String get deviceName =>
      _box.get('device_name', defaultValue: 'MediTracker') as String;
  set deviceName(String v) {
    _box.put('device_name', v.trim().isEmpty ? 'MediTracker' : v.trim());
    notifyListeners();
  }

  /// BLE remote id (MAC on Android / UUID on iOS) of the paired device,
  /// or null if no device is paired yet.
  String? get pairedDeviceId => _box.get('paired_id') as String?;
  set pairedDeviceId(String? v) {
    if (v == null) {
      _box.delete('paired_id');
    } else {
      _box.put('paired_id', v);
    }
    notifyListeners();
  }

  bool get hasPairedDevice => pairedDeviceId != null;

  // --- Onboarding -------------------------------------------------------

  /// True once the user has cleared the Welcome screen at least once.
  bool get onboardingComplete =>
      _box.get('onboarded', defaultValue: false) as bool;
  set onboardingComplete(bool v) {
    _box.put('onboarded', v);
    notifyListeners();
  }
}
