import 'package:hive_ce/hive.dart';

/// What happened to a scheduled dose.
enum DoseStatus { taken, skipped, missed }

/// Where the log entry came from.
enum DoseSource { manual, device }

/// A record that a specific scheduled dose was taken/skipped.
///
/// "Missed" doses are *not* stored — they are derived at read time as any
/// past scheduled occurrence with no matching log. This keeps the store
/// append-only and avoids a background job just to write misses.
class DoseLog {
  DoseLog({
    required this.id,
    required this.medicationId,
    required this.scheduledTime,
    required this.status,
    this.actualTime,
    this.source = DoseSource.manual,
  });

  final String id;
  final String medicationId;
  final DateTime scheduledTime;
  DoseStatus status;
  DateTime? actualTime;
  DoseSource source;

  /// Stable key identifying the scheduled occurrence this log belongs to.
  static String occurrenceKey(String medicationId, DateTime scheduledTime) =>
      '$medicationId@${scheduledTime.millisecondsSinceEpoch}';

  String get key => occurrenceKey(medicationId, scheduledTime);
}

class DoseLogAdapter extends TypeAdapter<DoseLog> {
  @override
  final int typeId = 1;

  @override
  DoseLog read(BinaryReader reader) {
    final fields = reader.readMap().cast<int, dynamic>();
    return DoseLog(
      id: fields[0] as String,
      medicationId: fields[1] as String,
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      status: DoseStatus.values[fields[3] as int],
      actualTime: fields[4] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      source: DoseSource.values[fields[5] as int? ?? 0],
    );
  }

  @override
  void write(BinaryWriter writer, DoseLog obj) {
    writer.writeMap(<int, dynamic>{
      0: obj.id,
      1: obj.medicationId,
      2: obj.scheduledTime.millisecondsSinceEpoch,
      3: obj.status.index,
      4: obj.actualTime?.millisecondsSinceEpoch,
      5: obj.source.index,
    });
  }
}
