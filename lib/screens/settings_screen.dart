import 'package:flutter/material.dart';

import '../ble/pill_dispenser_service.dart';
import '../data/settings_store.dart';
import '../services/reminder_service.dart';
import 'pair_device_screen.dart';
import 'scan_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: s,
        builder: (context, _) {
          return ListView(
            children: [
              const _SectionHeader('Appearance'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (set) => s.themeMode = set.first,
                ),
              ),

              const _SectionHeader('Audio'),
              RadioGroup<ReminderLanguage>(
                groupValue: s.language,
                onChanged: (v) => v == null ? null : s.language = v,
                child: Column(
                  children: [
                    for (final l in ReminderLanguage.values)
                      RadioListTile<ReminderLanguage>(
                        title: Text(_languageLabel(l)),
                        value: l,
                      ),
                  ],
                ),
              ),

              const _SectionHeader('Reminder'),
              ListTile(
                title: const Text('Volume'),
                subtitle: Slider(
                  value: s.volume.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${s.volume}%',
                  onChanged: (v) => s.volume = v.round(),
                ),
                trailing: Text('${s.volume}%'),
              ),
              ListTile(
                title: const Text('Repeat interval'),
                subtitle: Slider(
                  value: s.repeatIntervalMinutes.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${s.repeatIntervalMinutes} min',
                  onChanged: (v) =>
                      s.repeatIntervalMinutes = v.round(),
                ),
                trailing: Text('${s.repeatIntervalMinutes} min'),
              ),
              SwitchListTile(
                title: const Text('In-app reminder popup'),
                subtitle: const Text(
                  'When the app is open, also pop the reminder screen at '
                  'dose time. Off = OS notification only (recommended).',
                ),
                value: s.inAppReminderPopup,
                onChanged: (v) => s.inAppReminderPopup = v,
              ),
              const _PermissionStatusTile(),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined),
                title: const Text('Re-run permission setup'),
                subtitle: const Text(
                  'Walk through the notification / alarm / battery '
                  'prompts again.',
                ),
                onTap: () {
                  SettingsStore.instance.permissionsOnboardingComplete = false;
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Send test notification'),
                subtitle: const Text(
                  'Verify sound + delivery. Lock the phone first if '
                  'you want to test when the app is closed.',
                ),
                onTap: () => _testNotification(context),
              ),

              const _SectionHeader('Device'),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename device'),
                subtitle: Text(s.deviceName),
                onTap: () => _rename(context),
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth_searching),
                title: const Text('Pair / change device'),
                subtitle: Text(
                  s.hasPairedDevice
                      ? 'Paired: ${s.pairedDeviceId}'
                      : 'No device paired',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PairDeviceScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Sync time'),
                subtitle: const Text(
                  'Send the phone time to the device',
                ),
                onTap: () => _syncTime(context),
              ),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('Firmware update'),
                subtitle: const Text('Check for device firmware update'),
                onTap: () => _todo(context, 'Firmware update'),
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('BLE toolbox (debug)'),
                subtitle: const Text(
                  'Scan and inspect raw GATT services',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _languageLabel(ReminderLanguage l) {
    return switch (l) {
      ReminderLanguage.english => 'English',
      ReminderLanguage.bengali => 'Bengali (বাংলা)',
      ReminderLanguage.bilingual => 'Bilingual (English + Bengali)',
    };
  }

  Future<void> _rename(BuildContext context) async {
    final s = SettingsStore.instance;
    final ctrl = TextEditingController(text: s.deviceName);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'MediTracker'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) s.deviceName = name;
  }

  Future<void> _testNotification(BuildContext context) async {
    final svc = ReminderService.instance;
    if (!svc.supported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are not supported on this platform.',
          ),
        ),
      );
      return;
    }
    final ok = await svc.showTestNotification();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Test notification sent. Check the status bar.'
              : 'Failed to send. Check notification permission.',
        ),
      ),
    );
  }

  Future<void> _syncTime(BuildContext context) async {
    final svc = PillDispenserService.instance;
    if (!svc.isAttached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connect to the device first (Pair / change device).',
          ),
        ),
      );
      return;
    }
    final ok = await svc.syncTime();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Time synced to device.' : 'Time sync failed.'),
      ),
    );
  }

  void _todo(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label needs the device GATT protocol — wire it once UUIDs are '
          'provided.',
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

/// Live display of the Android notification + exact-alarm permission
/// status. Tap to re-request the permissions (Android prompts the user
/// once per app install for notifications; for exact alarms it deep-links
/// into system settings on API 31+).
class _PermissionStatusTile extends StatefulWidget {
  const _PermissionStatusTile();

  @override
  State<_PermissionStatusTile> createState() => _PermissionStatusTileState();
}

class _PermissionStatusTileState extends State<_PermissionStatusTile> {
  ({bool? notifications, bool? exactAlarms, bool? batteryOptimization})?
      _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await ReminderService.instance.permissionStatus();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _request() async {
    await ReminderService.instance.requestPermission();
    await _refresh();
  }

  Widget _row(BuildContext context, String label, bool ok) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: ok ? scheme.primary : scheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            ok ? 'granted' : 'DENIED',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ok ? scheme.primary : scheme.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) {
      return const ListTile(
        leading: Icon(Icons.lock_outline),
        title: Text('Reminder reliability'),
        subtitle: Text('Checking…'),
      );
    }
    if (s.notifications == null && s.exactAlarms == null) {
      return const SizedBox.shrink();
    }
    final notifOk = s.notifications == true;
    final exactOk = s.exactAlarms == true;
    final batteryOk = s.batteryOptimization == true;
    final allOk = notifOk && exactOk && batteryOk;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    allOk ? Icons.verified : Icons.warning_amber,
                    color: allOk ? scheme.primary : scheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reminder reliability',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _row(context, 'Show notifications', notifOk),
              _row(context, 'Exact alarm timing', exactOk),
              _row(context, 'Ignore battery optimization', batteryOk),
              if (!allOk) ...[
                const SizedBox(height: 8),
                Text(
                  batteryOk
                      ? 'Tap Fix and grant the prompted permissions.'
                      : 'Without battery optimization exemption Android '
                          'may kill scheduled alarms when the app is closed.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!allOk) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _request,
                        icon: const Icon(Icons.security),
                        label: const Text('Fix permissions'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ReminderService.instance.openAppSettings(),
                      icon: const Icon(Icons.tune),
                      label: const Text('App settings'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
