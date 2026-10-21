import 'dart:math' as math;

/// Persian-facing formatting helpers. Technical values are converted to
/// Persian digits only when they are labels; serialized and copyable values
/// always keep ASCII digits.
class PersianFormat {
  const PersianFormat._();

  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const Duration _tehranOffset = Duration(hours: 3, minutes: 30);

  static String digits(Object? value) {
    final String text = value?.toString() ?? '';
    final StringBuffer buffer = StringBuffer();
    for (final int rune in text.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.write(_faDigits[rune - 0x30]);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static String percent(double fraction) {
    return '${digits((fraction.clamp(0, 1) * 100).round())}٪';
  }

  static String plural(int count, String singular, String plural) {
    return '${digits(count)} ${count == 1 ? singular : plural}';
  }

  static String binary(List<bool> bits) {
    return bits.map((bool bit) => bit ? '1' : '0').join();
  }

  static String relativeDate(DateTime date, {DateTime? now}) {
    final DateTime localNow = (now ?? DateTime.now()).toLocal();
    final DateTime localDate = date.toLocal();
    final DateTime today = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    );
    final DateTime day = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
    final int difference = today.difference(day).inDays;

    if (difference == 0) {
      final String hour = localDate.hour.toString().padLeft(2, '0');
      final String minute = localDate.minute.toString().padLeft(2, '0');
      return 'امروز، ${digits(hour)}:${digits(minute)}';
    }
    if (difference == 1) {
      return 'دیروز';
    }
    if (difference > 1 && difference < 7) {
      return '${digits(difference)} روز پیش';
    }
    return jalaliDate(localDate);
  }

  static String jalaliDate(DateTime date) {
    final JalaliDate jalali = JalaliConverter.fromDateTime(date);
    return '${digits(jalali.day)} ${jalali.monthName} ${digits(jalali.year)}';
  }

  static String jalaliShort(DateTime date) {
    final JalaliDate jalali = JalaliConverter.fromDateTime(date);
    return '${digits(jalali.year)}/${digits(jalali.month.toString().padLeft(2, '0'))}/${digits(jalali.day.toString().padLeft(2, '0'))}';
  }

  /// Converts a wall-clock time to Iran Standard Time. Used for the clock in
  /// the home dashboard, not for stored timestamps.
  static DateTime tehranNow([DateTime? now]) {
    final DateTime utc = (now ?? DateTime.now()).toUtc();
    return utc.add(_tehranOffset);
  }

  static String clock(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '${digits(hour)}:${digits(minute)}';
  }
}

class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const List<String> monthNames = <String>[
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  String get monthName => monthNames[month - 1];

  @override
  String toString() => '$year/$month/$day';

  @override
  bool operator ==(Object other) {
    return other is JalaliDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Accurate Gregorian/Jalali conversion using the Borkowski break-year
/// algorithm (the same rule used by the widely deployed jalaali-js library).
/// It supports the modern range covered by the break table.
class JalaliConverter {
  const JalaliConverter._();

  static const List<int> _breaks = <int>[
    -61,
    9,
    38,
    199,
    426,
    686,
    756,
    818,
    1111,
    1181,
    1210,
    1635,
    2060,
    2097,
    2192,
    2262,
    2324,
    2394,
    2456,
    3178,
  ];

  static int _div(int a, int b) => (a / b).floor();
  static int _mod(int a, int b) => a - _div(a, b) * b;

  static ({int gy, int march, int leap}) _jalCal(int jy) {
    final int bl = _breaks.length;
    final int gy = jy + 621;
    int leapJ = -14;
    int jp = _breaks[0];
    int jump = 0;

    if (jy < jp || jy >= _breaks[bl - 1]) {
      throw ArgumentError('Jalali year out of supported range: $jy');
    }

    for (int i = 1; i < bl; i++) {
      final int jm = _breaks[i];
      jump = jm - jp;
      if (jy < jm) {
        break;
      }
      leapJ += _div(jump, 33) * 8 + _div(_mod(jump, 33), 4);
      jp = jm;
    }
    int n = jy - jp;
    leapJ += _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4);
    if (_mod(jump, 33) == 4 && jump - n == 4) {
      leapJ += 1;
    }

    final int leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150;
    final int march = 20 + leapJ - leapG;

    if (jump - n < 6) {
      n = n - jump + _div(jump + 4, 33) * 33;
    }
    int leap = _mod(_mod(n + 1, 33) - 1, 4);
    if (leap == -1) {
      leap = 4;
    }
    return (gy: gy, march: march, leap: leap);
  }

  static int _g2d(int gy, int gm, int gd) {
    int d =
        _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) +
        _div(153 * _mod(gm + 9, 12) + 2, 5) +
        gd -
        34840408;
    d = d - _div(_div(gy + _div(gm - 8, 6) + 100100, 100) * 3, 4) + 752;
    return d;
  }

  static ({int gy, int gm, int gd}) _d2g(int jdn) {
    int j = 4 * jdn + 139361631;
    j += _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
    final int i = _div(_mod(j, 1461), 4) * 5 + 308;
    final int gd = _div(_mod(i, 153), 5) + 1;
    final int gm = _mod(_div(i, 153), 12) + 1;
    final int gy = _div(j, 1461) - 100100 + _div(8 - gm, 6);
    return (gy: gy, gm: gm, gd: gd);
  }

  static JalaliDate fromDateTime(DateTime date) {
    final DateTime local = date.toLocal();
    final int jdn = _g2d(local.year, local.month, local.day);
    final int gy = _d2g(jdn).gy;
    int jy = gy - 621;
    final ({int gy, int march, int leap}) r = _jalCal(jy);
    final int jdn1f = _g2d(r.gy, 3, r.march);
    int k = jdn - jdn1f;
    if (k >= 0) {
      if (k <= 185) {
        final int jm = 1 + _div(k, 31);
        final int jd = _mod(k, 31) + 1;
        return JalaliDate(jy, jm, jd);
      }
      k -= 186;
    } else {
      jy -= 1;
      k += 179;
      if (r.leap == 1) {
        k += 1;
      }
    }
    final int jm = 7 + _div(k, 30);
    final int jd = _mod(k, 30) + 1;
    return JalaliDate(jy, jm, jd);
  }

  static bool isLeapYear(int jy) => _jalCal(jy).leap == 0;

  static int daysInMonth(int jy, int jm) {
    if (jm <= 6) {
      return 31;
    }
    if (jm <= 11) {
      return 30;
    }
    return isLeapYear(jy) ? 30 : 29;
  }

  /// A convenience range for tests and diagnostics.
  static int daysBetween(DateTime a, DateTime b) {
    return a.toLocal().difference(b.toLocal()).inDays.abs();
  }

  static String formatWeekday(DateTime date) {
    const List<String> weekdays = <String>[
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
      'شنبه',
      'یکشنبه',
    ];
    return weekdays[date.weekday - 1];
  }

  static String greeting([DateTime? now]) {
    final int hour = (now ?? DateTime.now()).hour;
    if (hour < 12) {
      return 'صبح بخیر';
    }
    if (hour < 18) {
      return 'بعدازظهر بخیر';
    }
    return 'شب بخیر';
  }

  static String factorialLabel(int n) {
    if (n > 20) {
      return 'بزرگ';
    }
    int value = 1;
    for (int i = 2; i <= n; i++) {
      value *= i;
    }
    return PersianFormat.digits(value);
  }

  static String clampName(String input, int maxLength) {
    final String trimmed = input.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, math.max(1, maxLength - 1))}…';
  }
}
