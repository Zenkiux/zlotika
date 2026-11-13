import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'deals.dart';

/// Typical shelf price for one vocabulary item in one country, from the daily collector:
/// Lithuania from Barbora (Maxima online), Poland from Rossmann (and Frisco when enabled).
class RefPrice {
  const RefPrice({required this.source, required this.unit, required this.n, required this.unitMin, required this.unitMedian, required this.pkgMedian, required this.exName, required this.exPrice, required this.exUnitPrice, required this.exUrl});

  final String source; // 'Barbora', 'Rossmann', 'Frisco'
  final String unit; // 'kg' | 'l' | 'units'
  final int n;
  final double unitMin, unitMedian, pkgMedian;
  final String exName, exUrl; // a popular product used as the example
  final double exPrice, exUnitPrice;

  /// Size of the example package, in [unit].
  double get exQty => exUnitPrice > 0 ? exPrice / exUnitPrice : 0;

  factory RefPrice.fromJson(Map<String, dynamic> j) {
    final ex = j['example'] as Map<String, dynamic>;
    return RefPrice(
      source: j['source'] as String,
      unit: j['unit'] as String,
      n: (j['n'] as num).toInt(),
      unitMin: (j['unitMin'] as num).toDouble(),
      unitMedian: (j['unitMedian'] as num).toDouble(),
      pkgMedian: (j['pkgMedian'] as num).toDouble(),
      exName: ex['name'] as String,
      exPrice: (ex['price'] as num).toDouble(),
      exUnitPrice: (ex['unitPrice'] as num).toDouble(),
      exUrl: ex['url'] as String? ?? '',
    );
  }
}

class PriceFeed {
  PriceFeed(this.lt, this.pl, this.generatedAt);
  final Map<String, RefPrice> lt, pl; // keyed by the Polish shelf name (Term.pl)
  final DateTime? generatedAt;

  static Map<String, RefPrice> _side(Object? o) =>
      ((o as Map?) ?? {}).map((k, v) => MapEntry('$k', RefPrice.fromJson(v as Map<String, dynamic>)));

  static PriceFeed parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return PriceFeed(_side(j['lt']), _side(j['pl']), DateTime.tryParse(j['generatedAt'] as String? ?? ''));
  }

  static Future<String> bundled() => rootBundle.loadString('assets/data/prices.json');

  static Future<String> fetch({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c.get(Uri.parse('$kFeedBase/prices.json')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final body = utf8.decode(r.bodyBytes);
      parse(body);
      return body;
    } finally {
      if (client == null) c.close();
    }
  }
}

/// A package size in the comparison units the collector uses: kg, l or units.
typedef Qty = ({double qty, String unit});

final _size = RegExp(r'(?:(\d+)\s*[x×]\s*)?(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|szt|vnt|pary|para)\b\.?', caseSensitive: false);

/// "250 ml" → 0.25 l, "4 x 85 g" → 0.34 kg, "48 szt." → 48 units. Null if no size is written.
Qty? parseQty(String? text) {
  if (text == null) return null;
  final m = _size.firstMatch(text.toLowerCase());
  if (m == null) return null;
  final times = int.tryParse(m.group(1) ?? '') ?? 1;
  final n = double.parse(m.group(2)!.replaceAll(',', '.')) * times;
  if (n <= 0) return null;
  return switch (m.group(3)!) {
    'kg' => (qty: n, unit: 'kg'),
    'g' => (qty: n / 1000, unit: 'kg'),
    'l' => (qty: n, unit: 'l'),
    'ml' => (qty: n / 1000, unit: 'l'),
    _ => (qty: n, unit: 'units'),
  };
}

/// How much a deal's package holds: from the per-unit price, the size field, or the name.
Qty? dealQty(Deal d) {
  final u = d.unit?.trim().toLowerCase();
  if (d.unitPrice != null && d.unitPrice! > 0 && u != null) {
    final base = switch (u) { 'kg' => 'kg', 'l' => 'l', 'szt.' || 'szt' => 'units', _ => null };
    if (base != null) return (qty: d.price / d.unitPrice!, unit: base);
  }
  // "1 szt." on a 400 ml shampoo says nothing about size: the name does.
  final fromUnit = parseQty(d.unit), fromName = parseQty(d.name);
  if (fromUnit == null || (fromUnit.unit == 'units' && fromUnit.qty == 1 && fromName != null)) return fromName ?? fromUnit;
  return fromUnit;
}
