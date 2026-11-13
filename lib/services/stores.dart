import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../core/hours.dart';
import 'deals.dart' show kFeedBase;

/// A shop or fuel station from OpenStreetMap (© OpenStreetMap contributors, ODbL).
class Store {
  const Store({required this.id, required this.chain, required this.brand, this.name, required this.town, required this.lat, required this.lon, this.address, this.hours});

  final String id, chain, brand, town; // chain = app chain id, or 'fuel'
  final String? name, address, hours; // hours = raw OSM opening_hours
  final double lat, lon;

  bool get isFuel => chain == 'fuel';

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'] as String,
        chain: j['chain'] as String,
        brand: j['brand'] as String,
        name: j['name'] as String?,
        town: j['town'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        address: j['address'] as String?,
        hours: j['hours'] as String?,
      );
}

/// Straight-line distance in km.
double kmBetween(double lat1, double lon1, double lat2, double lon2) {
  const k = math.pi / 180;
  final x = (lon2 - lon1) * k * math.cos((lat1 + lat2) / 2 * k);
  final y = (lat2 - lat1) * k;
  return math.sqrt(x * x + y * y) * 6371;
}

class StoreFeed {
  StoreFeed(this.stores, this.generatedAt) {
    // Typical hours per chain and town: the most common value among shops that list one.
    final counts = <String, Map<String, int>>{};
    for (final s in stores) {
      if (s.hours == null || OpeningHours.parse(s.hours) == null) continue;
      for (final key in ['${s.town}/${s.chain}', s.chain]) {
        final m = counts.putIfAbsent(key, () => {});
        m[s.hours!] = (m[s.hours!] ?? 0) + 1;
      }
    }
    counts.forEach((k, m) => _typical[k] = (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key);
  }

  final List<Store> stores;
  final DateTime? generatedAt;
  final Map<String, String> _typical = {};
  final Map<String, OpeningHours?> _parsed = {};

  OpeningHours? _parse(String? raw) => raw == null ? null : _parsed.putIfAbsent(raw, () => OpeningHours.parse(raw));

  /// The shop's own hours, or the chain's usual hours in that town (flagged as a guess).
  ({OpeningHours? hours, bool guessed}) hoursOf(Store s) {
    final own = _parse(s.hours);
    if (own != null) return (hours: own, guessed: false);
    if (s.isFuel) return (hours: null, guessed: false);
    final t = _typical['${s.town}/${s.chain}'] ?? _typical[s.chain];
    return (hours: _parse(t), guessed: t != null);
  }

  /// Shops of a chain in a town: ones with known hours and an address first.
  List<Store> inTown(String town, String chain) {
    final l = stores.where((s) => s.town == town && s.chain == chain).toList();
    int score(Store s) => (s.hours != null ? 2 : 0) + (s.address != null ? 1 : 0);
    l.sort((a, b) => score(b).compareTo(score(a)));
    return l;
  }

  Set<String> chainsIn(String town) => {for (final s in stores) if (s.town == town && !s.isFuel) s.chain};

  Store? byId(String? id) {
    for (final s in stores) {
      if (s.id == id) return s;
    }
    return null;
  }

  static StoreFeed parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return StoreFeed(
      ((j['stores'] as List?) ?? []).map((e) => Store.fromJson(e as Map<String, dynamic>)).toList(),
      DateTime.tryParse(j['generatedAt'] as String? ?? ''),
    );
  }

  /// Snapshot shipped with the app, so the plan works offline on first launch.
  static Future<String> bundled() => rootBundle.loadString('assets/data/stores.json');

  static Future<String> fetch({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c.get(Uri.parse('$kFeedBase/stores.json')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      StoreFeed.parse(r.body); // validate before caching
      return r.body;
    } finally {
      if (client == null) c.close();
    }
  }
}
