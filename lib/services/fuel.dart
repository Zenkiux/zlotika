import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deals.dart' show kFeedBase;

/// A published average pump price (not a single station). Per litre.
class FuelPrice {
  const FuelPrice({this.pb95, this.diesel, this.lpg, required this.currency, required this.date, required this.source, required this.url, this.region});
  final double? pb95, diesel, lpg;
  final String currency; // 'EUR' or 'PLN'
  final String date; // yyyy-mm-dd the average refers to
  final String source, url;
  final String? region;

  static FuelPrice? fromJson(Object? o) {
    if (o is! Map<String, dynamic>) return null;
    double? n(String k) => (o[k] as num?)?.toDouble();
    return FuelPrice(
      pb95: n('pb95'),
      diesel: n('diesel'),
      lpg: n('lpg'),
      currency: o['currency'] as String? ?? 'EUR',
      date: o['date'] as String? ?? '',
      source: o['source'] as String? ?? '',
      url: o['url'] as String? ?? '',
      region: o['region'] as String?,
    );
  }
}

/// fuel.json from the daily collector: EU Weekly Oil Bulletin (LT + PL, €),
/// e-petrol.pl (PL, zł; Podlaskie when fresh) and Poland's legal maximum price.
class FuelFeed {
  const FuelFeed({this.lt, this.pl, this.plRegion, this.plEu, this.plCap});
  final FuelPrice? lt, pl, plRegion, plEu;

  /// Legal maximum pump price in Poland (zł/l, gross), set daily by the Minister of Energy.
  /// No station may charge more. Covers Pb95 and diesel, not LPG.
  final FuelPrice? plCap;

  factory FuelFeed.fromJson(Map<String, dynamic> j) => FuelFeed(
        lt: FuelPrice.fromJson(j['lt']),
        pl: FuelPrice.fromJson(j['pl']),
        plRegion: FuelPrice.fromJson(j['plRegion']),
        plEu: FuelPrice.fromJson(j['plEu']),
        plCap: FuelPrice.fromJson(j['plCap'] is Map ? {...(j['plCap'] as Map<String, dynamic>), 'currency': 'PLN'} : null),
      );

  static Future<String> fetch({http.Client? client}) async {
    if (kFeedBase.isEmpty) return '';
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse('$kFeedBase/fuel.json')).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('fuel ${res.statusCode}');
      final body = utf8.decode(res.bodyBytes);
      FuelFeed.fromJson(jsonDecode(body) as Map<String, dynamic>); // validate before caching
      return body;
    } finally {
      if (client == null) c.close();
    }
  }
}
