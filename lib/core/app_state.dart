import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/calendar.dart' show isoDay, shopsOpen;
import '../data/chains.dart' show chainById;
import '../data/geo.dart';
import 'hours.dart' show plNow;
import '../services/deals.dart';
import '../services/fuel.dart';
import '../services/match.dart';
import '../data/dictionary.dart' show terms;
import '../services/nbp.dart';
import '../services/stores.dart';
import '../services/prices.dart';
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

/// Something the shopper wants to hear about when it goes on promotion.
class WatchItem {
  WatchItem({required this.id, required this.name, required this.pl, this.term = false});
  final String id;
  final String name; // as the shopper wrote it / translated
  final String pl; // Polish shelf word or brand text to look for
  final bool term; // from the dictionary: precise matching; otherwise free text

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'pl': pl, 'term': term};
  factory WatchItem.fromJson(Map<String, dynamic> j) =>
      WatchItem(id: j['id'] as String, name: j['name'] as String, pl: j['pl'] as String, term: j['term'] as bool? ?? false);
}

/// A finished shopping trip, for the savings history.
class TripRecord {
  TripRecord({required this.date, required this.dest, required this.pln, required this.eur, required this.items, this.saving, this.travel = 0});
  final String date; // yyyy-mm-dd
  final String dest;
  final double pln, eur; // what was spent in Poland
  final int items;
  final double? saving; // shopping saving vs Lithuanian prices, for items where the LT price was known
  final double travel; // fuel for the drive minus the cheaper refuel (€, may be negative)

  double? get net => saving == null ? null : saving! - travel;

  Map<String, dynamic> toJson() => {'date': date, 'dest': dest, 'pln': pln, 'eur': eur, 'items': items, 'saving': saving, 'travel': travel};
  factory TripRecord.fromJson(Map<String, dynamic> j) => TripRecord(
        date: j['date'] as String,
        dest: j['dest'] as String,
        pln: (j['pln'] as num).toDouble(),
        eur: (j['eur'] as num).toDouble(),
        items: (j['items'] as num).toInt(),
        saving: (j['saving'] as num?)?.toDouble(),
        travel: (j['travel'] as num?)?.toDouble() ?? 0,
      );
}

/// Where a price on the list came from — shown so estimates never look like facts.
enum PriceKind { typed, deal, last, ref }

