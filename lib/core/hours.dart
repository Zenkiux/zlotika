import '../data/calendar.dart';

/// Time in Poland, whatever time zone the phone is in.
/// CET (UTC+1); CEST (UTC+2) from the last Sunday of March to the last Sunday of
/// October, switching at 01:00 UTC (EU rule). Lithuania is always one hour ahead.
DateTime _lastSunday(int y, int m) {
  final d = DateTime.utc(y, m + 1, 0);
  return d.subtract(Duration(days: d.weekday % 7));
}

int plUtcOffset(DateTime utc) {
  final start = _lastSunday(utc.year, 3).add(const Duration(hours: 1));
  final end = _lastSunday(utc.year, 10).add(const Duration(hours: 1));
  return (!utc.isBefore(start) && utc.isBefore(end)) ? 2 : 1;
}

/// Polish wall-clock time. The returned value is only for reading fields (hour, weekday…).
DateTime plNow([DateTime? now]) {
  final u = (now ?? DateTime.now()).toUtc();
  final p = u.add(Duration(hours: plUtcOffset(u)));
  return DateTime(p.year, p.month, p.day, p.hour, p.minute);
}

/// Minutes from midnight, `to` may be 1440.
class Span {
  const Span(this.from, this.to);
  final int from, to;
  @override
  bool operator ==(Object other) => other is Span && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
  @override
  String toString() => '${fmtMin(from)}–${fmtMin(to)}';
}

String fmtMin(int m) => m == 1440 ? '24:00' : '${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

const _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _ph = 8; // public holiday slot

/// The common subset of OpenStreetMap `opening_hours`: weekday ranges and lists,
/// several time spans, `off`, `24/7`, `PH`. Rules with dates or months are skipped.
class OpeningHours {
  OpeningHours._(this._days);
  final Map<int, List<Span>> _days; // 1..7 = Mo..Su, 8 = PH

  static final _month = RegExp(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|week|easter|SH)\b');
  static final _dayTok = r'(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?';
  static final _rule = RegExp('^((?:$_dayTok)(?:\\s*,\\s*$_dayTok)*)?\\s*(.*)\$');
  static final _span = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$');

  static OpeningHours? parse(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    final days = <int, List<Span>>{};
    if (text == '24/7') {
      for (var d = 1; d <= _ph; d++) {
        days[d] = const [Span(0, 1440)];
      }
      return OpeningHours._(days);
    }
    final rules = text.split(';').expand((r) => r.split(RegExp(r'(?<=\d|off)\s*,\s*(?=(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)\b)')));
    for (var rule in rules) {
      rule = rule.trim();
      if (rule.isEmpty || _month.hasMatch(rule)) continue;
      final m = _rule.firstMatch(rule);
      if (m == null) continue;
      final dayPart = m.group(1);
      final rest = m.group(2)!.trim();
      if (rest.isEmpty) continue;
      final set = dayPart == null ? [1, 2, 3, 4, 5, 6, 7] : _expandDays(dayPart);
      List<Span>? spans;
      if (rest == 'off' || rest == 'closed') {
        spans = const [];
      } else {
        final list = <Span>[];
        var ok = true;
        for (final part in rest.split(',')) {
          final t = _span.firstMatch(part.trim());
          final from = t == null ? 0 : int.parse(t.group(1)!) * 60 + int.parse(t.group(2)!);
          final to = t == null ? 0 : int.parse(t.group(3)!) * 60 + int.parse(t.group(4)!);
          if (t == null || to <= from || to > 1440) {
            ok = false;
            break;
          }
          list.add(Span(from, to));
        }
        spans = ok ? list : null;
      }
      if (spans == null) continue;
      for (final d in set) {
        days[d] = spans;
      }
    }
    return days.isEmpty ? null : OpeningHours._(days);
  }

  static List<int> _expandDays(String part) {
    final out = <int>[];
    for (final tok in part.split(',')) {
      final t = tok.trim();
      if (t == 'PH') {
        out.add(_ph);
        continue;
      }
      final ends = t.split('-');
      final a = _dayNames.indexOf(ends.first) + 1;
      final b = ends.length > 1 ? _dayNames.indexOf(ends[1]) + 1 : a;
      if (a == 0 || b == 0) continue;
      for (var d = a;; d = d % 7 + 1) {
        out.add(d);
        if (d == b) break;
      }
    }
    return out;
  }

  /// Spans for a weekday (1 = Monday). Null when the data says nothing about that day.
  List<Span>? weekday(int d) => _days[d];
  List<Span>? get holiday => _days[_ph];
}

enum HoursKind { open, lawClosed, closed, unknown }

/// What a shop does on one Polish calendar day.
class DayHours {
  const DayHours(this.kind, [this.spans = const []]);
  final HoursKind kind;
  final List<Span> spans;

  int? get opens => spans.isEmpty ? null : spans.first.from;
  int? get closes => spans.isEmpty ? null : spans.last.to;

  @override
  String toString() => '$kind $spans';
}

/// Hours on a Polish date. Shops (not fuel stations) are closed on non-trading
/// Sundays and public holidays by law, whatever the map says.
DayHours dayHours(OpeningHours? oh, DateTime plDate, {bool fuel = false}) {
  final day = shopDay(plDate);
  if (!fuel && (day == ShopDay.sundayClosed || day == ShopDay.holiday)) return const DayHours(HoursKind.lawClosed);
  if (oh == null) return const DayHours(HoursKind.unknown);
  final spans = (day == ShopDay.holiday ? oh.holiday : null) ?? oh.weekday(plDate.weekday);
  if (spans == null) {
    // "Mo-Sa 06:00-22:00" says nothing about Sunday; on an ordinary Sunday OSM convention is closed.
    return plDate.weekday == DateTime.sunday && day != ShopDay.tradingSunday ? const DayHours(HoursKind.closed) : const DayHours(HoursKind.unknown);
  }
  return spans.isEmpty ? const DayHours(HoursKind.closed) : DayHours(HoursKind.open, spans);
}

enum NowKind { open, opensLater, closedForDay, notToday }

/// Open now? `minute` is the Polish time of day in minutes.
({NowKind kind, int? at}) nowStatus(DayHours h, int minute) {
  if (h.kind != HoursKind.open) return (kind: NowKind.notToday, at: null);
  for (final s in h.spans) {
    if (minute < s.from) return (kind: NowKind.opensLater, at: s.from);
    if (minute < s.to) return (kind: NowKind.open, at: s.to);
  }
  return (kind: NowKind.closedForDay, at: null);
}
