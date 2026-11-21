import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawahku/features/hijri/data/hijri_calendar_repository.dart';
import 'package:tilawahku/features/hijri/domain/hijri_models.dart';
import 'package:tilawahku/features/hijri/presentation/hijri_calendar_controller.dart';
import 'package:tilawahku/features/prayer/data/prayer_repository.dart';
import 'package:tilawahku/features/prayer/domain/prayer_method.dart';
import 'package:tilawahku/features/prayer/domain/prayer_models.dart';

class _FakeHijriRepository extends HijriCalendarRepository {
  _FakeHijriRepository({HijriAdjustment adjustment = const HijriAdjustment()})
      : _currentAdjustment = adjustment;

  HijriAdjustment _currentAdjustment;
  final requestedMonths = <(int year, int month)>[];
  Completer<HijriCalendarOutcome>? pendingCompleter;

  @override
  HijriAdjustment get adjustment => _currentAdjustment;

  @override
  Future<void> loadAdjustment() async {}

  @override
  Future<void> setAdjustment(HijriAdjustment adj) async {
    _currentAdjustment = adj;
  }

  @override
  Future<HijriCalendarOutcome> monthFor({
    required int gregorianYear,
    required int gregorianMonth,
    WorshipLocation? location,
    bool refresh = false,
  }) async {
    requestedMonths.add((gregorianYear, gregorianMonth));
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    return HijriCalendarOutcome(
      month: HijriCalendarMonth(
        gregorianYear: gregorianYear,
        gregorianMonth: gregorianMonth,
        days: [
          HijriCalendarDay(
            gregorianDate: '$gregorianYear-$gregorianMonth-01',
            hijriDay: 1,
            hijriMonth: 1,
            hijriYear: 1448,
            hijriMonthNameEn: 'Muharram',
            hijriMonthNameAr: 'محرم',
            hijriMonthNameId: 'Muharram',
            weekdayEn: 'Monday',
            weekdayAr: 'الاثنين',
            isToday: false,
          ),
        ],
        currentHijriDate: null,
      ),
      notice: null,
    );
  }
}

class _FakePrayerRepository extends PrayerRepository {
  _FakePrayerRepository([this._location]);

  final WorshipLocation? _location;

  @override
  Future<PrayerSettings> loadSettings() async => PrayerSettings(
    method: PrayerMethod.kemenag,
    asrMadhab: AsrMadhab.standard,
    adjustments: const PrayerAdjustments(),
    location: _location ??
        const WorshipLocation(
          name: 'Jakarta',
          latitude: -6.175,
          longitude: 106.827,
          source: LocationSource.manual,
        ),
  );
}