typedef Est = ({double price, PriceKind kind, RefPrice? ref});

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
  double? ltFuelPrice; // € / l, typed by the user — overrides the published average
  double? plFuelPrice; // zł / l, typed by the user — overrides the published average
  FuelFeed? fuelFeed; // published weekly averages (EU Oil Bulletin, e-petrol.pl)

  double? _pick(FuelPrice? p) => p == null ? null : switch (fuel) { FuelType.diesel => p.diesel, FuelType.petrol => p.pb95, FuelType.lpg => p.lpg };

  /// Published Lithuanian average for the chosen fuel, € / l.
  FuelPrice? get autoLtSource => _pick(fuelFeed?.lt) != null ? fuelFeed!.lt : null;
  double? get autoLtFuel => _pick(fuelFeed?.lt);

  /// Published Polish average for the chosen fuel, zł / l: Podlaskie if fresh, else national
  /// (e-petrol), else the EU bulletin converted at the NBP rate.
  FuelPrice? get autoPlSource {
    for (final p in [fuelFeed?.plRegion, fuelFeed?.pl]) {
      if (_pick(p) != null) return p;
    }
    return (_pick(fuelFeed?.plEu) != null && rate != null) ? fuelFeed!.plEu : null;
  }

  /// Poland's legal maximum for the chosen fuel today (zł/l), if one applies (not for LPG).
  double? get plCap => _pick(fuelFeed?.plCap);

  /// Published Polish average, never above the legal maximum (stations can't charge more).
  double? get autoPlFuel {
    final p = autoPlSource;
    final v = _pick(p);
    final avg = p == null || v == null ? null : (p.currency == 'PLN' ? v : v * rate!.mid);
    final cap = plCap;
    if (avg == null) return cap;
    return cap != null && cap < avg ? cap : avg;
  }

  /// True when the price shown for Poland is the legal maximum rather than an average.
  bool get plFuelIsCap => plFuelPrice == null && plCap != null && autoPlFuel == plCap;

  /// What the calculator uses: the user's own price if typed, else the published average.
  double? get ltFuel => ltFuelPrice ?? autoLtFuel;
  double? get plFuel => plFuelPrice ?? autoPlFuel;
  double cardFeePct = 0;

  // ── The trip: which shops, which loyalty cards, which day. Every price and
  // saving in the app comes only from these shops.
  bool tripReady = false; // the setup questions were answered
  final List<String> tripChains = []; // chains the shopper will visit, main shop first
  final Set<String> cards = {}; // chains whose loyalty card / app the shopper has
  String? tripDate; // yyyy-mm-dd, Polish calendar

  /// Where the shopper buys at home, so savings compare with *their* shop:
  /// 'maxima' (Barbora prices), 'rimi', or 'cheapest' of the two.
  String ltShop = 'maxima';
  static const ltShops = ['maxima', 'rimi', 'cheapest'];

  bool inTrip(String? chain) => chain != null && tripChains.contains(chain);

  /// The trip day; a past or unset date becomes the next day shops are open.
  DateTime get tripDay {
    final p = plNow();
    final today = DateTime(p.year, p.month, p.day);
    final d = tripDate == null ? null : DateTime.tryParse(tripDate!);
    if (d != null && !d.isBefore(today)) return d;
    var x = p.hour >= 18 ? today.add(const Duration(days: 1)) : today;
    for (var i = 0; i < 7 && !shopsOpen(x); i++) {
      x = x.add(const Duration(days: 1));
    }
    return x;
  }

  /// Chains with a shop in the destination town (all known chains if shops aren't loaded).
  Set<String> get chainsInTown => storeFeed?.chainsIn(destId) ?? {};

  void setDest(String id) => update((s) {
        s.destId = id;
        final here = s.chainsInTown;
        if (here.isNotEmpty) s.tripChains.retainWhere(here.contains);
      });

  void toggleTripChain(String chain) => update((s) => s.tripChains.contains(chain) ? s.tripChains.remove(chain) : s.tripChains.add(chain));
  void addTripChain(String chain) => update((s) {
        if (!s.tripChains.contains(chain)) s.tripChains.add(chain);
      });
  void toggleCard(String chain) => update((s) => s.cards.contains(chain) ? s.cards.remove(chain) : s.cards.add(chain));

  /// A deal counts for this trip: one of the trip's shops, valid that day, and the
  /// shopper has the card if the price needs one.
  bool dealUsable(Deal d) {
    if (!tripChains.contains(d.chain)) return false;
    if (d.card == true && !cards.contains(d.chain)) return false;
    final day = isoDay(tripDay);
    if (d.validFrom != null && d.validFrom!.compareTo(day) > 0) return false;
    if (d.validTo != null && d.validTo!.compareTo(day) < 0) return false;
    return true;
  }

  // List
  final List<ListItem> items = [];

  /// What the shopper paid before, by item name: shown as "last time" when no deal is known.
  final Map<String, ({double pl, String? chain, String date})> priceMemory = {};

  static String _memKey(String name) => name.trim().toLowerCase();
  ({double pl, String? chain, String date})? lastPrice(ListItem i) => priceMemory[_memKey(i.name)];

  void _remember(ListItem i) {
    if (i.plPrice == null) return;
    priceMemory[_memKey(i.name)] = (pl: i.plPrice!, chain: chainOf(i), date: DateTime.now().toIso8601String().substring(0, 10));
  }

  // Watchlist and alerts
  final List<WatchItem> watch = [];
  final Set<String> alerted = {}; // deal ids the shopper was already told about
  bool alertsOn = false;

  List<Deal> watchDeals(WatchItem w) => w.term ? dealsAnywhere(w.pl) : matchLoose(w.pl, deals);
  bool isWatched(String pl) => watch.any((w) => w.pl.toLowerCase() == pl.toLowerCase());

  void addWatch(WatchItem w) => update((s) {
        s.watch.insert(0, w);
        // Deals already on screen are not news; alert only for ones that appear later.
        s.alerted.addAll(s.watchDeals(w).map((d) => d.id));
      });
  void removeWatch(String id) => update((s) => s.watch.removeWhere((w) => w.id == id));

  /// Watchlist deals not alerted yet; marks them as alerted.
  List<(WatchItem, Deal)> takeNewWatchHits() {
    final out = <(WatchItem, Deal)>[];
    for (final w in watch) {
      for (final d in watchDeals(w)) {
        if (alerted.add(d.id)) out.add((w, d));
      }
    }
    // Forget ids of deals that are gone, so the set stays small.
    final live = deals.map((d) => d.id).toSet();
    alerted.retainWhere(live.contains);
    if (out.isNotEmpty || alerted.isNotEmpty) _save();
    return out;
  }

  // Savings history
  final List<TripRecord> trips = [];

  ({double saved, double spent, int count}) yearTotals(int year) {
    var saved = 0.0, spent = 0.0;
    var n = 0;
    for (final t in trips.where((t) => t.date.startsWith('$year'))) {
      n++;
      spent += t.eur;
      saved += t.net ?? 0;
    }
    return (saved: saved, spent: spent, count: n);
  }

  void addTrip(TripRecord t) => update((s) {
        s.trips.insert(0, t);
        s.items.removeWhere((e) => e.checked);
      });
  void removeTrip(TripRecord t) => update((s) => s.trips.remove(t));

  // Reference prices (typical shelf prices in LT and PL)
  PriceFeed? priceFeed;

  RefPrice? _ref(Map<String, RefPrice>? side, String? pl) {
    final r = pl == null ? null : side?[pl];
    return (r == null || feedConfig.disabledPriceSources.contains(r.source.toLowerCase())) ? null : r;
  }

  /// The chain a reference price was read from, when it is a chain with shops ('Rossmann').
  static String? refChain(RefPrice r) => chainById(r.source.toLowerCase())?.id;

  RefPrice? ltRef(ListItem i) {
    final maxima = _ref(priceFeed?.lt, i.plName), rimi = _ref(priceFeed?.ltRimi, i.plName);
    return switch (ltShop) {
      'rimi' => rimi ?? maxima,
      'cheapest' => (maxima == null || (rimi != null && rimi.unitMedian < maxima.unitMedian)) ? rimi : maxima,
      _ => maxima ?? rimi,
    };
  }

  /// Usual Polish price — only from a shop on this trip (an online-only source counts anywhere).
  RefPrice? plRef(ListItem i) {
    final r = _ref(priceFeed?.pl, i.plName);
    if (r == null) return null;
    final ch = refChain(r);
    return ch == null || inTrip(ch) ? r : null;
  }

  Deal? dealById(String? id) {
    if (id == null) return null;
    for (final d in feed?.deals ?? const <Deal>[]) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// This trip's deals for a list line: at the shop the shopper chose for it, else at any trip shop.
  List<Deal> itemDeals(ListItem i) {
    final all = dealsFor(i.plName);
    return inTrip(i.chain) ? all.where((d) => d.chain == i.chain).toList() : all;
  }

  /// The deal a line is priced from: the one the shopper picked, else the best this trip has.
  Deal? dealOf(ListItem i) {
    if (i.plPrice != null) return null; // a typed price wins
    final pinned = dealById(i.dealId);
    if (pinned != null && dealUsable(pinned) && (!inTrip(i.chain) || pinned.chain == i.chain)) return pinned;
    final l = itemDeals(i);
    return l.isEmpty ? null : l.first;
  }

  /// Polish price per package, only from this trip's shops: typed, else a deal,
  /// else last time's price there, else the usual shelf price.
  Est? plFor(ListItem i) {
    if (i.plPrice != null) return (price: i.plPrice!, kind: PriceKind.typed, ref: null);
    final d = dealOf(i);
    if (d != null) return (price: dealPrice(d), kind: PriceKind.deal, ref: null);
    final last = lastPrice(i);
    if (last != null && (last.chain == null || inTrip(last.chain))) return (price: last.pl, kind: PriceKind.last, ref: null);
    final r = plRef(i);
    if (r != null && r.exQty > 0) return (price: r.exPrice, kind: PriceKind.ref, ref: r);
    return null;
  }

  /// Which of the trip's shops a line will be bought at.
  String? chainOf(ListItem i) {
    if (inTrip(i.chain)) return i.chain;
    final d = dealOf(i);
    if (d != null) return d.chain;
    final p = plFor(i);
    if (p?.kind == PriceKind.ref) {
      final ch = refChain(p!.ref!);
      if (ch != null) return ch;
    }
    if (p?.kind == PriceKind.last && inTrip(lastPrice(i)?.chain)) return lastPrice(i)!.chain;
    return tripChains.isEmpty ? null : tripChains.first;
  }

  /// Deals at shops that are NOT on the trip and are cheaper than what the trip offers.
  List<Deal> cheaperElsewhere(ListItem i) {
    final here = plFor(i)?.price;
    final out = dealsAnywhere(i.plName).where((d) => !tripChains.contains(d.chain) && d.card != true && (here == null || dealPrice(d) < here - 0.009)).toList();
    final seen = <String>{};
    return [for (final d in out) if (seen.add(d.chain)) d].take(2).toList();
  }

  /// The package size the Polish price is for, when known.
  Qty? basis(ListItem i) {
    final d = dealOf(i);
    if (d != null) return dealQty(d);
    final p = plFor(i);
    if (p?.kind == PriceKind.ref) return (qty: p!.ref!.exQty, unit: p.ref!.unit);
    return null;
  }

  /// Lithuanian price for the same amount: typed by the shopper, else the typical LT price
  /// per kg / l / piece × the Polish package size. Null when sizes can't be compared.
  Est? ltFor(ListItem i) {
    if (i.ltPrice != null) return (price: i.ltPrice!, kind: PriceKind.typed, ref: null);
    final r = ltRef(i), b = basis(i);
    final v = r == null || b == null ? null : ltFromRef(r, b);
    return v == null ? null : (price: v, kind: PriceKind.ref, ref: r);
  }

  /// Typical LT price for a package of size [b]; null when units differ or sizes are far apart.
  static double? ltFromRef(RefPrice r, Qty b) {
    if (b.unit != r.unit || b.qty <= 0) return null;
    // Guard against nonsense comparisons (a 25 kg sack vs a 200 g pack).
    if (r.exQty > 0 && (b.qty / r.exQty > 12 || r.exQty / b.qty > 12)) return null;
    return (r.unitMedian * b.qty * 100).roundToDouble() / 100;
  }

  Future<void> loadPrices() async {
    try {
      final cached = _prefs.getString('$_key.prices');
      priceFeed = PriceFeed.parse(cached ?? await PriceFeed.bundled());
      notifyListeners();
    } catch (_) {}
    try {
      final body = await PriceFeed.fetch();
      priceFeed = PriceFeed.parse(body);
      await _prefs.setString('$_key.prices', body);
      notifyListeners();
    } catch (_) {/* keep cached or bundled prices */}
  }

  // Shops (OpenStreetMap) and the shopper's choice per town and chain
  StoreFeed? storeFeed;
  final Map<String, String> storeChoice = {}; // 'suwalki/lidl' → store id; 'suwalki/fuel' too

  /// The shop the plan uses for a chain in the destination town.
  Store? storeFor(String chain) {
    final f = storeFeed;
    if (f == null) return null;
    final picked = f.byId(storeChoice['$destId/$chain']);
    if (picked != null && picked.town == destId) return picked;
    final l = f.inTown(destId, chain);
    if (l.isEmpty) return null;
    if (chain == 'fuel') {
      // Fill up last, on the way home: the station with known hours nearest to home.
      final known = l.where((x) => x.hours != null && x.address != null).toList();
      final pool = known.isEmpty ? l : known;
      pool.sort((a, b) => kmBetween(a.lat, a.lon, origin.lat, origin.lon).compareTo(kmBetween(b.lat, b.lon, origin.lat, origin.lon)));
      return pool.first;
    }
    return l.first;
  }

  void chooseStore(String chain, String storeId) => update((s) => s.storeChoice['$destId/$chain'] = storeId);

  Future<void> loadStores() async {
    try {
      final cached = _prefs.getString('$_key.stores');
      storeFeed = StoreFeed.parse(cached ?? await StoreFeed.bundled());
      notifyListeners();
    } catch (_) {}
    try {
      final body = await StoreFeed.fetch();
      storeFeed = StoreFeed.parse(body);
      await _prefs.setString('$_key.stores', body);
      notifyListeners();
    } catch (_) {/* keep cached or bundled shops */}
  }

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

  final Map<String, List<Deal>> _matchCache = {};
  Object? _matchKey;

  /// This trip's deals for a Polish shelf name (trip shops, cards, day), best first.
  List<Deal> dealsFor(String? plName) => dealsAnywhere(plName).where(dealUsable).toList();

  /// This week's deals for a Polish shelf name in every chain, best first. Cached per feed.
  List<Deal> dealsAnywhere(String? plName) {
    if (plName == null || plName.isEmpty) return const [];
    final key = (feed, feedConfig);
    if (_matchKey != key) {
      _matchCache.clear();
      _matchKey = key;
    }
    return _matchCache.putIfAbsent(plName, () {
      var food = false;
      for (final t in terms) {
        if (t.pl == plName) food = const {'meat', 'dairy', 'pantry', 'drinks'}.contains(t.cat);
      }
      return matchDeals(plName, deals, food: food);
    });
  }

  /// List lines with a Polish price (from a deal or typed).
  ({double plEur, int n}) plOnlyTotal() {
    var sum = 0.0;
    var n = 0;
    for (final i in items) {
      final p = plFor(i);
      if (p == null) continue;
      final e = toEur(p.price);
      if (e == null) continue;
      sum += e * i.qty;
      n++;
    }
    return (plEur: sum, n: n);
  }

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
      tripReady = j['tripReady'] as bool? ?? false;
      tripChains
        ..clear()
        ..addAll(((j['tripChains'] as List?) ?? []).cast<String>());
      cards
        ..clear()
        ..addAll(((j['cards'] as List?) ?? []).cast<String>());
      tripDate = j['tripDate'] as String?;
      ltShop = j['ltShop'] as String? ?? 'maxima';
      items
        ..clear()
        ..addAll(((j['items'] as List?) ?? []).map((e) => ListItem.fromJson(e as Map<String, dynamic>)));
      if (((j['v'] as num?) ?? 1) < 2) {
        // v1 copied a deal's price and shop into the line, so lines stuck to shops the
        // shopper never planned to visit. Deal prices are now looked up per trip.
        for (final i in items.where((e) => e.dealId != null)) {
          i.plPrice = null;
          i.chain = null;
        }
      }
      ((j['priceFixes'] as Map?) ?? {}).forEach((k, v) => priceFixes['$k'] = (v as num).toDouble());
      watch
        ..clear()
        ..addAll(((j['watch'] as List?) ?? []).map((e) => WatchItem.fromJson(e as Map<String, dynamic>)));
      alerted.addAll(((j['alerted'] as List?) ?? []).cast<String>());
      alertsOn = j['alertsOn'] as bool? ?? false;
      trips
        ..clear()
        ..addAll(((j['trips'] as List?) ?? []).map((e) => TripRecord.fromJson(e as Map<String, dynamic>)));
      ((j['storeChoice'] as Map?) ?? {}).forEach((k, v) => storeChoice['$k'] = '$v');
      ((j['priceMemory'] as Map?) ?? {}).forEach((k, v) {
        final m = v as Map;
        priceMemory['$k'] = (pl: (m['pl'] as num).toDouble(), chain: m['chain'] as String?, date: m['date'] as String? ?? '');
      });
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
      final fu = _prefs.getString('$_key.fuel');
      if (fu != null) fuelFeed = FuelFeed.fromJson(jsonDecode(fu) as Map<String, dynamic>);
      final c = _prefs.getString('$_key.feedConfig');
      if (c != null) feedConfig = FeedConfig.fromJson(jsonDecode(c) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _save() => _prefs.setString(
        _key,
        jsonEncode({
          'v': 2, 'lang': lang.name, 'textScale': textScale, 'theme': themeMode.name, 'onboarded': onboarded,
          'originId': originId, 'destId': destId, 'fuel': fuel.name, 'consumption': consumption,
          'refuelLitres': refuelLitres, 'travellers': travellers, 'ltFuelPrice': ltFuelPrice, 'plFuelPrice': plFuelPrice,
          'cardFeePct': cardFeePct, 'items': items.map((e) => e.toJson()).toList(), 'rate': rate?.toJson(), 'priceFixes': priceFixes,
          'storeChoice': storeChoice,
          'tripReady': tripReady, 'tripChains': tripChains, 'cards': cards.toList(), 'tripDate': tripDate, 'ltShop': ltShop,
          'watch': watch.map((w) => w.toJson()).toList(), 'alerted': alerted.toList(), 'alertsOn': alertsOn,
          'trips': trips.map((t) => t.toJson()).toList(),
          'priceMemory': priceMemory.map((k, v) => MapEntry(k, {'pl': v.pl, 'chain': v.chain, 'date': v.date})),
        }),
      );

  void update(void Function(AppState s) fn) {
    fn(this);
    notifyListeners();
    _save();
  }

  // ── List operations
  void addItem(ListItem item) => update((s) {
        s.items.insert(0, item);
        s._remember(item);
      });
  void removeItem(String id) => update((s) => s.items.removeWhere((e) => e.id == id));
  void restoreItem(ListItem item, int index) => update((s) => s.items.insert(index.clamp(0, s.items.length), item));
  void changeItem(String id, void Function(ListItem i) fn) => update((s) {
        final i = s.items.firstWhere((e) => e.id == id);
        fn(i);
        s._remember(i);
      });
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
    tripReady = false;
    tripChains.clear();
    cards.clear();
    tripDate = null;
    ltShop = 'maxima';
    priceFixes.clear();
    priceMemory.clear();
    storeChoice.clear();
    watch.clear();
    alerted.clear();
    alertsOn = false;
    trips.clear();
    await _prefs.remove('$_key.feed');
    feed = null;
    notifyListeners();
  }

  // ── Money
  /// PLN → EUR including the user's card fee. Null when no rate is known yet.
  double? toEur(double pln) => rate == null ? null : pln / rate!.mid * (1 + cardFeePct / 100);

  /// Savings for one list line (positive = Poland cheaper). Null if prices or rate missing.
  double? itemSaving(ListItem i) {
    final p = plFor(i), l = ltFor(i);
    if (p == null || l == null) return null;
    final pl = toEur(p.price);
    if (pl == null) return null;
    return (l.price - pl) * i.qty;
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
        pl += toEur(plFor(i)!.price)! * i.qty;
        lt += ltFor(i)!.price * i.qty;
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
      try {
        final fb = await FuelFeed.fetch();
        if (fb.isNotEmpty) {
          fuelFeed = FuelFeed.fromJson(jsonDecode(fb) as Map<String, dynamic>);
          await _prefs.setString('$_key.fuel', fb);
        }
      } catch (_) {/* keep cached fuel prices */}
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
