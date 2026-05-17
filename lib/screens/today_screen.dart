import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../data/adherence.dart';
import '../data/medi_store.dart';
import '../models/dose_log.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MediStore.instance;
    final listenable = Listenable.merge([
      store.medicationsBox.listenable(),
      store.logsBox.listenable(),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
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
          if (occ.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nothing scheduled today.\nAdd medications in the Meds tab.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: occ.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _DoseRow(occ[i], now),
          );
        },
      ),
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

    Color? color;
    IconData icon;
    switch (o.status) {
      case DoseStatus.taken when o.log != null:
        color = Colors.green;
        icon = Icons.check_circle;
      case DoseStatus.skipped when o.log != null:
        color = Colors.orange;
        icon = Icons.do_not_disturb_on;
      case DoseStatus.missed when o.log != null:
        color = Colors.red;
        icon = Icons.cancel;
      default:
        color = overdue ? Colors.red : null;
        icon = overdue ? Icons.error_outline : Icons.schedule;
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(o.medication.name),
      subtitle: Text(
        [
          time,
          if (o.medication.dosage.isNotEmpty) o.medication.dosage,
          if (o.log != null) '· ${o.log!.status.name}',
          if (overdue) '· overdue',
        ].join('  '),
      ),
      trailing: o.log == null
          ? Row(
              mainAxisSize: MainAxisSize.min,
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
}
