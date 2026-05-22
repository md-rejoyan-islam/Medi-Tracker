import 'package:bluetooth_ble/services/reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: notification IDs must fit in Android's int32 NotificationManager
/// limit. A 64-bit Dart int that exceeds 2^31-1 silently truncates on the
/// Android side, causing different medications to collide on the same ID and
/// drop scheduled reminders. (Was the root cause of "test notifications fire
/// but real medication reminders don't" in v1.3.0/v1.3.1.)
void main() {
  group('ReminderService notification IDs', () {
    test('stay within Android int32 range for every (minute, weekday)', () {
      // 2^31 - 1
      const int32Max = 2147483647;
      // Drive a few hash buckets through the full schedule space.
      const medIds = [
        'med_1716397500123456',
        'med_z',
        'med_aaaaaaaaaaaaaaaa',
        'med_${0x7FFFFFFF}',
      ];
      for (final id in medIds) {
        for (var min = 0; min < 1440; min++) {
          for (var wd = 0; wd <= 7; wd++) {
            final n =
                ReminderService.notificationIdForTest(id, min, wd);
            expect(n, greaterThanOrEqualTo(0),
                reason: 'negative id for $id $min $wd');
            expect(n, lessThanOrEqualTo(int32Max),
                reason: 'overflow for $id $min $wd → $n');
          }
        }
      }
    });

    test('different (medId, time, weekday) tuples produce different IDs', () {
      // Within one medication, no two (minute, weekday) slots may collide
      // — that's what caused doses to overwrite each other.
      const medId = 'med_collision_check';
      final seen = <int>{};
      for (var min = 0; min < 1440; min++) {
        for (var wd = 0; wd <= 7; wd++) {
          final n =
              ReminderService.notificationIdForTest(medId, min, wd);
          expect(seen.add(n), isTrue,
              reason: 'duplicate id $n for $medId min=$min wd=$wd');
        }
      }
    });
  });
}
