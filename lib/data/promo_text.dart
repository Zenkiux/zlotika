import '../core/i18n.dart' show Lang;

/// Translates Polish promotion conditions from leaflets ("drugi za 5 zł, limit
/// dzienny 2 szt. na kartę MB") into Lithuanian or English. Phrases it doesn't
/// know stay in Polish, so nothing is ever guessed.
class _Rule {
  const _Rule(this.re, this.lt, this.en);
  final RegExp re;
  final String Function(Match m) lt, en;
}

RegExp _r(String p) => RegExp(p, caseSensitive: false, unicode: true);
String _n(String? s) => (s ?? '').replaceAll('.', ',');

final _rules = <_Rule>[
  _Rule(_r(r'limit dzienny (\d+) (?:szt\.?|sztuk|opak\.?)(?: gratis)?(?: za [\d,.]+ zł)? na kart[ęe] MB\.?'),
      (m) => 'ne daugiau ${m[1]} vnt. per dieną su Moja Biedronka kortele', (m) => 'max ${m[1]} per day with the Moja Biedronka card'),
  _Rule(_r(r'limit dzienny (\d+) (?:szt\.?|sztuk|opak\.?)(?: gratis)?'), (m) => 'ne daugiau ${m[1]} vnt. per dieną', (m) => 'max ${m[1]} per day'),
  _Rule(_r(r'(\d+)\s*\+\s*(\d+)\s*(?:opakowanie\s*)?gratis'), (m) => 'pirkite ${m[1]}, ${m[2]} gausite nemokamai', (m) => 'buy ${m[1]}, get ${m[2]} free'),
  _Rule(_r(r'drugi tańszy produkt za ([\d,.]+) zł'), (m) => 'pigesnis iš dviejų už ${_n(m[1])} zł', (m) => 'cheaper of two for ${_n(m[1])} zł'),
  _Rule(_r(r'drugi za ([\d,.]+) zł(/kg)?'), (m) => 'antras už ${_n(m[1])} zł${m[2] ?? ''}', (m) => 'second one for ${_n(m[1])} zł${m[2] ?? ''}'),
  _Rule(_r(r'trzeci za ([\d,.]+) zł'), (m) => 'trečias už ${_n(m[1])} zł', (m) => 'third one for ${_n(m[1])} zł'),
  _Rule(_r(r'drugi (\d+)\s*% taniej'), (m) => 'antras ${m[1]} % pigiau', (m) => 'second one ${m[1]}% off'),
  _Rule(_r(r'-?(\d+)\s*% co drug[aą] szt\.?'), (m) => 'kas antras ${m[1]} % pigiau', (m) => 'every second one ${m[1]}% off'),
  _Rule(_r(r'(?:-(\d+)\s*% )?przy zakupie (\d+)(-paku)?(?: szt\.?)?'),
      (m) => '${m[1] != null ? '−${m[1]} % ' : ''}perkant ${m[2]}${m[3] != null ? ' vnt. pakuotę' : ' vnt.'}',
      (m) => '${m[1] != null ? '${m[1]}% off ' : ''}when buying ${m[2]}${m[3] != null ? '-pack' : ''}'),
  _Rule(_r(r'każda z (\d+) sztuk'), (m) => 'kaina už vienetą, perkant ${m[1]}', (m) => 'price each, when buying ${m[1]}'),
  _Rule(_r(r'(\d+)\s*% taniej'), (m) => '${m[1]} % pigiau', (m) => '${m[1]}% off'),
  _Rule(_r(r'mieszaj dowolnie'), (m) => 'galima maišyti rūšis', (m) => 'mix any kinds'),
  _Rule(_r(r'z kartą lub apką'), (m) => 'su kortele arba programėle', (m) => 'with the card or app'),
  _Rule(_r(r'różne rodzaje'), (m) => 'įvairių rūšių', (m) => 'various kinds'),
  _Rule(_r(r'różne wzory'), (m) => 'įvairių raštų', (m) => 'various designs'),
  _Rule(_r(r'do wyboru'), (m) => 'galima rinktis', (m) => 'choice of kinds'),
  _Rule(_r(r'cena ?za ?1 ?szt\.?'), (m) => 'kaina už 1 vnt.', (m) => 'price for 1'),
  _Rule(_r(r'(\d+) sztuk[ia]?\b'), (m) => '${m[1]} vnt.', (m) => '${m[1]} pcs'),
  _Rule(_r(r'(\d+) el\.'), (m) => '${m[1]} dalių', (m) => '${m[1]} pieces'),
  _Rule(_r(r'^od (\d{1,2})\.(\d{1,2})$'), (m) => 'nuo ${m[2]}-${m[1]}', (m) => 'from ${m[1]}/${m[2]}'),
  _Rule(_r(r'^od$'), (m) => 'kaina nuo', (m) => 'from'),
];

/// The promotion text in the app's language.
String promoText(String pl, Lang lang) {
  var s = pl.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'\s*\.$'), '');
  for (final r in _rules) {
    s = s.replaceAllMapped(r.re, (m) => '\u0000${lang == Lang.lt ? r.lt(m) : r.en(m)}\u0001');
  }
  s = s.replaceAll('\u0000', '').replaceAll('\u0001', '').replaceAll(' / ', ', ');
  return s.isEmpty ? pl : s[0].toUpperCase() + s.substring(1);
}

/// True when every Polish word was translated (so the original isn't needed alongside).
bool promoFullyTranslated(String pl, Lang lang) => !RegExp(r'\b(za|szt|sztuk|przy|zakupie|gratis|taniej|drugi|limit|dzienny|kart|każda|mieszaj)\b', caseSensitive: false, unicode: true)
    .hasMatch(promoText(pl, lang));

/// "Drugi za 5 zł" leaflets print 5 zł as the price, which is only the second item.
/// The honest price per item is what two (or three) cost together, divided.
({double price, int qty})? multibuyUnitPrice(String? multibuy, double price, double? oldPrice) {
  if (multibuy == null || oldPrice == null) return null;
  final m = _r(r'\b(drugi|trzeci)(?: tańszy produkt)? za ([\d,.]+) zł(?!/)').firstMatch(multibuy);
  if (m == null) return null;
  final x = double.tryParse(m[2]!.replaceAll(',', '.'));
  if (x == null || (x - price).abs() > 0.01 || oldPrice <= x) return null;
  final n = m[1]!.toLowerCase() == 'drugi' ? 2 : 3;
  return (price: ((oldPrice * (n - 1) + x) / n * 100).roundToDouble() / 100, qty: n);
}
