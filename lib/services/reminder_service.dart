import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_ce/hive.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';

/// Schedules and cancels local medication reminders.
///
/// The core `flutter_local_notifications` plugin supports Android, iOS, macOS
/// and Linux. On platforms it can't drive (notably Windows desktop) every
/// method becomes a safe no-op so the rest of the app keeps working.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// medId -> notification ids we scheduled for it (for clean cancellation
  /// across edits, since a med's times can change).
  static const _idBoxName = 'reminder_ids';
  Box<List>? _idBox;

  bool _supported = false;
  bool _ready = false;

  bool get supported => _supported;

  static const _channelId = 'medication_reminders';

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    _supported =
        Platform.isAndroid || Platform.isIOS || Platform.isMacOS ||
            Platform.isLinux;
    if (!_supported) return;

    try {
      tzdata.initializeTimeZones();
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      const linux =
          LinuxInitializationSettings(defaultActionName: 'Open');
      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
          linux: linux,
        ),
      );
      _idBox = await Hive.openBox<List>(_idBoxName);
    } catch (_) {
      // Any platform/init failure: degrade to no-op rather than crash.
      _supported = false;
    }
  }

  /// Requests notification permission where the OS gates it (Android 13+,
  /// iOS/macOS). Returns true if granted or not required.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (Platform.isIOS || Platform.isMacOS) {
        final darwin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await darwin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Medication reminders',
          channelDescription: 'Reminders to take your medication on time',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      );

  /// Deterministic notification id for a (med, minute-of-day, weekday) slot.
  /// weekday 0 means "every day".
  int _notificationId(String medId, int minuteOfDay, int weekday) {
    final base = medId.hashCode & 0x3FFFFF; // 22 bits
    return base * 10000 + minuteOfDay * 10 + weekday;
  }

  /// Reschedules all reminders for [m]: cancels any previous ones, then
  /// schedules the current schedule. Inactive meds are just cancelled.
  Future<void> sync(Medication m) async {
    if (!_supported) return;
    await cancel(m.id);
    if (!m.active) return;

    final ids = <int>[];
    final days = m.daysOfWeek.isEmpty ? <int>[0] : m.daysOfWeek;
    for (final minute in m.timesOfDay) {
      for (final wd in days) {
        final id = _notificationId(m.id, minute, wd);
        final when = _nextInstance(minute, wd);
        try {
          await _plugin.zonedSchedule(
            id,
            'Time for ${m.name}',
            m.dosage.isEmpty ? 'Tap when taken' : m.dosage,
            when,
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: wd == 0
                ? DateTimeComponents.time
                : DateTimeComponents.dayOfWeekAndTime,
          );
          ids.add(id);
        } catch (_) {
          // Skip a slot that the OS refuses rather than abort the rest.
        }
      }
    }
    await _idBox?.put(m.id, ids);
  }

  Future<void> cancel(String medId) async {
    if (!_supported) return;
    final ids = (_idBox?.get(medId) ?? const []).cast<int>();
    for (final id in ids) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    await _idBox?.delete(medId);
  }

  /// Next [tz.TZDateTime] at [minuteOfDay]; if [weekday] (1-7) is given,
  /// the next occurrence of that weekday.
  tz.TZDateTime _nextInstance(int minuteOfDay, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
    if (weekday != 0) {
      while (when.weekday != weekday) {
        when = when.add(const Duration(days: 1));
      }
    }
    return when;
  }
}
