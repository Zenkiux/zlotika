import 'dart:convert';

import 'package:http/http.dart' as http;

/// Official EUR/PLN mid rate from the National Bank of Poland (Table A).
/// https://api.nbp.pl — free, no key; published on working days around midday.
class NbpRate {
  const NbpRate({required this.mid, required this.date, required this.fetchedAt});

  final double mid; // PLN for 1 EUR
  final String date; // effective date, yyyy-mm-dd
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {'mid': mid, 'date': date, 'fetchedAt': fetchedAt.toIso8601String()};

  factory NbpRate.fromJson(Map<String, dynamic> j) =>
      NbpRate(mid: (j['mid'] as num).toDouble(), date: j['date'] as String, fetchedAt: DateTime.parse(j['fetchedAt'] as String));
}

class NbpService {
  static final _uri = Uri.parse('https://api.nbp.pl/api/exchangerates/rates/a/eur/?format=json');

  static Future<NbpRate> fetchEur({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c.get(_uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('NBP ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final r = (j['rates'] as List).first as Map<String, dynamic>;
      return NbpRate(mid: (r['mid'] as num).toDouble(), date: r['effectiveDate'] as String, fetchedAt: DateTime.now());
    } finally {
      if (client == null) c.close();
    }
  }
}
