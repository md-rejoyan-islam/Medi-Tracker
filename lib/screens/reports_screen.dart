import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../data/adherence.dart';
import '../data/medi_store.dart';

/// Spec §8 Reports: weekly summary + Daily / Weekly / Monthly charts.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

enum _ChartRange { daily, weekly, monthly }

class _ReportsTabState extends State<ReportsTab> {
  _ChartRange _range = _ChartRange.daily;

  @override
  Widget build(BuildContext context) {
    final store = MediStore.instance;
    final listenable = Listenable.merge([
      store.medicationsBox.listenable(),
      store.logsBox.listenable(),
    ]);
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekly = computeAdherence(
          medications: store.medications,
          lookupLog: store.logFor,
          from: weekStart,
          to: now,
          now: now,
        );
        final buckets = _buildBuckets(now);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeekSummary(stats: weekly),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Adherence trend',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                SegmentedButton<_ChartRange>(
                  segments: const [
                    ButtonSegment(
                        value: _ChartRange.daily, label: Text('Daily')),
                    ButtonSegment(
                        value: _ChartRange.weekly, label: Text('Weekly')),
                    ButtonSegment(
                        value: _ChartRange.monthly,
                        label: Text('Monthly')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) =>
                      setState(() => _range = s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: _AdherenceBarChart(buckets: buckets)),
          ],
        );
      },
    );
  }

  /// Buckets of (label, adherence-rate 0..1) for the chosen range.
  List<({String label, double rate})> _buildBuckets(DateTime now) {
    final store = MediStore.instance;
    switch (_range) {
      case _ChartRange.daily:
        // Last 7 days
        return List.generate(7, (i) {
          final d = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: 6 - i));
          final s = computeAdherence(
            medications: store.medications,
            lookupLog: store.logFor,
            from: d,
            to: d,
            now: now,
          );
          return (label: _shortDay(d), rate: s.rate);
        });
      case _ChartRange.weekly:
        // Last 6 weeks
        return List.generate(6, (i) {
          final end = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: 7 * (5 - i)));
          final start = end.subtract(const Duration(days: 6));
          final s = computeAdherence(
            medications: store.medications,
            lookupLog: store.logFor,
            from: start,
            to: end,
            now: now,
          );
          return (label: 'W${i + 1}', rate: s.rate);
        });
      case _ChartRange.monthly:
        // Last 6 months
        return List.generate(6, (i) {
          final monthOffset = 5 - i;
          final monthDate =
              DateTime(now.year, now.month - monthOffset, 1);
          final next = DateTime(monthDate.year, monthDate.month + 1, 1);
          final end = next.subtract(const Duration(days: 1));
          final s = computeAdherence(
            medications: store.medications,
            lookupLog: store.logFor,
            from: monthDate,
            to: end,
            now: now,
          );
          return (label: _shortMonth(monthDate), rate: s.rate);
        });
    }
  }

  String _shortDay(DateTime d) {
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[d.weekday - 1];
  }

  String _shortMonth(DateTime d) {
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return m[d.month];
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.stats});
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
            Text('This week',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$pct%',
                  style:
                      Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _rateColor(stats.rate, context),
                          ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _legend(context, 'Taken', stats.taken, Colors.green),
                      _legend(context, 'Late', stats.late, Colors.orange),
                      _legend(context, 'Missed', stats.missed, Colors.red),
                      _legend(context, 'Skipped', stats.skipped,
                          Colors.orange.shade300),
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

  Widget _legend(BuildContext context, String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: $value'),
      ],
    );
  }
}

class _AdherenceBarChart extends StatelessWidget {
  const _AdherenceBarChart({required this.buckets});
  final List<({String label, double rate})> buckets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 1,
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, horizontalInterval: 0.25),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 0.25,
              getTitlesWidget: (v, _) => Text(
                '${(v * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    buckets[i].label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].rate.clamp(0.0, 1.0),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  color: _rateColor(buckets[i].rate, context),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 1,
                    color: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

Color _rateColor(double rate, BuildContext context) {
  if (rate >= 0.8) return Colors.green;
  if (rate >= 0.5) return Colors.orange;
  return Theme.of(context).colorScheme.error;
}
