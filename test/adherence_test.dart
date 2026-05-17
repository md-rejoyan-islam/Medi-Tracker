import 'package:bluetooth_ble/data/adherence.dart';
import 'package:bluetooth_ble/models/dose_log.dart';
import 'package:bluetooth_ble/models/medication.dart';
import 'package:flutter_test/flutter_test.dart';

Medication _med({
  String id = 'm1',
  List<int> times = const [480, 1200], // 08:00, 20:00
  List<int> days = const [],
  DateTime? start,
  DateTime? end,
  bool active = true,
}) {
  return Medication(
    id: id,
    name: 'Test',
    dosage: '1 tab',
    timesOfDay: times,
    daysOfWeek: days,
    startDate: start ?? DateTime(2026, 1, 1),
    endDate: end,
    active: active,
  );
}

void main() {
  group('Medication scheduling', () {
    test('isScheduledOn respects start/end window', () {
      final m = _med(start: DateTime(2026, 5, 10), end: DateTime(2026, 5, 12));
      expect(m.isScheduledOn(DateTime(2026, 5, 9)), isFalse);
      expect(m.isScheduledOn(DateTime(2026, 5, 10)), isTrue);
      expect(m.isScheduledOn(DateTime(2026, 5, 12)), isTrue);
      expect(m.isScheduledOn(DateTime(2026, 5, 13)), isFalse);
    });

    test('isScheduledOn filters by weekday when set', () {
      // 2026-05-18 is a Monday.
      final m = _med(days: const [1, 3]); // Mon, Wed
      expect(m.isScheduledOn(DateTime(2026, 5, 18)), isTrue); // Mon
      expect(m.isScheduledOn(DateTime(2026, 5, 19)), isFalse); // Tue
      expect(m.isScheduledOn(DateTime(2026, 5, 20)), isTrue); // Wed
    });

    test('inactive medication is never scheduled', () {
      expect(_med(active: false).isScheduledOn(DateTime(2026, 5, 18)), isFalse);
    });

    test('doseTimesOn returns sorted concrete times', () {
      final m = _med(times: const [1200, 480]);
      final t = m.doseTimesOn(DateTime(2026, 5, 18));
      expect(t, [
        DateTime(2026, 5, 18, 8, 0),
        DateTime(2026, 5, 18, 20, 0),
      ]);
    });
  });

  group('occurrencesForDay', () {
    test('past dose with no log is missed; future dose is pending', () {
      final m = _med(times: const [480, 1200]);
      final now = DateTime(2026, 5, 18, 12, 0); // between the two doses
      final occ = occurrencesForDay(
        medications: [m],
        lookupLog: (_, _) => null,
        day: now,
        now: now,
      );
      expect(occ.length, 2);
      expect(occ[0].status, DoseStatus.missed); // 08:00 passed, no log
      expect(occ[0].isPending, isTrue); // still actionable (no log)
      expect(occ[1].isPending, isTrue); // 20:00 future
    });

    test('logged dose reflects its stored status', () {
      final m = _med(times: const [480]);
      final now = DateTime(2026, 5, 18, 12, 0);
      final logged = DoseLog(
        id: 'l1',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 5, 18, 8, 0),
        status: DoseStatus.taken,
      );
      final occ = occurrencesForDay(
        medications: [m],
        lookupLog: (id, t) => t == logged.scheduledTime ? logged : null,
        day: now,
        now: now,
      );
      expect(occ.single.status, DoseStatus.taken);
      expect(occ.single.isPending, isFalse);
    });
  });

  group('computeAdherence', () {
    test('counts taken/missed/skipped over a range', () {
      final m = _med(times: const [480], start: DateTime(2026, 5, 16));
      final logs = <String, DoseLog>{
        DoseLog.occurrenceKey('m1', DateTime(2026, 5, 16, 8, 0)): DoseLog(
          id: 'a',
          medicationId: 'm1',
          scheduledTime: DateTime(2026, 5, 16, 8, 0),
          status: DoseStatus.taken,
        ),
        DoseLog.occurrenceKey('m1', DateTime(2026, 5, 17, 8, 0)): DoseLog(
          id: 'b',
          medicationId: 'm1',
          scheduledTime: DateTime(2026, 5, 17, 8, 0),
          status: DoseStatus.skipped,
        ),
        // 2026-05-18 left unlogged -> missed (it is in the past vs now)
      };
      final now = DateTime(2026, 5, 18, 23, 0);
      final s = computeAdherence(
        medications: [m],
        lookupLog: (id, t) =>
            logs[DoseLog.occurrenceKey(id, t)],
        from: DateTime(2026, 5, 16),
        to: DateTime(2026, 5, 18),
        now: now,
      );
      expect(s.scheduled, 3);
      expect(s.taken, 1);
      expect(s.skipped, 1);
      expect(s.missed, 1);
      expect(s.rate, closeTo(1 / 3, 1e-9));
    });

    test('rate is 0 when nothing decided yet', () {
      final m = _med(times: const [480], start: DateTime(2026, 5, 20));
      final now = DateTime(2026, 5, 19, 12, 0); // before any dose
      final s = computeAdherence(
        medications: [m],
        lookupLog: (_, _) => null,
        from: DateTime(2026, 5, 20),
        to: DateTime(2026, 5, 20),
        now: now,
      );
      expect(s.taken, 0);
      expect(s.rate, 0);
    });
  });
}
