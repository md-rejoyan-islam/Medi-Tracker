import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (kIsWeb) {
      _supported = false;
      return;
    }
    _supported = Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux;
    if (!_supported) return;

    try {
      tzdata.initializeTimeZones();
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      );
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

      // Create the channel explicitly so it picks up MAX importance + sound
      // immediately; channels can't be modified after first creation on
      // Android, so this must match [_details] below.
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Medication reminders',
            description: 'Reminders to take your medication on time',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      _idBox = await Hive.openBox<List>(_idBoxName);

      // Ask up-front so notifications can actually be delivered. Android
      // 13+ silently drops scheduled notifications until POST_NOTIFICATIONS
      // is granted.
      await requestPermission();
    } catch (_) {
      // Any platform/init failure: degrade to no-op rather than crash.
      _supported = false;
    }
  }

  /// Requests notification permission where the OS gates it (Android 13+
  /// `POST_NOTIFICATIONS`, Android 12+ exact-alarm, iOS/macOS alert+sound).
  /// Returns true if granted or not required.
  Future<bool> requestPermission() async {
    if (!_supported || kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final notif = await android?.requestNotificationsPermission();
        // Android 12+ requires explicit user consent for exact alarms; we
        // want exact for medication timing (within a minute of the dose).
        await android?.requestExactAlarmsPermission();
        return notif ?? true;
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
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: false,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
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
          // exactAllowWhileIdle wakes the device from Doze and fires within
          // a minute of the scheduled time — required for medication
          // adherence (vs. inexact which the OS may batch by 10+ min).
          await _plugin.zonedSchedule(
            id,
            'Time for ${m.name}',
            m.dosage.isEmpty ? 'Tap when taken' : m.dosage,
            when,
            _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: wd == 0
                ? DateTimeComponents.time
                : DateTimeComponents.dayOfWeekAndTime,
          );
          ids.add(id);
        } catch (_) {
          // If the OS refuses exact (permission not granted on Android 12+),
          // fall back to inexact so the user still gets *something*.
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
          } catch (_) {/* give up on this slot */}
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
