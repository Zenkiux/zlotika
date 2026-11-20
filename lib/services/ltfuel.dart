import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deals.dart' show kFeedBase;
import 'stores.dart';

/// One Lithuanian station with today's pump prices reported to the energy agency (LEA).
class LtStation {
  const LtStation({required this.store, this.pb95, this.diesel, this.lpg, required this.at});
  final Store store; // shown on the map like any other fuel station
  final double? pb95, diesel, lpg; // €/l
  final String at; // "2026-11-20 10:00:00"

  static LtStation? fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble(), lon = (j['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    final address = j['address'] as String?;
    return LtStation(
      store: Store(id: j['id'] as String, chain: 'fuel', brand: (j['brand'] as String?) ?? 'Degalinė', town: 'route', lat: lat, lon: lon, address: address, country: 'LT'),
      pb95: (j['pb95'] as num?)?.toDouble(),
      diesel: (j['diesel'] as num?)?.toDouble(),
      lpg: (j['lpg'] as num?)?.toDouble(),
      at: j['at'] as String? ?? '',
    );
  }
}

class LtFuelFeed {
  LtFuelFeed(this.stations, this.updated) : _byId = {for (final s in stations) s.store.id: s};
  final List<LtStation> stations;
  final String updated;
  final Map<String, LtStation> _byId;

  LtStation? byId(String id) => _byId[id];

  static LtFuelFeed parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final list = ((j['stations'] as List?) ?? []).map((e) => LtStation.fromJson(e as Map<String, dynamic>)).whereType<LtStation>().toList();
    return LtFuelFeed(list, j['updated'] as String? ?? '');
  }

  static Future<String> fetch({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c.get(Uri.parse('$kFeedBase/ltfuel.json')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final body = utf8.decode(r.bodyBytes);
      parse(body);
      return body;
    } finally {
      if (client == null) c.close();
    }
  }
}

/// A Polish pump price drivers reported on AutoCentrum.pl, kept only if under a week old.
class PlReport {
  const PlReport(this.price, this.days);
  final double price; // zł/l
  final int days; // 0 = today
}

class PlStationPrices {
  const PlStationPrices({required this.lat, required this.lon, this.pb95, this.diesel, this.lpg});
  final double lat, lon;
  final PlReport? pb95, diesel, lpg;
}

class PlFuelFeed {
  PlFuelFeed(this.stations, this.generatedAt);
  final List<PlStationPrices> stations;
  final DateTime? generatedAt;

  /// Reports for the station at this spot (OpenStreetMap and AutoCentrum positions differ a little).
  PlStationPrices? near(double lat, double lon) {
    PlStationPrices? best;
    var bestKm = .15;
    for (final s in stations) {
      final d = kmBetween(lat, lon, s.lat, s.lon);
      if (d < bestKm) {
        best = s;
        bestKm = d;
      }
    }
    return best;
  }

  static PlFuelFeed parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    PlReport? r(Object? o) {
      if (o is! Map<String, dynamic>) return null;
      final p = (o['price'] as num?)?.toDouble();
      return p == null ? null : PlReport(p, (o['days'] as num?)?.toInt() ?? 0);
    }

    final list = <PlStationPrices>[];
    for (final e in (j['stations'] as List? ?? [])) {
      final m = e as Map<String, dynamic>;
      final s = PlStationPrices(lat: (m['lat'] as num).toDouble(), lon: (m['lon'] as num).toDouble(), pb95: r(m['pb95']), diesel: r(m['diesel']), lpg: r(m['lpg']));
      if (s.pb95 != null || s.diesel != null || s.lpg != null) list.add(s);
    }
    return PlFuelFeed(list, DateTime.tryParse(j['generatedAt'] as String? ?? ''));
  }

  static Future<String> fetch() async {
    final r = await http.get(Uri.parse('$kFeedBase/plfuel.json')).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final body = utf8.decode(r.bodyBytes);
    parse(body);
    return body;
  }
}
