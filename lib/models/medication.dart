import 'package:hive_ce/hive.dart';

/// When the dose is meant to be taken relative to meals.
///
/// Matches the spec's "Before Meal / After Meal / Any Time" option and is
/// serialised as the BLE payload's `meal` field
/// (`before_meal` / `after_meal` / `any_time`).
enum MealTiming {
  anyTime('any_time', 'Any time'),
  beforeMeal('before_meal', 'Before meal'),
  afterMeal('after_meal', 'After meal');

  const MealTiming(this.wire, this.label);
  final String wire;
  final String label;
}

/// Reminder frequency presets from the spec. `custom` means the user picked
/// each time manually.
enum Frequency { onceDaily, twiceDaily, threeTimesDaily, custom }

/// A medication assigned to a drawer on the MediTracker hardware device.
///
/// [timesOfDay] holds minutes-from-midnight for each daily dose (e.g. 480 =
/// 08:00). [daysOfWeek] uses ISO weekday numbers (1 = Monday … 7 = Sunday);
/// an empty list means "every day". [drawer] is the physical drawer index
/// (1..8) on the device. Scheduling logic stays pure and trivially testable
/// without any platform calls.
class Medication {
  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.timesOfDay,
    this.daysOfWeek = const [],
    required this.startDate,
    this.endDate,
    this.notes = '',
    this.drawer,
    this.mealTiming = MealTiming.anyTime,
    this.active = true,
  });

  final String id;
  String name;
  String dosage;
  List<int> timesOfDay;
  List<int> daysOfWeek;
  DateTime startDate;
  DateTime? endDate;
  String notes;

  /// Physical drawer (1..8) on the MediTracker hardware. Null = not yet
  /// assigned to a drawer (the device cannot fire reminders for it).
  int? drawer;
  MealTiming mealTiming;
  bool active;

  /// Back-compat alias: previous releases called this `dispenserSlot`.
  int? get dispenserSlot => drawer;
  set dispenserSlot(int? v) => drawer = v;

  /// The preset that produced [timesOfDay] (derived, not stored).
  Frequency get frequency {
    return switch (timesOfDay.length) {
      1 => Frequency.onceDaily,
      2 => Frequency.twiceDaily,
      3 => Frequency.threeTimesDaily,
      _ => Frequency.custom,
    };
  }

  /// Whether this medication is scheduled to be taken on [day]
  /// (date component only).
  bool isScheduledOn(DateTime day) {
    if (!active) return false;
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(start)) return false;
    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (d.isAfter(end)) return false;
    }
    if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(d.weekday)) return false;
    return true;
  }

  /// The concrete dose date-times scheduled on [day], sorted ascending.
  List<DateTime> doseTimesOn(DateTime day) {
    if (!isScheduledOn(day)) return const [];
    final sorted = [...timesOfDay]..sort();
    return [
      for (final m in sorted)
        DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
    ];
  }

  Medication copyWith({
    String? name,
    String? dosage,
    List<int>? timesOfDay,
    List<int>? daysOfWeek,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    String? notes,
    int? drawer,
    bool clearDrawer = false,
    MealTiming? mealTiming,
    bool? active,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timesOfDay: timesOfDay ?? this.timesOfDay,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
      drawer: clearDrawer ? null : (drawer ?? this.drawer),
      mealTiming: mealTiming ?? this.mealTiming,
      active: active ?? this.active,
    );
  }

  /// JSON the phone sends to the nRF52832 over BLE (see spec §3).
  Map<String, dynamic> toDeviceJson() => {
        'drawer': drawer,
        'medicine': name,
        'times': [
          for (final m in [...timesOfDay]..sort())
            '${(m ~/ 60).toString().padLeft(2, '0')}:'
                '${(m % 60).toString().padLeft(2, '0')}',
        ],
        'meal': mealTiming.wire,
      };

  /// Helper used by the schedule UI to derive times from a [Frequency] preset.
  /// Returns minutes-from-midnight matching the preset's typical schedule.
  static List<int> defaultTimesFor(Frequency f) {
    return switch (f) {
      Frequency.onceDaily => const [480], // 08:00
      Frequency.twiceDaily => const [480, 1200], // 08:00, 20:00
      Frequency.threeTimesDaily => const [480, 780, 1200], // 08, 13, 20
      Frequency.custom => const [],
    };
  }
}

/// Manual Hive adapter (no codegen) so the build stays free of build_runner.
///
/// Field IDs are append-only — never repurpose an existing ID. Unknown future
/// fields are tolerated by `fields[N] as T?`, and missing legacy fields
/// fall back to sensible defaults so older records load cleanly.
class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 0;

  @override
  Medication read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return Medication(
      id: fields[0] as String,
      name: fields[1] as String,
      dosage: fields[2] as String,
      timesOfDay: (fields[3] as List).cast<int>(),
      daysOfWeek: (fields[4] as List).cast<int>(),
      startDate: DateTime.fromMillisecondsSinceEpoch(fields[5] as int),
      endDate: fields[6] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[6] as int),
      notes: fields[7] as String? ?? '',
      drawer: fields[8] as int?,
      active: fields[9] as bool? ?? true,
      mealTiming: MealTiming.values[fields[10] as int? ?? 0],
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    writer.writeMap(<int, dynamic>{
      0: obj.id,
      1: obj.name,
      2: obj.dosage,
      3: obj.timesOfDay,
      4: obj.daysOfWeek,
      5: obj.startDate.millisecondsSinceEpoch,
      6: obj.endDate?.millisecondsSinceEpoch,
      7: obj.notes,
      8: obj.drawer,
      9: obj.active,
      10: obj.mealTiming.index,
    });
  }
}
