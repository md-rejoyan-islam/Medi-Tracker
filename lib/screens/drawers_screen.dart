import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../data/adherence.dart';
import '../data/medi_store.dart';
import '../models/dose_log.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';
import '../widgets/minute_ticker.dart';
import 'medication_edit_screen.dart';
import 'reminder_screen.dart';

/// Spec §5 Drawer Configuration: 2×4 visual grid of the device's 8 drawers.
/// Each tile's colour mirrors the spec's RGB-LED indication table for the
/// drawer's *next* dose today: green=due/taken, red=overdue/missed,
/// neutral=idle/unassigned.
class DrawersScreen extends StatelessWidget {
  const DrawersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MediStore.instance;
    final listenable = Listenable.merge([
      store.medicationsBox.listenable(),
      store.logsBox.listenable(),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Drawers')),
      body: MinuteTicker(
        child: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final byDrawer = <int, Medication>{};
          for (final m in store.medications) {
            if (m.drawer != null) byDrawer[m.drawer!] = m;
          }
          final now = DateTime.now();
          final occ = occurrencesForDay(
            medications: store.medications,
            lookupLog: store.logFor,
            day: now,
            now: now,
          );
          // Pick the most-relevant occurrence per drawer for the colour cue:
          // overdue-pending > taken > skipped/missed > pending-future > none.
          final cuePerDrawer = <int, DoseOccurrence>{};
          for (final o in occ) {
            final d = o.medication.drawer;
            if (d == null) continue;
            final existing = cuePerDrawer[d];
            if (existing == null ||
                _priority(o, now) > _priority(existing, now)) {
              cuePerDrawer[d] = o;
            }
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (var i = 1; i <= 8; i++)
                  _DrawerTile(
                    index: i,
                    medication: byDrawer[i],
                    cue: cuePerDrawer[i],
                    now: now,
                  ),
              ],
            ),
          );
        },
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MedicationEditScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Assign med'),
      ),
    );
  }

  int _priority(DoseOccurrence o, DateTime now) {
    if (o.isPending && o.scheduledTime.isBefore(now)) return 4; // overdue
    if (o.log?.status == DoseStatus.taken) return 3;
    if (o.log?.status == DoseStatus.late) return 2;
    if (o.log?.status == DoseStatus.missed) return 2;
    if (o.isPending) return 1; // future pending
    return 0;
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.index,
    this.medication,
    this.cue,
    required this.now,
  });
  final int index;
  final Medication? medication;
  final DoseOccurrence? cue;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final assigned = medication != null;
    final scheme = Theme.of(context).colorScheme;
    final (bg, border, fg, label) = _colors(context, scheme);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: assigned ? 2 : 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$index',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              medication?.name ?? 'Empty',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg,
                  ),
            ),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Maps the dose cue → (background, border, foreground, status label).
  (Color, Color, Color, String?) _colors(
    BuildContext context,
    ColorScheme scheme,
  ) {
    if (medication == null) {
      return (
        scheme.surfaceContainer,
        scheme.outlineVariant,
        scheme.onSurfaceVariant,
        null,
      );
    }
    final s = context.statusColors;
    final c = cue;
    if (c != null) {
      if (c.isPending && c.scheduledTime.isBefore(now)) {
        return (s.dangerContainer, s.danger, s.onDangerContainer, 'OVERDUE');
      }
      switch (c.log?.status) {
        case DoseStatus.taken:
          return (s.successContainer, s.success, s.onSuccessContainer,
              'TAKEN');
        case DoseStatus.late:
          return (s.warningContainer, s.warning, s.onWarningContainer,
              'LATE');
        case DoseStatus.missed:
          return (s.dangerContainer, s.danger, s.onDangerContainer,
              'MISSED');
        case DoseStatus.skipped:
          return (s.warningContainer, s.warning, s.onWarningContainer,
              'SKIPPED');
        case null:
          // Future pending today
          return (scheme.primaryContainer, scheme.primary,
              scheme.onPrimaryContainer, 'DUE');
      }
    }
    return (
      scheme.primaryContainer,
      scheme.primary,
      scheme.onPrimaryContainer,
      null,
    );
  }

  void _open(BuildContext context) {
    final m = medication;
    if (m == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MedicationEditScreen()),
      );
      return;
    }
    // If a dose is due/overdue right now, open the Reminder screen so the
    // user can act on it immediately; otherwise show the info sheet.
    final c = cue;
    if (c != null && c.isPending) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ReminderScreen(
            medication: m,
            scheduledTime: c.scheduledTime,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DrawerSheet(medication: m),
    );
  }
}

class _DrawerSheet extends StatelessWidget {
  const _DrawerSheet({required this.medication});
  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final times = ([...medication.timesOfDay]..sort())
        .map((m) =>
            TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context))
        .join(', ');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Drawer ${medication.drawer}',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(medication.name,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _row(context, Icons.medication,
                medication.dosage.isEmpty ? '—' : medication.dosage),
            _row(context, Icons.schedule, times),
            _row(context, Icons.restaurant, medication.mealTiming.label),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MedicationEditScreen(
                            existing: medication,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
