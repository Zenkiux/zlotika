import 'deals.dart';

/// Finds this week's deals for a Polish shelf name (e.g. "Masło", "Filet z piersi kurczaka").
///
/// Polish inflects words ("kurczak" → "kurczaka"), so words are compared by stem
/// (first 4–6 letters). The product word must appear near the start of the deal name
/// ("Masło Extra 200 g" yes, "Chleb z masłem" no). Results are suggestions the shopper
/// picks from; nothing is attached to the list without a tap.
String _fold(String s) => s
    .toLowerCase()
    .replaceAll('ą', 'a').replaceAll('ć', 'c').replaceAll('ę', 'e').replaceAll('ł', 'l')
    .replaceAll('ń', 'n').replaceAll('ó', 'o').replaceAll('ś', 's').replaceAll('ź', 'z').replaceAll('ż', 'z');

List<String> _words(String s) => _fold(s).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();

const _stop = {'z', 'ze', 'w', 'na', 'do', 'i', 'dla', 'bez', 'od', 'po', 'o'};

String _stem(String w) => w.length <= 4 ? w : w.substring(0, w.length >= 7 ? 6 : w.length - 1);

/// Same word, allowing Polish endings (a few letters), but not a different longer
/// word that happens to start the same ("Mlekovita" is not "mleko").
bool _same(String w, String stem) =>
    stem.length <= 3 ? w == stem : (w.startsWith(stem) && (stem.length >= 6 || w.length <= stem.length + 4) && !_falseFriends.any(w.startsWith));

/// Words that start like a shopping word but are something else.
const _falseFriends = ['cukierk', 'chlebak', 'winogr', 'masci', 'olejek', 'zabawkow', 'mlecz'];

bool _has(List<String> words, String stem, {int within = 99}) {
  for (var i = 0; i < words.length && i < within; i++) {
    if (_same(words[i], stem)) return true;
  }
  return false;
}

/// Chains that sell no groceries worth matching food words against.
const _nonFoodChains = {'rossmann', 'hebe', 'pepco', 'action'};

List<Deal> matchDeals(String plName, Iterable<Deal> deals, {int max = 12, bool food = false}) {
  final keys = _words(plName).where((w) => !_stop.contains(w)).map(_stem).toList();
  if (keys.isEmpty) return const [];
  final head = keys.first;
  final out = <Deal>[];
  for (final d in deals) {
    if (food && _nonFoodChains.contains(d.chain)) continue;
    // Aldi names read "BRAND · Product · details": match on the product part.
    final parts = d.name.split(' · ');
    final product = parts.length > 1 ? parts[1] : d.name;
    final w = _words(product).where((x) => !_stop.contains(x)).toList();
    // The product word comes first ("Masło extra", not "Chleb z masłem"), or second
    // after a brand: an ALL-CAPS word ("RZEŹNIK Karkówka") or Rossmann's brand-first names.
    final first = product.trim().split(RegExp(r'\s+')).first;
    final brandFirst = d.chain == 'rossmann' || (first.length > 1 && first == first.toUpperCase() && first != first.toLowerCase());
    if (!_has(w, head, within: brandFirst ? 2 : 1)) continue;
    final all = _words(d.name);
    if (!keys.skip(1).every((k) => _has(all, k))) continue;
    out.add(d);
  }
  // Read-from-website deals before leaflet-OCR ones, then cheapest per unit when known.
  out.sort((a, b) {
    if (a.ocr != b.ocr) return a.ocr ? 1 : -1;
    final au = a.unitPrice, bu = b.unitPrice;
    if (au != null && bu != null && a.unit == b.unit) return au.compareTo(bu);
    return a.price.compareTo(b.price);
  });
  return out.take(max).toList();
}

/// Free-text watch ("Jacobs Krönung", "Pampers 4"): every word of 3+ letters
/// (or any number) appears somewhere in the deal name.
List<Deal> matchLoose(String query, Iterable<Deal> deals, {int max = 12}) {
  final keys = _words(query).where((w) => w.length >= 3 || RegExp(r'^\d+$').hasMatch(w)).map(_stem).toList();
  if (keys.isEmpty) return const [];
  final out = [
    for (final d in deals)
      if (keys.every((k) => _words(d.name).any((w) => w.startsWith(k)))) d
  ];
  out.sort((a, b) => a.ocr != b.ocr ? (a.ocr ? 1 : -1) : a.price.compareTo(b.price));
  return out.take(max).toList();
}
