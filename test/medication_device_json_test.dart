import 'package:bluetooth_ble/models/medication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toDeviceJson matches the spec §3 example', () {
    final m = Medication(
      id: 'm1',
      name: 'Metformin',
      dosage: '1 tablet',
      timesOfDay: const [1200, 480], // 20:00, 08:00 (unsorted on purpose)
      startDate: DateTime(2026, 5, 22),
      drawer: 3,
      mealTiming: MealTiming.afterMeal,
    );
    expect(m.toDeviceJson(), {
      'drawer': 3,
      'medicine': 'Metformin',
      'times': ['08:00', '20:00'],
      'meal': 'after_meal',
    });
  });

  test('defaultTimesFor produces sensible preset schedules', () {
    expect(Medication.defaultTimesFor(Frequency.onceDaily), [480]);
    expect(Medication.defaultTimesFor(Frequency.twiceDaily), [480, 1200]);
    expect(
      Medication.defaultTimesFor(Frequency.threeTimesDaily),
      [480, 780, 1200],
    );
    expect(Medication.defaultTimesFor(Frequency.custom), isEmpty);
  });
}
