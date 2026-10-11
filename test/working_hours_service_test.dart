import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livreur_app/services/working_hours_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('working hours use weekday, enabled state, and exclusive end time', () {
    final service = WorkingHoursService();
    final mondayAtNine = DateTime(2026, 10, 12, 9);
    final mondayAtFive = DateTime(2026, 10, 12, 17);
    final saturdayAtTen = DateTime(2026, 10, 17, 10);

    expect(service.isWorkingAt(mondayAtNine), isTrue);
    expect(service.isWorkingAt(mondayAtFive), isFalse);
    expect(service.isWorkingAt(saturdayAtTen), isFalse);
  });

  test('weekly hours persist on device and can be edited', () async {
    final service = WorkingHoursService();
    await service.load();
    await service.updateDay(
      DateTime.saturday,
      const DailyWorkingHours(
        enabled: true,
        start: TimeOfDay(hour: 10, minute: 0),
        end: TimeOfDay(hour: 14, minute: 0),
      ),
    );

    final reloaded = WorkingHoursService();
    await reloaded.load();

    expect(reloaded.isWorkingAt(DateTime(2026, 10, 17, 12)), isTrue);
    expect(reloaded.isWorkingAt(DateTime(2026, 10, 17, 15)), isFalse);
  });

  test('invalid same-day time range is rejected', () async {
    final service = WorkingHoursService();
    await service.load();

    await expectLater(
      service.updateDay(
        DateTime.monday,
        const DailyWorkingHours(
          enabled: true,
          start: TimeOfDay(hour: 17, minute: 0),
          end: TimeOfDay(hour: 9, minute: 0),
        ),
      ),
      throwsArgumentError,
    );
  });
}
