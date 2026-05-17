import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../data/adherence.dart';
import '../data/medi_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final store = MediStore.instance;
    final listenable = Listenable.merge([
      store.medicationsBox.listenable(),
      store.logsBox.listenable(),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _days,
            onSelected: (v) => setState(() => _days = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
              PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Text('$_days d'),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final now = DateTime.now();
          final from = now.subtract(Duration(days: _days - 1));
          final overall = computeAdherence(
            medications: store.medications,
            lookupLog: store.logFor,
            from: from,
            to: now,
            now: now,
          );
          final meds = store.medications
            ..sort((a, b) => a.name.compareTo(b.name));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OverallCard(stats: overall),
              const SizedBox(height: 16),
              if (meds.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No medications to report on.')),
                )
              else
                for (final m in meds)
                  Builder(builder: (context) {
                    final s = computeAdherence(
                      medications: [m],
                      lookupLog: store.logFor,
                      from: from,
                      to: now,
                      now: now,
                    );
                    return Card(
                      child: ListTile(
                        title: Text(m.name),
                        subtitle: Text(
                          'Taken ${s.taken} · Missed ${s.missed} · '
                          'Skipped ${s.skipped} of ${s.scheduled}',
                        ),
                        trailing: Text(
                          '${(s.rate * 100).round()}%',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: _rateColor(s.rate, context),
                              ),
                        ),
                      ),
                    );
                  }),
            ],
          );
        },
      ),
    );
  }
}

Color _rateColor(double rate, BuildContext context) {
  if (rate >= 0.8) return Colors.green;
  if (rate >= 0.5) return Colors.orange;
  return Theme.of(context).colorScheme.error;
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.stats});
  final AdherenceStats stats;

  @override
  Widget build(BuildContext context) {
    final pct = (stats.rate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overall adherence',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$pct%',
                  style:
                      Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: _rateColor(stats.rate, context),
                            fontWeight: FontWeight.bold,
                          ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Stat('Taken', stats.taken, Colors.green),
                      _Stat('Missed', stats.missed, Colors.red),
                      _Stat('Skipped', stats.skipped, Colors.orange),
                      _Stat('Scheduled', stats.scheduled, Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stats.rate,
                minHeight: 8,
                color: _rateColor(stats.rate, context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('$label: $value'),
        ],
      ),
    );
  }
}
