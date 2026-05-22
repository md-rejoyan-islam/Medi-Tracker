import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../data/adherence.dart';
import '../data/medi_store.dart';
import '../data/settings_store.dart';
import '../models/dose_log.dart';
import 'reminder_screen.dart';

/// Spec §2 Dashboard + the day's dose list.
///
/// Device status (online/offline) and battery are still placeholders because
/// they come from the device over BLE — they'll go live once
/// `PillDispenserService` is wired with the real GATT UUIDs.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MediStore.instance;
    final listenable = Listenable.merge([
      store.medicationsBox.listenable(),
      store.logsBox.listenable(),
      SettingsStore.instance,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo/logo.png', height: 32),
            const SizedBox(width: 10),
            const Text('Dashboard'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final now = DateTime.now();
          final occ = occurrencesForDay(
            medications: store.medications,
            lookupLog: store.logFor,
            day: now,
            now: now,
          );
          final today = computeAdherence(
            medications: store.medications,
            lookupLog: store.logFor,
            from: now,
            to: now,
            now: now,
          );
          final nextDose = occ
              .where((o) => o.isPending && o.scheduledTime.isAfter(now))
              .map((o) => o.scheduledTime)
              .fold<DateTime?>(null,
                  (a, b) => a == null || b.isBefore(a) ? b : a);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DeviceCard(nextDose: nextDose, adherenceToday: today.rate),
              const SizedBox(height: 16),
              Text("Today's doses",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (occ.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nothing scheduled today.\n'
                      'Add medications in the Meds tab.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...occ.map((o) => _DoseRow(o, now)),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.nextDose, required this.adherenceToday});
  final DateTime? nextDose;
  final double adherenceToday;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;
    final online = settings.hasPairedDevice;
    final scheme = Theme.of(context).colorScheme;
    final next = nextDose == null
        ? '—'
        : TimeOfDay.fromDateTime(nextDose!).format(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  online
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: online ? Colors.green : scheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.deviceName,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(online ? 'Paired' : 'Not paired'),
                  backgroundColor: online
                      ? Colors.green.withValues(alpha: 0.15)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Battery',
                    value: '—', // Live value comes from device over BLE.
                  ),
                ),
                Expanded(child: _Stat(label: 'Next dose', value: next)),
                Expanded(
                  child: _Stat(
                    label: 'Adherence',
                    value: '${(adherenceToday * 100).round()}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow(this.o, this.now);
  final DoseOccurrence o;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(o.scheduledTime).format(context);
    final overdue = o.isPending && o.scheduledTime.isBefore(now);
    final (color, icon) = _stylize(o, overdue);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      onTap: o.log == null
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ReminderScreen(
                    medication: o.medication,
                    scheduledTime: o.scheduledTime,
                  ),
                ),
              )
          : null,
      title: Text('${o.medication.name}'
          '${o.medication.drawer != null ? ' · Drawer ${o.medication.drawer}' : ''}'),
      subtitle: Text(
        [
          time,
          if (o.medication.dosage.isNotEmpty) o.medication.dosage,
          if (o.log != null) '· ${o.log!.status.name}',
          if (overdue) '· overdue',
        ].join('  '),
      ),
      trailing: o.log == null
          ? Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Skip',
                  icon: const Icon(Icons.do_not_disturb_on_outlined),
                  onPressed: () => MediStore.instance.recordDose(
                    medicationId: o.medication.id,
                    scheduledTime: o.scheduledTime,
                    status: DoseStatus.skipped,
                  ),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Taken'),
                  onPressed: () => MediStore.instance.recordDose(
                    medicationId: o.medication.id,
                    scheduledTime: o.scheduledTime,
                    status: DoseStatus.taken,
                  ),
                ),
              ],
            )
          : IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: () => MediStore.instance.clearDose(
                o.medication.id,
                o.scheduledTime,
              ),
            ),
    );
  }

  (Color?, IconData) _stylize(DoseOccurrence o, bool overdue) {
    if (o.log != null) {
      switch (o.log!.status) {
        case DoseStatus.taken:
          return (Colors.green, Icons.check_circle);
        case DoseStatus.late:
          return (Colors.orange, Icons.access_time_filled);
        case DoseStatus.skipped:
          return (Colors.orange, Icons.do_not_disturb_on);
        case DoseStatus.missed:
          return (Colors.red, Icons.cancel);
      }
    }
    return overdue
        ? (Colors.red, Icons.error_outline)
        : (null, Icons.schedule);
  }
}
