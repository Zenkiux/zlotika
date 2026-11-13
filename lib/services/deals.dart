import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where the daily collector publishes its output. One JSON file, no keys.
/// The same host serves `config.json`, the remote off switch.
/// Published daily by github.com/Zenkiux/zlotika-data (GitHub Actions → Pages).
/// Override for testing with --dart-define=ZLOTIKA_FEED=…
const kFeedBase = String.fromEnvironment('ZLOTIKA_FEED', defaultValue: 'https://zenkiux.github.io/zlotika-data');

/// A promotion seen on a retailer's public website or leaflet.
class Deal {
  const Deal({
    required this.id,
    required this.chain,
    required this.name,
    required this.price,
    this.oldPrice,
    this.unit,
    this.unitPrice,
    this.card,
    this.multibuy,
    this.minQty,
    this.limit,
    this.validFrom,
    this.validTo,
    this.imageUrl,
    this.url,
    this.category,
    this.ocr = false,
    this.vision = false,
    this.everyday = false,
    this.crowd = false,
    this.barcode,
    this.leaflet,
    this.page,
  });

  final String id, chain, name; // name = original Polish text
  final double price; // zł
  final double? oldPrice, unitPrice;
  final String? unit; // "kg", "l", "szt."
  final bool? card; // requires the chain's loyalty card/app
  final String? multibuy; // e.g. "2+1", "drugi -50%"
  final int? minQty, limit;
  final String? validFrom, validTo; // yyyy-mm-dd
  final String? imageUrl, url, category;
  final bool ocr; // read automatically from a leaflet image — less certain
  final bool vision; // read by the image-reading model (more reliable than plain OCR)
  final bool everyday; // the chain's everyday (regular) price, not a short promotion
  final bool crowd; // photographed on a shelf tag or receipt by a shopper (Open Prices)
  final String? barcode;
  final String? leaflet; // id in the leaflet list
  final int? page;

  double? get discountPct => (oldPrice != null && oldPrice! > price) ? (1 - price / oldPrice!) : null;

  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
        id: j['id'] as String,
        chain: j['chain'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        oldPrice: (j['oldPrice'] as num?)?.toDouble(),
        unit: j['unit'] as String?,
        unitPrice: (j['unitPrice'] as num?)?.toDouble(),
        card: j['card'] as bool?,
        multibuy: j['multibuy'] as String?,
        minQty: (j['minQty'] as num?)?.toInt(),
        limit: (j['limit'] as num?)?.toInt(),
        validFrom: j['validFrom'] as String?,
        validTo: j['validTo'] as String?,
        imageUrl: j['imageUrl'] as String?,
        url: j['url'] as String?,
        category: j['category'] as String?,
        ocr: j['ocr'] as bool? ?? false,
        vision: j['vision'] as bool? ?? false,
        everyday: j['everyday'] as bool? ?? false,
        crowd: j['crowd'] as bool? ?? false,
        barcode: j['barcode'] as String?,
        leaflet: j['leaflet'] as String?,
        page: (j['page'] as num?)?.toInt(),
      );
}

/// A retailer leaflet shown in the in-app reader. Images load from the retailer's servers.
class LeafletPage {
  const LeafletPage({required this.n, required this.image, this.thumb, required this.link});
  final int n;
  final String image, link;
  final String? thumb;
}

class Leaflet {
  const Leaflet({required this.id, required this.chain, required this.title, this.validFrom, this.validTo, this.cover, required this.link, required this.pages});
  final String id, chain, title, link;
  final String? validFrom, validTo, cover;
  final List<LeafletPage> pages;

  factory Leaflet.fromJson(Map<String, dynamic> j) => Leaflet(
        id: j['id'] as String,
        chain: j['chain'] as String,
        title: j['title'] as String,
        validFrom: j['validFrom'] as String?,
        validTo: j['validTo'] as String?,
        cover: j['cover'] as String?,
        link: j['link'] as String,
        pages: ((j['pages'] as List?) ?? [])
            .map((p) => LeafletPage(n: (p['n'] as num).toInt(), image: p['image'] as String, thumb: p['thumb'] as String?, link: p['link'] as String))
            .toList(),
      );
}

class SourceStatus {
  const SourceStatus({required this.chain, required this.ok, required this.count, required this.fetchedAt});
  final String chain;
  final bool ok;
  final int count;
  final DateTime fetchedAt;

  factory SourceStatus.fromJson(Map<String, dynamic> j) => SourceStatus(
        chain: j['chain'] as String,
        ok: j['ok'] as bool? ?? false,
        count: (j['count'] as num?)?.toInt() ?? 0,
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
      );
}

class DealFeed {
  const DealFeed({required this.generatedAt, required this.deals, required this.sources});
  final DateTime generatedAt;
  final List<Deal> deals;
  final List<SourceStatus> sources;

  factory DealFeed.fromJson(Map<String, dynamic> j) => DealFeed(
        generatedAt: DateTime.parse(j['generatedAt'] as String),
        deals: ((j['deals'] as List?) ?? []).map((e) => Deal.fromJson(e as Map<String, dynamic>)).toList(),
        sources: ((j['sources'] as List?) ?? []).map((e) => SourceStatus.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Remote switches: turn collected data off globally or per chain without an app update.
class FeedConfig {
  const FeedConfig({this.collectedEnabled = true, this.leafletsEnabled = true, this.disabledChains = const {}, this.disabledPriceSources = const {}});
  final bool collectedEnabled;
  /// Reference-price sources switched off remotely, lower-case ('barbora', 'rossmann', 'frisco').
  final Set<String> disabledPriceSources;
  final bool leafletsEnabled;
  final Set<String> disabledChains;

  factory FeedConfig.fromJson(Map<String, dynamic> j) => FeedConfig(
        collectedEnabled: j['collectedEnabled'] as bool? ?? true,
        leafletsEnabled: j['leafletsEnabled'] as bool? ?? true,
        disabledChains: ((j['disabledChains'] as List?) ?? []).map((e) => '$e').toSet(),
        disabledPriceSources: {
          for (final e in ((j['priceSources'] as Map?) ?? {}).entries)
            if (e.value == false) '${e.key}'.toLowerCase(),
          ...((j['disabledPriceSources'] as List?) ?? []).map((e) => '$e'),
        },
      );
}

class DealService {
  static Future<String> fetchLeaflets({http.Client? client}) async {
    if (kFeedBase.isEmpty) return '';
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse('$kFeedBase/leaflets.json')).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('leaflets ${res.statusCode}');
      return utf8.decode(res.bodyBytes);
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<(FeedConfig, String)> fetch({http.Client? client}) async {
    if (kFeedBase.isEmpty) return (const FeedConfig(), '');
    final c = client ?? http.Client();
    try {
      var config = const FeedConfig();
      try {
        final r = await c.get(Uri.parse('$kFeedBase/config.json')).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) config = FeedConfig.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
      } catch (_) {/* no config = defaults */}
      if (!config.collectedEnabled) return (config, '');
      final res = await c.get(Uri.parse('$kFeedBase/deals.json')).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('feed ${res.statusCode}');
      final body = utf8.decode(res.bodyBytes);
      DealFeed.fromJson(jsonDecode(body) as Map<String, dynamic>); // validate before caching
      return (config, body);
    } finally {
      if (client == null) c.close();
    }
  }
}
