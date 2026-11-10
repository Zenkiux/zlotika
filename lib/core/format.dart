import 'i18n.dart';

String _num(double v, int digits, Lang lang) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(digits);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final sep = lang == Lang.lt ? ' ' : ',';
  final b = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) b.write(sep);
    b.write(intPart[i]);
  }
  final dec = parts.length > 1 ? '${lang == Lang.lt ? ',' : '.'}${parts[1]}' : '';
  return '${neg ? '−' : ''}$b$dec';
}

String fmtNum(double v, Lang lang, {int digits = 1}) => _num(v, digits, lang);

/// "12,50 €" (LT) / "€12.50" (EN).
String eur(double v, Lang lang, {int digits = 2}) {
  final n = _num(v, digits, lang);
  if (lang == Lang.lt) return '$n €';
  return n.startsWith('−') ? '−€${n.substring(1)}' : '€$n';
}

/// "+12,50 €" with explicit sign.
String eurSigned(double v, Lang lang) => '${v >= 0.005 ? '+' : ''}${eur(v, lang)}';

/// Złoty as shown on Polish shelves: "12,99 zł".
String zl(double v, Lang lang) => '${_num(v, 2, lang)} zł';

double? parseAmount(String s) {
  final t = s.trim().replaceAll(' ', '').replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return (v == null || v < 0 || v > 100000) ? null : v;
}

const _ltMonths = ['sausio', 'vasario', 'kovo', 'balandžio', 'gegužės', 'birželio', 'liepos', 'rugpjūčio', 'rugsėjo', 'spalio', 'lapkričio', 'gruodžio'];
const _enMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _ltDays = ['pirmadienis', 'antradienis', 'trečiadienis', 'ketvirtadienis', 'penktadienis', 'šeštadienis', 'sekmadienis'];
const _enDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "lapkričio 14 d." / "14 November".
String dayMonth(DateTime d, Lang lang) => lang == Lang.lt ? '${_ltMonths[d.month - 1]} ${d.day} d.' : '${d.day} ${_enMonths[d.month - 1]}';
String weekday(DateTime d, Lang lang) => (lang == Lang.lt ? _ltDays : _enDays)[d.weekday - 1];
String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
