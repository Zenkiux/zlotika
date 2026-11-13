import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zlotika/core/app_state.dart';
import 'package:zlotika/services/deals.dart';
import 'package:zlotika/services/fuel.dart';
import 'package:zlotika/services/nbp.dart';
import 'package:zlotika/services/open_prices.dart';
import 'package:zlotika/services/prices.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState(await SharedPreferences.getInstance());
  s.rate = NbpRate(mid: 4.25, date: '2026-11-12', fetchedAt: DateTime(2026, 11, 12));
  return s;
}

void main() {
  test('Polish fuel price never goes above the legal maximum', () async {
    final s = await _state();
    s.fuelFeed = FuelFeed.fromJson({
      'plEu': {'pb95': 1.52, 'diesel': 1.62, 'lpg': .72, 'currency': 'EUR', 'date': '2026-11-09', 'source': 'EU Weekly Oil Bulletin', 'url': ''},
      'plCap': {'pb95': 6.10, 'pb98': 6.70, 'diesel': 7.66, 'date': '2026-11-10', 'source': 'Minister Energii', 'url': ''},
    });
    s.fuel = FuelType.diesel; // 1.62 € × 4.25 = 6.885 zł, under the 7.66 cap
    expect(s.autoPlFuel, closeTo(6.885, 1e-9));
    expect(s.plFuelIsCap, isFalse);
    s.fuel = FuelType.petrol; // 1.52 € × 4.25 = 6.46 zł, above the 6.10 cap → cap
    expect(s.autoPlFuel, 6.10);
    expect(s.plFuelIsCap, isTrue);
    s.fuel = FuelType.lpg; // no cap for LPG
    expect(s.plCap, isNull);
  });

  test('shopper-photographed prices count like deals at trip shops', () async {
    final s = await _state();
    s.tripChains.add('biedronka');
    s.feed = DealFeed.fromJson({
      'generatedAt': DateTime.now().toIso8601String(),
      'deals': [
        {'id': 'op-1', 'chain': 'biedronka', 'name': 'Masło Extra Łaciate, 200 g', 'price': 7.49, 'crowd': true, 'validFrom': '2026-11-12'},
      ],
    });
    final i = ListItem(id: 'b', name: 'Sviestas', plName: 'Masło');
    expect(s.dealOf(i)!.crowd, isTrue);
    expect(s.plFor(i)!.price, 7.49);
  });

  test('OpenStreetMap shop ids map to Open Prices locations', () {
    expect(OpenPrices.osmRef('osm:w1456108900'), (1456108900, 'WAY'));
    expect(OpenPrices.osmRef('osm:n42'), (42, 'NODE'));
    expect(OpenPrices.osmRef('pepco:123'), isNull);
  });

  test("savings compare with the shopper's own Lithuanian shop", () async {
    final s = await _state();
    RefPrice r(String src, double v) => RefPrice(source: src, unit: 'kg', n: 5, unitMin: v, unitMedian: v, pkgMedian: v / 5, exName: 'x', exPrice: v / 5, exUnitPrice: v, exUrl: '');
    s.priceFeed = PriceFeed({'Masło': r('Barbora', 16.0)}, const {}, null, ltRimi: {'Masło': r('Rimi', 14.95)});
    final i = ListItem(id: 'b', name: 'Sviestas', plName: 'Masło');
    expect(s.ltRef(i)!.source, 'Barbora');
    s.ltShop = 'rimi';
    expect(s.ltRef(i)!.source, 'Rimi');
    s.ltShop = 'cheapest';
    expect(s.ltRef(i)!.unitMedian, 14.95);
  });
}
