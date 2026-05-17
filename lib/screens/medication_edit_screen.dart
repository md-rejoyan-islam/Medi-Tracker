import 'package:flutter/material.dart';

import '../data/medi_store.dart';
import '../models/medication.dart';
import '../services/reminder_service.dart';

/// Add or edit a [Medication]. Pass null to create a new one.
class MedicationEditScreen extends StatefulWidget {
  const MedicationEditScreen({super.key, this.existing});
  final Medication? existing;

  @override
  State<MedicationEditScreen> createState() => _MedicationEditScreenState();
}

class _MedicationEditScreenState extends State<MedicationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _notes;

  // Schedule state
  final List<int> _times = []; // minutes from midnight
  final Set<int> _days = {}; // ISO weekdays; empty = every day
  late DateTime _start;
  DateTime? _end;
  bool _active = true;
  int? _dispenserSlot;

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _dosage = TextEditingController(text: m?.dosage ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _times.addAll(m?.timesOfDay ?? const [480]); // default 08:00
    _days.addAll(m?.daysOfWeek ?? const []);
    _start = m?.startDate ?? DateTime.now();
    _end = m?.endDate;
    _active = m?.active ?? true;
    _dispenserSlot = m?.dispenserSlot;
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _fmt(int minutes) {
    final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return t.format(context);
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    if (!_times.contains(minutes)) {
      setState(() {
        _times
          ..add(minutes)
          ..sort();
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : (_end ?? _start);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one reminder time.')),
      );
      return;
    }

    final old = widget.existing;
    final med = Medication(
      id: old?.id ??
          'med_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      dosage: _dosage.text.trim(),
      timesOfDay: [..._times]..sort(),
      daysOfWeek: _days.toList()..sort(),
      startDate: _start,
      endDate: _end,
      notes: _notes.text.trim(),
      dispenserSlot: _dispenserSlot,
      active: _active,
    );

    await MediStore.instance.saveMedication(med);

    if (!ReminderService.instance.supported) {
      // no-op platform
    } else {
      await ReminderService.instance.requestPermission();
      await ReminderService.instance.sync(med);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit medication' : 'Add medication'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. Metformin',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosage,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                hintText: 'e.g. 1 tablet, 500 mg',
              ),
            ),
            const SizedBox(height: 24),
            Text('Reminder times',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _times)
                  InputChip(
                    label: Text(_fmt(t)),
                    onDeleted: () => setState(() => _times.remove(t)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Add time'),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Repeat on', style: Theme.of(context).textTheme.titleMedium),
            const Text(
              'Leave all unselected for every day.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text(_weekdayLabels[i - 1]),
                    selected: _days.contains(i),
                    onSelected: (sel) => setState(
                      () => sel ? _days.add(i) : _days.remove(i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(_dateLabel(_start)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End date'),
              subtitle: Text(_end == null ? 'No end' : _dateLabel(_end!)),
              trailing: _end == null
                  ? const Icon(Icons.calendar_today)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _end = null),
                    ),
              onTap: () => _pickDate(isStart: false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Off pauses reminders without deleting'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'e.g. take with food',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
