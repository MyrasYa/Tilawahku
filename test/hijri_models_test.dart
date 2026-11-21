import 'package:flutter_test/flutter_test.dart';

import 'package:tilawahku/features/hijri/domain/hijri_models.dart';

void main() {
  group('HijriAdjustment', () {
    test('default is 0 days', () {
      const adjustment = HijriAdjustment();
      expect(adjustment.days, 0);
      expect(adjustment.isValid, true);
      expect(adjustment.isActive, false);
    });

    test('valid range -2 to +2', () {
      for (final days in [-2, -1, 0, 1, 2]) {
        final adjustment = HijriAdjustment(days);
        expect(adjustment.days, days);
        expect(adjustment.isValid, true);
      }
    });

    test('clamps out of range values', () {
      expect(HijriAdjustment(-3).validated().days, -2);
      expect(HijriAdjustment(-3).validated().isValid, true);
      expect(HijriAdjustment(3).validated().days, 2);
      expect(HijriAdjustment(3).validated().isValid, true);
    });

    test('set clamps to valid range', () {
      final adjustment = const HijriAdjustment(0).set(5);
      expect(adjustment.days, 2);
      expect(adjustment.isValid, true);
    });

    test('toMap and fromMap', () {
      const adjustment = HijriAdjustment(1);
      final map = adjustment.toMap();
      expect(map['hijri_adjustment_days'], 1);

      final restored = HijriAdjustment.fromMap(map);
      expect(restored.days, 1);
    });

    test('fromMap handles invalid values', () {
      expect(HijriAdjustment.fromMap({}).days, 0);
      expect(HijriAdjustment.fromMap({'hijri_adjustment_days': -5}).days, -2);
      expect(HijriAdjustment.fromMap({'hijri_adjustment_days': 10}).days, 2);
    });
  });

  group('HijriCalendarDay', () {
    test('creates with required fields', () {
      const day = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: true,
      );

      expect(day.gregorianDate, '2024-12-01');
      expect(day.hijriDay, 27);
      expect(day.hijriMonth, 9);
      expect(day.hijriYear, 1446);
      expect(day.isToday, true);
    });

    test('displayLabel formats correctly', () {
      const day = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: false,
      );

      expect(day.displayLabel, '27 Ramadan 1446 H');
    });

    test('arabicLabel formats correctly', () {
      const day = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: false,
      );

      expect(day.arabicLabel, 'رمضان 1446');
    });

    test('withAdjustment shifts Hijri date forward', () {
      const day = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: false,
      );

      final adjusted = day.withAdjustment(2);
      expect(adjusted.hijriDay, 29);
      expect(adjusted.hijriMonth, 9);
      expect(adjusted.hijriYear, 1446);
    });

    test('withAdjustment shifts Hijri date backward', () {
      const day = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 2,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: false,
      );

      final adjusted = day.withAdjustment(-2);
      expect(adjusted.hijriDay, 29);
      expect(adjusted.hijriMonth, 8);
      expect(adjusted.hijriYear, 1446);
    });
  });

  group('HijriCalendarMonth', () {
    test('creates with days and current date', () {
      const currentDay = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: true,
      );

      final days = [
        currentDay,
        const HijriCalendarDay(
          gregorianDate: '2024-12-02',
          hijriDay: 28,
          hijriMonth: 9,
          hijriYear: 1446,
          hijriMonthNameEn: 'Ramadan',
          hijriMonthNameAr: 'رمضان',
          hijriMonthNameId: 'Ramadan',
          weekdayEn: 'Monday',
          weekdayAr: 'الاثنين',
          isToday: false,
        ),
      ];

      final month = HijriCalendarMonth(
        gregorianYear: 2024,
        gregorianMonth: 12,
        days: days,
        currentHijriDate: currentDay,
      );

      expect(month.gregorianYear, 2024);
      expect(month.gregorianMonth, 12);
      expect(month.days.length, 2);
      expect(month.currentHijriDate, currentDay);
    });

    test('findByGregorianDate finds matching day', () {
      const day1 = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: false,
      );

      const day2 = HijriCalendarDay(
        gregorianDate: '2024-12-02',
        hijriDay: 28,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Monday',
        weekdayAr: 'الاثنين',
        isToday: false,
      );

      final month = HijriCalendarMonth(
        gregorianYear: 2024,
        gregorianMonth: 12,
        days: [day1, day2],
        currentHijriDate: null,
      );

      final found = month.findByGregorianDate('2024-12-02');
      expect(found, day2);
    });

    test('findByGregorianDate returns null for non-existent date', () {
      const day = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: false,
      );

      final month = HijriCalendarMonth(
        gregorianYear: 2024,
        gregorianMonth: 12,
        days: [day],
        currentHijriDate: null,
      );

      final found = month.findByGregorianDate('2024-12-02');
      expect(found, isNull);
    });

    test('withAdjustment applies to all days', () {
      const day1 = HijriCalendarDay(
        gregorianDate: '2024-12-01',
        hijriDay: 27,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Sunday',
        weekdayAr: 'الاحد',
        isToday: false,
      );

      const day2 = HijriCalendarDay(
        gregorianDate: '2024-12-02',
        hijriDay: 28,
        hijriMonth: 9,
        hijriYear: 1446,
        hijriMonthNameEn: 'Ramadan',
        hijriMonthNameAr: 'رمضان',
        hijriMonthNameId: 'Ramadan',
        weekdayEn: 'Monday',
        weekdayAr: 'الاثنين',
        isToday: false,
      );

      final month = HijriCalendarMonth(
        gregorianYear: 2024,
        gregorianMonth: 12,
        days: [day1, day2],
        currentHijriDate: day1,
      );

      final adjusted = month.withAdjustment(1);
      expect(adjusted.days[0].hijriDay, 28);
      expect(adjusted.days[1].hijriDay, 29);
      expect(adjusted.currentHijriDate?.hijriDay, 28);
    });
  });

  group('IslamicEvent', () {
    test('creates with required fields', () {
      const event = IslamicEvent(
        hijriDay: 1,
        hijriMonth: 1,
        nameId: 'Tahun Baru Islam',
        description: 'Awal tahun Hijriah.',
      );

      expect(event.hijriDay, 1);
      expect(event.hijriMonth, 1);
      expect(event.nameId, 'Tahun Baru Islam');
      expect(event.description, 'Awal tahun Hijriah.');
    });

    test('hijriKey formats correctly', () {
      const event = IslamicEvent(
        hijriDay: 10,
        hijriMonth: 1,
        nameId: 'Hari Asyura',
        description: 'Hari ke-10 bulan Muharram.',
      );

      expect(event.hijriKey, '01-10');
    });
  });

  group('IslamicEvents', () {
    test('instance returns singleton', () {
      final instance1 = IslamicEvents.instance;
      final instance2 = IslamicEvents.instance;
      expect(identical(instance1, instance2), true);
    });

    test('findByHijriKey finds event', () {
      final events = IslamicEvents.instance;
      final event = events.findByHijriKey('01-01');
      expect(event, isNotNull);
      expect(event?.nameId, 'Tahun Baru Islam');
    });

    test('findByHijriKey returns null for non-existent event', () {
      final events = IslamicEvents.instance;
      final event = events.findByHijriKey('13-13');
      expect(event, isNull);
    });

    test('all returns all events', () {
      final events = IslamicEvents.instance.all;
      expect(events.length, 8);
      expect(events.any((e) => e.nameId == 'Maulid Nabi'), true);
      expect(events.any((e) => e.nameId == 'Idul Fitri'), true);
      expect(events.any((e) => e.nameId == 'Idul Adha'), true);
    });
  });
}
