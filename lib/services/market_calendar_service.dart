class MarketCalendarService {
  MarketCalendarService._();

  static const int marketAlertScheduleWindowDays = 120;

  static const Map<int, Set<String>> _krxHolidayKeysByYear = {
    2025: {
      '2025-01-01',
      '2025-01-27',
      '2025-01-28',
      '2025-01-29',
      '2025-01-30',
      '2025-03-03',
      '2025-05-01',
      '2025-05-05',
      '2025-05-06',
      '2025-06-03',
      '2025-06-06',
      '2025-08-15',
      '2025-10-03',
      '2025-10-06',
      '2025-10-07',
      '2025-10-08',
      '2025-10-09',
      '2025-12-25',
      '2025-12-31',
    },
    2026: {
      '2026-01-01',
      '2026-02-16',
      '2026-02-17',
      '2026-02-18',
      '2026-03-02',
      '2026-05-01',
      '2026-05-05',
      '2026-05-25',
      '2026-06-03',
      '2026-08-17',
      '2026-09-24',
      '2026-09-25',
      '2026-10-05',
      '2026-10-09',
      '2026-12-25',
      '2026-12-31',
    },
  };

  static bool isKoreanTradingDay(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }

    final holidayKeys = _krxHolidayKeysByYear[date.year];
    if (holidayKeys == null) {
      return true;
    }

    return !holidayKeys.contains(_dateKey(date));
  }

  static Iterable<DateTime> upcomingKoreanTradingDays({
    required DateTime startDate,
    int windowDays = marketAlertScheduleWindowDays,
  }) sync* {
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    for (var offset = 0; offset < windowDays; offset++) {
      final candidate = firstDay.add(Duration(days: offset));
      if (isKoreanTradingDay(candidate)) {
        yield candidate;
      }
    }
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
