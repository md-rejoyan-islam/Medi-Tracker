import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../data/medi_store.dart';
import '../models/medication.dart';
import '../services/reminder_service.dart';
import 'medication_edit_screen.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  String _scheduleSummary(BuildContext context, Medication m) {
    final times = ([...m.timesOfDay]..sort())
        .map((min) =>
            TimeOfDay(hour: min ~/ 60, minute: min % 60).format(context))
        .join(', ');
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = m.daysOfWeek.isEmpty
        ? 'every day'
        : (m.daysOfWeek.toList()..sort())
            .map((d) => labels[d - 1])
            .join(', ');
    return '$times · $days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      body: ValueListenableBuilder(
        valueListenable: MediStore.instance.medicationsBox.listenable(),
        builder: (context, Box<Medication> box, _) {
          final meds = box.values.toList()
            ..sort((a, b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (meds.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No medications yet.\nTap + to add one and start '
                  'getting reminders.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: meds.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = meds[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    m.drawer?.toString() ?? '–',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  m.name,
                  style: TextStyle(
                    decoration:
                        m.active ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  [
                    if (m.dosage.isNotEmpty) m.dosage,
                    _scheduleSummary(context, m),
                    m.mealTiming.label,
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      _openEdit(context, m);
                    } else if (v == 'delete') {
                      final ok = await _confirmDelete(context, m);
                      if (ok) {
                        await ReminderService.instance.cancel(m.id);
                        await MediStore.instance.deleteMedication(m.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => _openEdit(context, m),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _openEdit(BuildContext context, Medication? m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationEditScreen(existing: m),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Medication m) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${m.name}?'),
        content: const Text(
          'This also removes its dose history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}
