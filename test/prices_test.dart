import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zlotika/core/app_state.dart';
import 'package:zlotika/services/deals.dart';
import 'package:zlotika/services/prices.dart';

RefPrice _ref(String source, String unit, double median, double exPrice, double exUnit) => RefPrice(
    source: source, unit: unit, n: 10, unitMin: median * .7, unitMedian: median, pkgMedian: exPrice, exName: 'x', exPrice: exPrice, exUnitPrice: exUnit, exUrl: '');

void main() {
  test('package sizes', () {
    expect(parseQty('250 ml'), (qty: .25, unit: 'l'));
    expect(parseQty('Masło Extra 200 g'), (qty: .2, unit: 'kg'));
    expect(parseQty('4 x 85 g'), (qty: .34, unit: 'kg'));
    expect(parseQty('Pampers Premium Care 4, 52 szt.'), (qty: 52.0, unit: 'units'));
    expect(parseQty('1,5 l'), (qty: 1.5, unit: 'l'));
    expect(parseQty('Banany luzem'), isNull);
  });

  test('deal size: per-kg price, size field, or name when the field just says 1 piece', () {
    expect(dealQty(const Deal(id: 'a', chain: 'lidl', name: 'Schab', price: 15.98, unit: 'kg', unitPrice: 7.99))!.qty, closeTo(2, 1e-9));
    expect(dealQty(const Deal(id: 'b', chain: 'rossmann', name: 'Isana szampon 400 ml', price: 9.99, unit: '1 szt.')), (qty: .4, unit: 'l'));
    expect(dealQty(const Deal(id: 'c', chain: 'rossmann', name: 'Krem', price: 9.99, unit: '50 ml')), (qty: .05, unit: 'l'));
  });

  group('effective prices', () {
    late AppState s;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      s = AppState(await SharedPreferences.getInstance());
      s.feed = DealFeed(generatedAt: DateTime.now(), deals: const [Deal(id: 'd1', chain: 'biedronka', name: 'Masło Extra 200 g', price: 4.99)], sources: const []);
      s.priceFeed = PriceFeed({'Masło': _ref('Barbora', 'kg', 8.36, 1.19, 5.95)}, {'Szampon': _ref('Rossmann', 'l', 40, 15.99, 39.98)}, null);
      s.tripChains.addAll(['biedronka', 'rossmann']);
    });

    test('LT estimate uses the Polish package size', () {
      final i = ListItem(id: '1', name: 'Sviestas', plName: 'Masło'); // priced from the Biedronka deal
      final lt = s.ltFor(i)!;
      expect(lt.kind, PriceKind.ref);
      expect(lt.price, closeTo(1.67, 0.001)); // 8.36 €/kg × 0.2 kg
    });

    test('typed LT price wins; no size means no estimate', () {
      expect(s.ltFor(ListItem(id: '2', name: 'Sviestas', plName: 'Masło', plPrice: 4.99, ltPrice: 2.10))!.price, 2.10);
      expect(s.ltFor(ListItem(id: '3', name: 'Sviestas', plName: 'Masło', plPrice: 4.99)), isNull);
    });

    test('no deal or typed price: the usual Polish price is used, labelled as such', () {
      final p = s.plFor(ListItem(id: '4', name: 'Šampūnas', plName: 'Szampon'))!;
      expect([p.kind, p.price], [PriceKind.ref, 15.99]);
    });

    test('a source switched off remotely is ignored', () {
      s.feedConfig = FeedConfig.fromJson({'priceSources': {'barbora': false}});
      expect(s.ltRef(ListItem(id: '5', name: 'Sviestas', plName: 'Masło')), isNull);
    });

    test('far-apart sizes are not compared', () {
      expect(AppState.ltFromRef(_ref('Barbora', 'kg', 8, 1.6, 8), (qty: 25, unit: 'kg')), isNull);
      expect(AppState.ltFromRef(_ref('Barbora', 'kg', 8, 1.6, 8), (qty: .2, unit: 'l')), isNull);
    });
  });

  group('trip scoping', () {
    late AppState s;
    final today = DateTime.now();
    String day(int add) => DateTime(today.year, today.month, today.day + add).toIso8601String().substring(0, 10);
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      s = AppState(await SharedPreferences.getInstance());
      s.feed = DealFeed(generatedAt: DateTime.now(), sources: const [], deals: [
        const Deal(id: 'aldi', chain: 'aldi', name: 'Masło Extra 200 g', price: 3.99),
        const Deal(id: 'bied', chain: 'biedronka', name: 'Masło Extra 200 g', price: 5.49),
        const Deal(id: 'card', chain: 'biedronka', name: 'Masło ekstra 200 g', price: 4.49, card: true),
        Deal(id: 'old', chain: 'biedronka', name: 'Masło śmietankowe 200 g', price: 2.99, validTo: day(-1)),
      ]);
      s.priceFeed = PriceFeed(const {}, {'Szampon': _ref('Rossmann', 'l', 40, 15.99, 39.98)}, null);
      s.tripChains.add('biedronka');
    });

    final butter = ListItem(id: 'b', name: 'Sviestas', plName: 'Masło');

    test('only the trip shops count: Aldi is ignored when going to Biedronka', () {
      expect(s.plFor(butter)!.price, 5.49);
      expect(s.chainOf(butter), 'biedronka');
      expect(s.cheaperElsewhere(butter).map((d) => d.chain), ['aldi']);
      s.addTripChain('aldi');
      expect(s.plFor(butter)!.price, 3.99);
      expect(s.chainOf(butter), 'aldi');
    });

    test('card-only deals count only with the card', () {
      expect(s.dealsFor('Masło').map((d) => d.id), isNot(contains('card')));
      s.toggleCard('biedronka');
      expect(s.plFor(butter)!.price, 4.49);
    });

    test('a deal that has ended by the trip day is ignored', () {
      expect(s.dealsFor('Masło').map((d) => d.id), isNot(contains('old')));
    });

    test('the shopper can tie an item to one trip shop', () {
      s.addTripChain('aldi');
      final i = ListItem(id: 'x', name: 'Sviestas', plName: 'Masło', chain: 'biedronka');
      expect([s.chainOf(i), s.plFor(i)!.price], ['biedronka', 5.49]);
    });

    test('usual Rossmann prices only when Rossmann is on the trip; unpriced items go to the main shop', () {
      final sh = ListItem(id: 's', name: 'Šampūnas', plName: 'Szampon');
      expect(s.plFor(sh), isNull);
      expect(s.chainOf(sh), 'biedronka');
      s.addTripChain('rossmann');
      expect([s.plFor(sh)!.kind, s.chainOf(sh)], [PriceKind.ref, 'rossmann']);
    });

    test('a pinned deal at a shop that is not on the trip does not count', () {
      final i = ListItem(id: 'p', name: 'Sviestas', plName: 'Masło', dealId: 'aldi');
      expect(s.dealOf(i)!.id, 'bied');
    });
  });

  test('lists saved by v1 lose the copied deal price and shop', () async {
    SharedPreferences.setMockInitialValues({
      'zlotika.v1': '{"items":[{"id":"a","name":"Sviestas","plName":"Masło","plPrice":3.99,"chain":"aldi","dealId":"aldi"},'
          '{"id":"b","name":"Kava","plPrice":20.0}]}'
    });
    final s = AppState(await SharedPreferences.getInstance());
    expect([s.items[0].plPrice, s.items[0].chain, s.items[0].dealId], [null, null, 'aldi']);
    expect(s.items[1].plPrice, 20.0);
  });
}
