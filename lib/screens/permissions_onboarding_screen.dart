import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../services/reminder_service.dart';

/// One-shot permission onboarding shown right after the user clears the
/// Welcome screen — explains *why* MediTracker needs notification,
/// exact-alarm and battery-optimization permissions, then triggers the
/// system prompts in sequence.
///
/// Modelled after bKash / WhatsApp / Daraz first-launch flows: a single
/// friendly screen with a primary "Allow & continue" CTA and a "Skip for
/// now" escape hatch. The user can re-run it any time from Settings.
class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> {
  bool _working = false;

  Future<void> _allowAll() async {
    setState(() => _working = true);
    try {
      await ReminderService.instance.requestPermission();
    } finally {
      _finish();
    }
  }

  void _skip() => _finish();

  void _finish() {
    SettingsStore.instance.permissionsOnboardingComplete = true;
    // AppRoot rebuilds on the flag change and swaps in HomeShell — no
    // explicit Navigator.push needed.
  }

  @override
  Widget build(BuildContext context) {
    // On platforms where these permissions don't exist (iOS handles it
    // inline, desktop / web have no concept), skip immediately so the
    // user doesn't see an empty form.
    if (kIsWeb || !(Platform.isAndroid)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.notifications_active,
                  size: 56,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Never miss a dose',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'MediTracker needs a few permissions so reminders fire on '
                'time — even when the app is closed.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              const _PermBullet(
                icon: Icons.notifications_outlined,
                title: 'Show notifications',
                detail: 'Display reminders on your lock screen and tray.',
              ),
              const _PermBullet(
                icon: Icons.access_alarm,
                title: 'Exact alarm timing',
                detail: 'Fire at the dose time, not 10 minutes later.',
              ),
              const _PermBullet(
                icon: Icons.battery_charging_full,
                title: 'Ignore battery optimization',
                detail:
                    'Lets alarms run while the app is closed (same as '
                    'bKash, WhatsApp).',
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _working ? null : _allowAll,
                icon: _working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_working ? 'Requesting…' : 'Allow & continue'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _working ? null : _skip,
                child: const Text('Skip for now'),
              ),
              Text(
                'You can change these any time in Settings → Reminder.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermBullet extends StatelessWidget {
  const _PermBullet({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
