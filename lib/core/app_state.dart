import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/geo.dart';
import '../services/deals.dart';
import '../services/nbp.dart';
import 'i18n.dart';

enum FuelType { diesel, petrol, lpg }

/// One line of the shopping list. Prices are what the user saw; nothing is invented.
class ListItem {
  ListItem({required this.id, required this.name, this.plName, this.qty = 1, this.plPrice, this.ltPrice, this.barcode, this.checked = false, this.chain, this.dealId});

  final String id;
  String name; // in the user's language
  String? plName; // original Polish name, for finding it on the shelf
  int qty;
  double? plPrice; // zł per unit
  double? ltPrice; // € per unit
  String? barcode;
  bool checked;
  String? chain; // where to buy it, when added from a deal
  String? dealId;

  bool get hasPrices => plPrice != null && ltPrice != null;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'plName': plName, 'qty': qty, 'plPrice': plPrice, 'ltPrice': ltPrice, 'barcode': barcode, 'checked': checked, 'chain': chain, 'dealId': dealId};

  factory ListItem.fromJson(Map<String, dynamic> j) => ListItem(
        id: j['id'] as String,
        name: j['name'] as String,
        plName: j['plName'] as String?,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        plPrice: (j['plPrice'] as num?)?.toDouble(),
        ltPrice: (j['ltPrice'] as num?)?.toDouble(),
        barcode: j['barcode'] as String?,
        checked: j['checked'] as bool? ?? false,
        chain: j['chain'] as String?,
        dealId: j['dealId'] as String?,
      );
}

