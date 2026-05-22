import 'package:flutter/material.dart';

import '../ble/pill_dispenser_service.dart';
import '../data/settings_store.dart';
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
