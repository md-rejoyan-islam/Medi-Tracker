import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../data/adherence.dart';
import '../data/medi_store.dart';
import '../models/dose_log.dart';
import '../models/medication.dart';
import 'reports_screen.dart';

/// Spec §7 + §8: per-dose daily history timeline and aggregated Reports
/// (Daily / Weekly / Monthly charts). Two tabs in one shell so the History
/// nav destination covers both halves of the spec without a 6th tab.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Timeline'),
              Tab(icon: Icon(Icons.show_chart), text: 'Reports'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TimelineTab(),
            ReportsTab(),
          ],
        ),
      ),
    );
  }
}

/// Daily timeline grouped by date, newest first, matching the spec
/// example: "22 May / 08:00 ✓ Taken / 13:00 ✓ Taken / 20:00 ✗ Missed".
class _TimelineTab extends StatefulWidget {
  const _TimelineTab();

  @override
  State<_TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<_TimelineTab> {
  int _days = 7;

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
        final days = <DateTime>[
          for (int i = 0; i < _days; i++)
            DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: i)),
        ];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Show last:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _days,
                    onChanged: (v) =>
                        v == null ? null : setState(() => _days = v),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 days')),
                      DropdownMenuItem(value: 14, child: Text('14 days')),
                      DropdownMenuItem(value: 30, child: Text('30 days')),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final day = days[i];
                  final occ = occurrencesForDay(
                    medications: store.medications,
                    lookupLog: store.logFor,
                    day: day,
                    now: now,
                  );
                  if (occ.isEmpty) return const SizedBox.shrink();
                  return _DayBlock(day: day, occurrences: occ, now: now);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.day,
    required this.occurrences,
    required this.now,
  });
  final DateTime day;
  final List<DoseOccurrence> occurrences;
  final DateTime now;

  String _dayLabel(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final today = DateTime(now.year, now.month, now.day);
    final yest = today.subtract(const Duration(days: 1));
    if (d == today) return 'Today';
    if (d == yest) return 'Yesterday';
    return '${d.day} ${months[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _dayLabel(day),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < occurrences.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _DoseLine(occurrences[i], now),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseLine extends StatelessWidget {
  const _DoseLine(this.o, this.now);
  final DoseOccurrence o;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(o.scheduledTime).format(context);
    final m = o.medication;
    final (label, color, icon) = _statusUi(o);
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(
        '$time  ·  ${m.name}'
        '${m.drawer != null ? '  ·  Drawer ${m.drawer}' : ''}',
      ),
      subtitle: m.dosage.isEmpty ? null : Text(m.dosage),
      trailing: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  (String, Color, IconData) _statusUi(DoseOccurrence o) {
    if (o.log != null) {
      switch (o.log!.status) {
        case DoseStatus.taken:
          return ('Taken', Colors.green, Icons.check_circle);
        case DoseStatus.late:
          return ('Late', Colors.orange, Icons.access_time_filled);
        case DoseStatus.skipped:
          return ('Skipped', Colors.orange, Icons.do_not_disturb_on);
        case DoseStatus.missed:
          return ('Missed', Colors.red, Icons.cancel);
      }
    }
    if (o.scheduledTime.isBefore(now)) {
      return ('Missed', Colors.red, Icons.cancel_outlined);
    }
    return ('Pending', Colors.grey, Icons.schedule);
  }
}

/// Per-medication helper used by the Reports tab.
List<Medication> medicationsSnapshot() =>
    MediStore.instance.medications
      ..sort((a, b) => a.name.compareTo(b.name));