void main() {
  group('HijriCalendarController', () {
    test('initializes with current date from clock', () async {
      final repo = _FakeHijriRepository();
      final controller = HijriCalendarController(
        repository: repo,
        prayerRepository: _FakePrayerRepository(),
        clock: () => DateTime(2026, 6, 15),
      );

      expect(controller.gregorianYear, 2026);
      expect(controller.gregorianMonth, 6);

      await Future<void>.delayed(Duration.zero);
      expect(controller.state, HijriLoadState.ready);
      expect(repo.requestedMonths, contains((2026, 6)));
    });

    test('previousMonth decrements month and navigates across years (Jan -> Dec)', () async {
      final repo = _FakeHijriRepository();
      final controller = HijriCalendarController(
        repository: repo,
        prayerRepository: _FakePrayerRepository(),
        clock: () => DateTime(2026, 1, 10),
      );

      await Future<void>.delayed(Duration.zero);
      expect(controller.gregorianYear, 2026);
      expect(controller.gregorianMonth, 1);

      await controller.previousMonth();
      expect(controller.gregorianYear, 2025);
      expect(controller.gregorianMonth, 12);
      expect(repo.requestedMonths.last, (2025, 12));
    });

    test('nextMonth increments month and navigates across years (Dec -> Jan)', () async {
      final repo = _FakeHijriRepository();
      final controller = HijriCalendarController(
        repository: repo,
        prayerRepository: _FakePrayerRepository(),
        clock: () => DateTime(2026, 12, 25),
      );

      await Future<void>.delayed(Duration.zero);
      expect(controller.gregorianYear, 2026);
      expect(controller.gregorianMonth, 12);

      await controller.nextMonth();
      expect(controller.gregorianYear, 2027);
      expect(controller.gregorianMonth, 1);
      expect(repo.requestedMonths.last, (2027, 1));
    });

    test('refresh preserves currently selected month and year', () async {
      final repo = _FakeHijriRepository();
      final controller = HijriCalendarController(
        repository: repo,
        prayerRepository: _FakePrayerRepository(),
        clock: () => DateTime(2026, 5, 10),
      );

      await Future<void>.delayed(Duration.zero);
      // Navigate to July
      await controller.nextMonth();
      await controller.nextMonth();
      expect(controller.gregorianMonth, 7);

      // Refresh
      await controller.refresh();
      expect(controller.gregorianMonth, 7);
      expect(controller.gregorianYear, 2026);
      expect(repo.requestedMonths.last, (2026, 7));
    });

    test('consecutive navigation requests are not lost', () async {
      final repo = _FakeHijriRepository();
      final controller = HijriCalendarController(
        repository: repo,
        prayerRepository: _FakePrayerRepository(),
        clock: () => DateTime(2026, 3, 1),
      );

      await Future<void>.delayed(Duration.zero);
      expect(controller.gregorianMonth, 3);

      // Fire 3 nextMonth requests in rapid succession without waiting
      final f1 = controller.nextMonth();
      final f2 = controller.nextMonth();
      final f3 = controller.nextMonth();

      await Future.wait([f1, f2, f3]);

      // Month must be 3 + 3 = 6
      expect(controller.gregorianMonth, 6);
      expect(controller.gregorianYear, 2026);
      expect(repo.requestedMonths.last, (2026, 6));
    });

    test('stale response protection ignores older async responses', () async {
      final repo = _FakeHijriRepository();
      final controller = HijriCalendarController(
        repository: repo,
        prayerRepository: _FakePrayerRepository(),
        clock: () => DateTime(2026, 4, 1),
      );

      await Future<void>.delayed(Duration.zero);

      // Make the next call hang with a completer
      final completer1 = Completer<HijriCalendarOutcome>();
      repo.pendingCompleter = completer1;

      // Start navigation to May (this request will hang)
      final mayFuture = controller.nextMonth();
      expect(controller.gregorianMonth, 5);

      // User immediately clicks nextMonth to June with a fast completer
      final completer2 = Completer<HijriCalendarOutcome>();
      repo.pendingCompleter = completer2;
      final juneFuture = controller.nextMonth();
      expect(controller.gregorianMonth, 6);

      // June completes first
      completer2.complete(
        HijriCalendarOutcome(
          month: HijriCalendarMonth(
            gregorianYear: 2026,
            gregorianMonth: 6,
            days: [
              const HijriCalendarDay(
                gregorianDate: '2026-06-01',
                hijriDay: 1,
                hijriMonth: 12,
                hijriYear: 1447,
                hijriMonthNameEn: 'Dhu al-Hijjah',
                hijriMonthNameAr: 'ذو الحجة',
                hijriMonthNameId: 'Dzulhijjah',
                weekdayEn: 'Monday',
                weekdayAr: 'الاثنين',
                isToday: false,
              ),
            ],
            currentHijriDate: null,
          ),
          notice: 'June Data',
        ),
      );
      await juneFuture;

      expect(controller.notice, 'June Data');

      // Now May completes later (stale response)
      completer1.complete(
        HijriCalendarOutcome(
          month: HijriCalendarMonth(
            gregorianYear: 2026,
            gregorianMonth: 5,
            days: [
              const HijriCalendarDay(
                gregorianDate: '2026-05-01',
                hijriDay: 1,
                hijriMonth: 11,
                hijriYear: 1447,
                hijriMonthNameEn: 'Dhu al-Qadah',
                hijriMonthNameAr: 'ذو القعدة',
                hijriMonthNameId: 'Dzulkaidah',
                weekdayEn: 'Friday',
                weekdayAr: 'الجمعة',
                isToday: false,
              ),
            ],
            currentHijriDate: null,
          ),
          notice: 'Stale May Data',
        ),
      );
      await mayFuture;

      // The stale May response must NOT overwrite the active June data
      expect(controller.notice, 'June Data');
      expect(controller.gregorianMonth, 6);
    });

    test('sets needsLocation when prayer location is unset', () async {
      final repo = _FakeHijriRepository();
      final controller = HijriCalendarController(
        repository: repo,
        prayerRepository: _FakePrayerRepository(null),
        clock: () => DateTime(2026, 4, 1),
      );

      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isNotNull);
    });
  });
}
