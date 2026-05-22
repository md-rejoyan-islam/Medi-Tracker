import 'dart:async';

import 'package:flutter/material.dart';

import '../data/adherence.dart';
import '../data/medi_store.dart';
import '../data/settings_store.dart';
import '../models/dose_log.dart';
import '../screens/reminder_screen.dart';

/// Polls for medication doses that are due *right now* while the app is open
/// and automatically pushes the [ReminderScreen] for them.
///
/// This complements the OS-level scheduled notifications from
/// `flutter_local_notifications` — those fire even when the app is closed,
/// but they don't bring the user inside the app. This watcher gives the
/// in-app reminder behaviour the user expects when they're already looking
/// at the phone.
///
/// Design notes:
/// - Polls every 30 s, cheap because the check is pure Dart over a small
///   in-memory list.
/// - Tracks shown-occurrence keys per process so the same dose doesn't
///   re-pop after the user dismisses the reminder.
/// - Pauses while the app is backgrounded (saves battery; the OS
///   notification handles that case).
class InAppReminderWatcher with WidgetsBindingObserver {
  InAppReminderWatcher(this._navKey);

  final GlobalKey<NavigatorState> _navKey;

  Timer? _timer;
  final _alreadyShown = <String>{};
  String? _activeKey; // currently-open reminder; null = none

  static const _pollInterval = Duration(seconds: 30);

  /// A dose is "due now" once its scheduled time passes, up to this many
  /// minutes after — beyond that it's missed and we don't pop a reminder.
  static const _dueWindow = Duration(minutes: 30);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _arm();
    // One immediate tick so the user gets feedback on app launch.
    _check();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _arm();
      _check();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _check() async {
    if (!SettingsStore.instance.inAppReminderPopup) return;
    if (_activeKey != null) return; // a reminder is already on screen
    final nav = _navKey.currentState;
    if (nav == null) return;

    final now = DateTime.now();
    final store = MediStore.instance;
    final occ = occurrencesForDay(
      medications: store.medications,
      lookupLog: store.logFor,
      day: now,
      now: now,
    );

    for (final o in occ) {
      if (!o.isPending) continue;
      // Only fire for doses inside the actionable window: from scheduled
      // time up to _dueWindow after.
      final since = now.difference(o.scheduledTime);
      if (since.isNegative) continue;
      if (since > _dueWindow) continue;

      final key = DoseLog.occurrenceKey(
        o.medication.id,
        o.scheduledTime,
      );
      if (_alreadyShown.contains(key)) continue;

      _alreadyShown.add(key);
      _activeKey = key;
      // Push above any current screen and clear the active marker once it
      // closes, so the next due dose can pop later in the day.
      await nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ReminderScreen(
            medication: o.medication,
            scheduledTime: o.scheduledTime,
          ),
        ),
      );
      _activeKey = null;
      return; // one at a time
    }
  }
}
