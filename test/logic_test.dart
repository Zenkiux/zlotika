import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zlotika/core/app_state.dart';
import 'package:zlotika/core/format.dart';
import 'package:zlotika/core/i18n.dart';
import 'package:zlotika/data/calendar.dart';
import 'package:zlotika/data/dictionary.dart';
import 'package:zlotika/features/trip/trip_screen.dart';
import 'package:zlotika/services/nbp.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState(await SharedPreferences.getInstance());
  s.rate = NbpRate(mid: 4.0, date: '2026-11-10', fetchedAt: DateTime(2026, 11, 10));
  return s;
}

void main() {
  test('Polish shop calendar', () {
    expect(shopDay(DateTime(2026, 11, 15)), ShopDay.sundayClosed);
    expect(shopDay(DateTime(2026, 12, 13)), ShopDay.tradingSunday);
    expect(shopDay(DateTime(2026, 11, 11)), ShopDay.holiday);
    expect(shopDay(DateTime(2026, 11, 14)), ShopDay.open);
    expect(nextSaturday(DateTime(2026, 11, 10)), DateTime(2026, 11, 14));
  });

  test('Lithuanian money formatting', () {
    expect(eur(1234.5, Lang.lt), '1 234,50 €');
    expect(eur(12.5, Lang.en), '€12.50');
    expect(zl(6.99, Lang.lt), '6,99 zł');
    expect(parseAmount('12,99'), 12.99);
    expect(parseAmount('abc'), isNull);
  });

  test('Dictionary finds Polish shelf names from Lithuanian and Polish words', () {
    expect(searchTerms('vištienos krūtinėlė').first.pl, 'Filet z piersi kurczaka');
    expect(searchTerms('podpaski').first.lt, 'Higieniniai paketai');
    expect(searchTerms('sauskelnes').first.pl, 'Pieluchy');
  });

  test('Basket savings only count items cheaper in Poland', () async {
    final s = await _state();
    s.items.addAll([
      ListItem(id: 'a', name: 'Kava', qty: 2, plPrice: 20, ltPrice: 8), // 5 € in PL → saves 3 × 2
      ListItem(id: 'b', name: 'Grikiai', plPrice: 10, ltPrice: 2), // 2.5 € in PL → dearer, ignored
      ListItem(id: 'c', name: 'Sviestas'), // no prices
    ]);
    final b = s.basket();
    expect(b.saving, closeTo(6, 1e-9));
    expect(b.plEur, closeTo(10, 1e-9));
    expect(b.ltEur, closeTo(16, 1e-9));
    expect(b.priced, 2);
    expect(b.missing, 1);
  });

  test('Trip net equals the sum of its displayed parts', () async {
    final s = await _state();
    s.originId = 'kaunas';
    s.destId = 'suwalki'; // 124 km one way
    s.consumption = 6.2;
    s.ltFuelPrice = 1.749;
    s.plFuelPrice = 5.6; // 1.40 €/l at rate 4.0
    s.refuelLitres = 40;
    s.items.add(ListItem(id: 'a', name: 'Kava', qty: 10, plPrice: 20, ltPrice: 8)); // saves 30 €
    final t = TripCalc(s);
    expect(t.km, 248);
    expect(t.tripCost, 26.89); // 248 × 6.2 / 100 × 1.749 = 26.892…
    expect(t.refuelSaving, 13.96); // 40 × 0.349
    expect(t.shopping, 30.0);
    expect(t.net, closeTo(t.shopping + t.refuelSaving - t.tripCost, 1e-9));
    expect(t.breakEven, isNotNull);
  });
}
