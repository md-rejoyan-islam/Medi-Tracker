import 'dart:async';

import 'package:flutter/material.dart';

import '../data/medi_store.dart';
import '../models/dose_log.dart';
import '../models/medication.dart';

/// Spec §6 Reminder Screen: full-screen "Medication Due" prompt for a single
/// scheduled dose, with the drawer number called out and Taken / Skip
/// actions. The matching drawer LED on the device blinks in parallel; this
/// screen mirrors that with a pulsing visual cue.
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({
    super.key,
    required this.medication,
    required this.scheduledTime,
  });

  final Medication medication;
  final DateTime scheduledTime;

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late Timer _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _tick = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _tick.cancel();
    super.dispose();
  }

  Future<void> _record(DoseStatus status) async {
    await MediStore.instance.recordDose(
      medicationId: widget.medication.id,
      scheduledTime: widget.scheduledTime,
      status: status,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medication;
    final overdue = widget.scheduledTime.isBefore(_now);
    final timeText = TimeOfDay.fromDateTime(widget.scheduledTime)
        .format(context);
    // Mirrors the spec's RGB LED table: green-blinking when due, red when
    // overdue. White-blinking (BLE pair) lives in the Pair screen.
    final cueColor = overdue ? Colors.red : Colors.green;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Dismiss without recording',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Spacer(),
              Text(
                overdue ? 'OVERDUE' : 'MEDICATION DUE',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      letterSpacing: 2,
                      color: cueColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                m.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (m.dosage.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(m.dosage,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
              const SizedBox(height: 32),
              if (m.drawer != null) _DrawerCue(drawer: m.drawer!,
                  color: cueColor, pulse: _pulse),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _MetaChip(icon: Icons.schedule, label: timeText),
                  _MetaChip(
                    icon: Icons.restaurant,
                    label: m.mealTiming.label,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _record(DoseStatus.skipped),
                      icon: const Icon(Icons.do_not_disturb_on_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Skip'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _record(DoseStatus.taken),
                      icon: const Icon(Icons.check),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Taken'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerCue extends StatelessWidget {
  const _DrawerCue({
    required this.drawer,
    required this.color,
    required this.pulse,
  });
  final int drawer;
  final Color color;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10 + t * 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25 + t * 0.35),
                blurRadius: 20 + t * 20,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Open Drawer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$drawer',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
