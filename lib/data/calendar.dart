/// Polish retail calendar: Sunday trading ban (Ustawa z 10.01.2018, as amended)
/// and statutory holidays when shops are closed. Dates are kept as data so they
/// can later be served by the backend and corrected without an app update.
const _tradingSundays = {
  '2026-01-25', '2026-03-29', '2026-04-26', '2026-06-28', '2026-08-30', '2026-12-06', '2026-12-13', '2026-12-20',
  '2027-01-31', '2027-03-21', '2027-04-25', '2027-06-27', '2027-08-29', '2027-12-05', '2027-12-12', '2027-12-19',
};

const _holidays = {
  '2026-01-01', '2026-01-06', '2026-04-05', '2026-04-06', '2026-05-01', '2026-05-03', '2026-05-24', '2026-06-04',
  '2026-08-15', '2026-11-01', '2026-11-11', '2026-12-24', '2026-12-25', '2026-12-26',
  '2027-01-01', '2027-01-06', '2027-03-28', '2027-03-29', '2027-05-01', '2027-05-03', '2027-05-16', '2027-05-27',
  '2027-08-15', '2027-11-01', '2027-11-11', '2027-12-24', '2027-12-25', '2027-12-26',
};

enum ShopDay { open, sundayClosed, holiday, tradingSunday }

String isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

ShopDay shopDay(DateTime d) {
  final k = isoDay(d);
  if (_holidays.contains(k)) return ShopDay.holiday;
  if (d.weekday == DateTime.sunday) return _tradingSundays.contains(k) ? ShopDay.tradingSunday : ShopDay.sundayClosed;
  return ShopDay.open;
}

bool shopsOpen(DateTime d) => shopDay(d) == ShopDay.open || shopDay(d) == ShopDay.tradingSunday;

DateTime nextSaturday(DateTime from) {
  final d = DateTime(from.year, from.month, from.day);
  final add = (DateTime.saturday - d.weekday + 7) % 7;
  return d.add(Duration(days: add == 0 ? 7 : add));
}

/// Poland (CET/CEST) is one hour behind Lithuania (EET/EEST) all year.
DateTime polishTime(DateTime lithuanianLocal) => lithuanianLocal.subtract(const Duration(hours: 1));
