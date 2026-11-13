import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zlotika/core/app_state.dart';
import 'package:zlotika/services/deals.dart';
import 'package:zlotika/services/match.dart';

Deal _d(String id, String chain, String name, double price) => Deal(id: id, chain: chain, name: name, price: price);

void main() {
  test('free-text watch finds brands anywhere in the name', () {
    final deals = [
      _d('1', 'lidl', 'Kawa JACOBS Krönung ziarnista 500 g', 29.99),
      _d('2', 'biedronka', 'Jacobs Velvet mielona', 19.99),
      _d('3', 'kaufland', 'Herbata Lipton', 9.99),
    ];
    expect(matchLoose('Jacobs', deals).map((d) => d.id), ['2', '1']);
    expect(matchLoose('jacobs krönung', deals).map((d) => d.id), ['1']);
    expect(matchLoose('Pampers 4', [_d('4', 'rossmann', 'Pampers Premium Care 4, 52 szt.', 59.99), _d('5', 'rossmann', 'Pampers 5', 59.99)]).map((d) => d.id), ['4']);
    expect(matchLoose('a', deals), isEmpty);
  });

  group('watchlist alerts', () {
    late AppState s;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      s = AppState(await SharedPreferences.getInstance());
      s.feed = DealFeed(generatedAt: DateTime.now(), deals: [_d('a', 'lidl', 'Jacobs Krönung 500 g', 29.99)], sources: const []);
    });

    test('deals present when an item is added are not alerted; new ones are, once', () {
      s.addWatch(WatchItem(id: 'w', name: 'Kava', pl: 'Jacobs'));
      expect(s.takeNewWatchHits(), isEmpty);
      s.feed = DealFeed(
        generatedAt: DateTime.now(),
        deals: [_d('a', 'lidl', 'Jacobs Krönung 500 g', 29.99), _d('b', 'biedronka', 'Jacobs Velvet 400 g', 21.99)],
        sources: const [],
      );
      final hits = s.takeNewWatchHits();
      expect(hits.map((h) => h.$2.id), ['b']);
      expect(s.takeNewWatchHits(), isEmpty);
    });

    test('expired deal ids are forgotten', () {
      s.addWatch(WatchItem(id: 'w', name: 'Kava', pl: 'Jacobs'));
      s.feed = DealFeed(generatedAt: DateTime.now(), deals: const [], sources: const []);
      s.takeNewWatchHits();
      expect(s.alerted, isEmpty);
    });
  });

  test('year totals count net savings of trips that year only', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    s.addTrip(TripRecord(date: '2026-03-01', dest: 'Suwałki', pln: 400, eur: 92, items: 10, saving: 30, travel: 12));
    s.addTrip(TripRecord(date: '2026-11-14', dest: 'Suwałki', pln: 200, eur: 46, items: 5, travel: 10)); // no LT prices known
    s.addTrip(TripRecord(date: '2025-12-20', dest: 'Białystok', pln: 900, eur: 210, items: 20, saving: 80, travel: 25));
    final y = s.yearTotals(2026);
    expect(y.count, 2);
    expect(y.saved, closeTo(18, 1e-9));
    expect(y.spent, closeTo(138, 1e-9));
  });
}
