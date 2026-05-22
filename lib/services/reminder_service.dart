import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_ce/hive.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/medi_store.dart';
import '../data/settings_store.dart';
import '../models/medication.dart';
import 'reminder_text.dart';

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

  // Channel ID is bumped each time the channel's audio attributes change,
  // because Android locks channel properties at first creation and the
  // only way to "edit" them is to create a fresh channel.
  //
  // v4: in addition to the alarm-stream routing from v3, the channel now
  // points at the system *alarm* sound URI. v3 relied on the default
  // notification sound, which can be silenced to "None" at the OS level
  // — even with alarm-stream routing — leaving the user with a silent
  // notification. The alarm URI guarantees a tone is selected.
  static const _channelId = 'medication_reminders_v4';
  static const _legacyChannelIds = <String>[
    'medication_reminders', // v1: no explicit sound
    'medication_reminders_v2', // v2: sound on but routed via notification stream
    'medication_reminders_v3', // v3: alarm stream but default-notification sound
  ];

  /// System alarm sound URI — the same tone the user has chosen in
  /// *Settings → Sound → Alarm sound*. Works across all Android versions.
  static const _alarmSoundUri = 'content://settings/system/alarm_alert';

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
        // Clean up older channels so the user doesn't see "Medication
        // reminders" / "v2" leftover entries in Android system settings.
        for (final legacy in _legacyChannelIds) {
          try {
            await android?.deleteNotificationChannel(legacy);
          } catch (_) {/* didn't exist */}
        }
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Medication reminders',
            description: 'Reminders to take your medication on time',
            importance: Importance.max,
            playSound: true,
            // Explicit alarm tone — survives a "None" notification sound
            // setting that would otherwise silence the channel.
            sound: UriAndroidNotificationSound(_alarmSoundUri),
            enableVibration: true,
            // Route through the alarm audio stream — plays at alarm
            // volume + bypasses Do Not Disturb, matching the Clock app.
            audioAttributesUsage: AudioAttributesUsage.alarm,
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

  /// Requests every permission the medication reminder pipeline needs:
  /// - `POST_NOTIFICATIONS` (Android 13+) so notifications can be shown
  /// - `SCHEDULE_EXACT_ALARM` (Android 12+) so they fire on time
  /// - `IGNORE_BATTERY_OPTIMIZATIONS` so the alarm survives Doze / app
  ///   being closed (the reason most "no notification after I close the
  ///   app" reports happen on Xiaomi / Samsung / Vivo / Realme / Oppo)
  /// - iOS/macOS alert + sound + badge
  ///
  /// Returns true if the notification permission specifically was granted.
  /// The other two are best-effort — the user can decline them and the
  /// app still works (just less reliably while the app is killed).
  Future<bool> requestPermission() async {
    if (!_supported || kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final notif = await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
        // The OS prompts the user with a system dialog ("Allow MediTracker
        // to ignore battery optimizations?") — the same dialog bKash /
        // Daraz / WhatsApp use for this exact reason.
        await ph.Permission.ignoreBatteryOptimizations.request();
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
          sound: UriAndroidNotificationSound(_alarmSoundUri),
          enableVibration: true,
          fullScreenIntent: false,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm,
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

    final lang = SettingsStore.instance.language;
    final title = ReminderText.title(m.name, lang);
    final body = ReminderText.body(m.dosage, lang);

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
            title,
            body,
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
              title,
              body,
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

  /// Re-schedule every active medication's notifications. Used when the
  /// reminder language changes — the title/body baked into already-
  /// scheduled notifications don't auto-update, so we cancel and re-issue.
  Future<void> resyncAll() async {
    if (!_supported) return;
    for (final m in MediStore.instance.medications) {
      if (m.active) await sync(m);
    }
  }

  /// Fires a notification immediately. Use it from Settings to confirm the
  /// whole pipeline (channel, sound, permission) works without waiting for
  /// a real dose time.
  Future<bool> showTestNotification() async {
    if (!_supported) return false;
    try {
      await requestPermission();
      final lang = SettingsStore.instance.language;
      await _plugin.show(
        9999,
        ReminderText.testTitle(lang),
        ReminderText.testBody(lang),
        _details,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Schedules a single notification [seconds] in the future via the same
  /// exact-alarm pipeline real medication reminders use. The point: prove
  /// scheduling works (channel + alarm + exact permission + battery exempt)
  /// **without** waiting for a real dose time. If this fires while the app
  /// is closed, real scheduled reminders will too.
  Future<bool> scheduleTestNotification({int seconds = 30}) async {
    if (!_supported) return false;
    try {
      await requestPermission();
      final lang = SettingsStore.instance.language;
      final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
      await _plugin.zonedSchedule(
        9998,
        ReminderText.testTitle(lang),
        'Scheduled test ($seconds s). ${ReminderText.testBody(lang)}',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    } catch (_) {
      try {
        // Fall back to inexact if exact-alarm permission isn't granted.
        final lang = SettingsStore.instance.language;
        final when =
            tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
        await _plugin.zonedSchedule(
          9998,
          ReminderText.testTitle(lang),
          'Scheduled test ($seconds s, inexact). '
              '${ReminderText.testBody(lang)}',
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// How many notifications are currently scheduled with the OS. A useful
  /// sanity check — if this is 0 right after adding meds, scheduling
  /// silently failed (usually an exact-alarm permission issue).
  Future<int> pendingNotificationCount() async {
    if (!_supported) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  /// Snapshot of every reliability-relevant permission so the UI can show
  /// the user exactly what's blocking notifications. Returns null fields
  /// on non-Android platforms (iOS / desktop don't expose this trio).
  Future<
      ({
        bool? notifications,
        bool? exactAlarms,
        bool? batteryOptimization,
      })> permissionStatus() async {
    if (!_supported || kIsWeb || !Platform.isAndroid) {
      return (
        notifications: null,
        exactAlarms: null,
        batteryOptimization: null,
      );
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final notif = await android?.areNotificationsEnabled();
      final exact = await android?.canScheduleExactNotifications();
      final battery = await ph.Permission.ignoreBatteryOptimizations.isGranted;
      return (
        notifications: notif,
        exactAlarms: exact,
        batteryOptimization: battery,
      );
    } catch (_) {
      return (
        notifications: null,
        exactAlarms: null,
        batteryOptimization: null,
      );
    }
  }

  /// Opens the system app-settings page for MediTracker — useful when the
  /// user has previously denied a permission and the runtime dialog won't
  /// show again, or when they need OEM-specific autostart toggles
  /// (Xiaomi MIUI, Samsung "Sleeping apps", etc.) that have no public API.
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
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
