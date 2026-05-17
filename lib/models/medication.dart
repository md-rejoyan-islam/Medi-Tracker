import 'package:hive_ce/hive.dart';

/// A medication the user takes on a fixed daily schedule.
///
/// [timesOfDay] holds minutes-from-midnight for each daily dose (e.g. 480 =
/// 08:00). [daysOfWeek] uses ISO weekday numbers (1 = Monday … 7 = Sunday);
/// an empty list means "every day". This keeps scheduling logic pure and
/// trivially testable without any platform calls.
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
    this.dispenserSlot,
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

  /// Optional slot index on a linked BLE pill dispenser. Null = not linked.
  int? dispenserSlot;
  bool active;

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
    int? dispenserSlot,
    bool clearDispenserSlot = false,
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
      dispenserSlot:
          clearDispenserSlot ? null : (dispenserSlot ?? this.dispenserSlot),
      active: active ?? this.active,
    );
  }
}

/// Manual Hive adapter (no codegen) so the build stays free of build_runner.
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
      dispenserSlot: fields[8] as int?,
      active: fields[9] as bool? ?? true,
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
      8: obj.dispenserSlot,
      9: obj.active,
    });
  }
}