class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _key = 'zlotika.v1';

  // Preferences
  Lang lang = Lang.lt;
  double textScale = 1.0; // 1.0 / 1.15 / 1.3
  ThemeMode themeMode = ThemeMode.dark;
  bool onboarded = false;

  // Trip
  String originId = 'kaunas';
  String destId = 'suwalki';
  FuelType fuel = FuelType.diesel;
  double consumption = 6.2;
  int refuelLitres = 40;
  int travellers = 1;
  double? ltFuelPrice; // € / l, entered by the user
  double? plFuelPrice; // zł / l, entered by the user
  double cardFeePct = 0;

  // List
  final List<ListItem> items = [];

  // Deals feed (collected daily on a server; cached on the phone)
  DealFeed? feed;
  FeedConfig feedConfig = const FeedConfig();
  bool feedLoading = false;
  bool feedFailed = false;
  /// User corrections: deal id → price the shopper actually saw (zł).
  final Map<String, double> priceFixes = {};

  List<Leaflet> _leaflets = const [];

  /// Leaflets for the in-app reader, after the remote off switches.
  List<Leaflet> get leaflets {
    if (!feedConfig.leafletsEnabled) return const [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _leaflets
        .where((l) => !feedConfig.disabledChains.contains(l.chain) && (l.validTo == null || l.validTo!.compareTo(today) >= 0))
        .toList();
  }

  Leaflet? leafletById(String? id) {
    for (final l in _leaflets) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Deals visible to the user after the remote off switches.
  List<Deal> get deals {
    final f = feed;
    if (f == null || !feedConfig.collectedEnabled) return const [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return f.deals
        .where((d) => !feedConfig.disabledChains.contains(d.chain) && (d.validTo == null || d.validTo!.compareTo(today) >= 0))
        .toList();
  }

  double dealPrice(Deal d) => priceFixes[d.id] ?? d.price;

  // Exchange rate (live from NBP, cached)
  NbpRate? rate;
  bool rateLoading = false;
  bool rateFailed = false;

  Origin get origin => originById(originId);
  Destination get dest => destById(destId);

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      lang = Lang.values.byName(j['lang'] as String? ?? 'lt');
      textScale = (j['textScale'] as num?)?.toDouble() ?? 1.0;
      themeMode = ThemeMode.values.byName(j['theme'] as String? ?? 'dark');
      onboarded = j['onboarded'] as bool? ?? false;
      originId = j['originId'] as String? ?? originId;
      destId = j['destId'] as String? ?? destId;
      fuel = FuelType.values.byName(j['fuel'] as String? ?? 'diesel');
      consumption = (j['consumption'] as num?)?.toDouble() ?? consumption;
      refuelLitres = (j['refuelLitres'] as num?)?.toInt() ?? refuelLitres;
      travellers = (j['travellers'] as num?)?.toInt() ?? travellers;
      ltFuelPrice = (j['ltFuelPrice'] as num?)?.toDouble();
      plFuelPrice = (j['plFuelPrice'] as num?)?.toDouble();
      cardFeePct = (j['cardFeePct'] as num?)?.toDouble() ?? 0;
      items
        ..clear()
        ..addAll(((j['items'] as List?) ?? []).map((e) => ListItem.fromJson(e as Map<String, dynamic>)));
      ((j['priceFixes'] as Map?) ?? {}).forEach((k, v) => priceFixes['$k'] = (v as num).toDouble());
      final r = j['rate'];
      if (r is Map<String, dynamic>) rate = NbpRate.fromJson(r);
    } catch (_) {
      // Corrupt storage must never block the app; start clean.
    }
    try {
      final f = _prefs.getString('$_key.feed');
      if (f != null) feed = DealFeed.fromJson(jsonDecode(f) as Map<String, dynamic>);
      final lf = _prefs.getString('$_key.leaflets');
      if (lf != null) _leaflets = _parseLeaflets(lf);
      final c = _prefs.getString('$_key.feedConfig');
      if (c != null) feedConfig = FeedConfig.fromJson(jsonDecode(c) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _save() => _prefs.setString(
        _key,
        jsonEncode({
          'lang': lang.name, 'textScale': textScale, 'theme': themeMode.name, 'onboarded': onboarded,
          'originId': originId, 'destId': destId, 'fuel': fuel.name, 'consumption': consumption,
          'refuelLitres': refuelLitres, 'travellers': travellers, 'ltFuelPrice': ltFuelPrice, 'plFuelPrice': plFuelPrice,
          'cardFeePct': cardFeePct, 'items': items.map((e) => e.toJson()).toList(), 'rate': rate?.toJson(), 'priceFixes': priceFixes,
        }),
      );

  void update(void Function(AppState s) fn) {
    fn(this);
    notifyListeners();
    _save();
  }

  // ── List operations
  void addItem(ListItem item) => update((s) => s.items.insert(0, item));
  void removeItem(String id) => update((s) => s.items.removeWhere((e) => e.id == id));
  void restoreItem(ListItem item, int index) => update((s) => s.items.insert(index.clamp(0, s.items.length), item));
  void changeItem(String id, void Function(ListItem i) fn) => update((s) => fn(s.items.firstWhere((e) => e.id == id)));
  void clearChecked() => update((s) => s.items.removeWhere((e) => e.checked));

  Future<void> resetAll() async {
    await _prefs.remove(_key);
    items.clear();
    lang = Lang.lt;
    textScale = 1.0;
    themeMode = ThemeMode.dark;
    onboarded = false;
    originId = 'kaunas';
    destId = 'suwalki';
    fuel = FuelType.diesel;
    consumption = 6.2;
    refuelLitres = 40;
    travellers = 1;
    ltFuelPrice = null;
    plFuelPrice = null;
    cardFeePct = 0;
    priceFixes.clear();
    await _prefs.remove('$_key.feed');
    feed = null;
    notifyListeners();
  }

  // ── Money
  /// PLN → EUR including the user's card fee. Null when no rate is known yet.
  double? toEur(double pln) => rate == null ? null : pln / rate!.mid * (1 + cardFeePct / 100);

  /// Savings for one list line (positive = Poland cheaper). Null if prices or rate missing.
  double? itemSaving(ListItem i) {
    if (!i.hasPrices) return null;
    final pl = toEur(i.plPrice!);
    if (pl == null) return null;
    return (i.ltPrice! - pl) * i.qty;
  }

  ({double plEur, double ltEur, double saving, int priced, int missing}) basket() {
    var pl = 0.0, lt = 0.0, saving = 0.0;
    var priced = 0;
    for (final i in items) {
      final s = itemSaving(i);
      if (s == null) continue;
      priced++;
      // Only items that are cheaper in Poland are worth buying there.
      if (s > 0) {
        pl += toEur(i.plPrice!)! * i.qty;
        lt += i.ltPrice! * i.qty;
        saving += s;
      }
    }
    return (plEur: pl, ltEur: lt, saving: saving, priced: priced, missing: items.length - priced);
  }

  Future<void> refreshFeed() async {
    if (feedLoading) return;
    feedLoading = true;
    feedFailed = false;
    notifyListeners();
    try {
      final (config, body) = await DealService.fetch();
      feedConfig = config;
      await _prefs.setString('$_key.feedConfig',
          jsonEncode({'collectedEnabled': config.collectedEnabled, 'leafletsEnabled': config.leafletsEnabled, 'disabledChains': config.disabledChains.toList()}));
      if (config.leafletsEnabled) {
        try {
          final lb = await DealService.fetchLeaflets();
          if (lb.isNotEmpty) {
            _leaflets = _parseLeaflets(lb);
            await _prefs.setString('$_key.leaflets', lb);
          }
        } catch (_) {/* keep cached leaflets */}
      }
      if (body.isNotEmpty) {
        feed = DealFeed.fromJson(jsonDecode(body) as Map<String, dynamic>);
        await _prefs.setString('$_key.feed', body);
      }
    } catch (_) {
      feedFailed = true;
    } finally {
      feedLoading = false;
      notifyListeners();
    }
  }

  static List<Leaflet> _parseLeaflets(String body) =>
      (((jsonDecode(body) as Map<String, dynamic>)['leaflets'] as List?) ?? []).map((e) => Leaflet.fromJson(e as Map<String, dynamic>)).toList();

  void setPriceFix(String dealId, double? price) => update((s) => price == null ? s.priceFixes.remove(dealId) : s.priceFixes[dealId] = price);

  Future<void> refreshRate() async {
    if (rateLoading) return;
    rateLoading = true;
    rateFailed = false;
    notifyListeners();
    try {
      final r = await NbpService.fetchEur();
      rate = r;
      _save();
    } catch (_) {
      rateFailed = true;
    } finally {
      rateLoading = false;
      notifyListeners();
    }
  }
}

/// Provides [AppState] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
