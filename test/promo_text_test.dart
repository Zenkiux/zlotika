import 'package:flutter_test/flutter_test.dart';
import 'package:zlotika/core/i18n.dart';
import 'package:zlotika/data/promo_text.dart';

void main() {
  test('Biedronka conditions read in Lithuanian', () {
    expect(promoText('Drugi za 5 zł, limit dzienny 2 szt. za 5 zł na kartę MB', Lang.lt),
        'Antras už 5 zł, ne daugiau 2 vnt. per dieną su Moja Biedronka kortele');
    expect(promoText('Drugi za 5 zł, mieszaj dowolnie', Lang.lt), 'Antras už 5 zł, galima maišyti rūšis');
    expect(promoText('1+1 gratis', Lang.en), 'Buy 1, get 1 free');
    expect(promoText('-33% PRZY ZAKUPIE 2 SZT.', Lang.lt), '−33 % perkant 2 vnt.');
    expect(promoText('drugi 66% taniej, każda z 2 sztuk', Lang.lt), 'Antras 66 % pigiau, kaina už vienetą, perkant 2');
    expect(promoFullyTranslated('Drugi 50% taniej, każda z 2 sztuk, z kartą lub apką', Lang.lt), isTrue);
  });

  test('"second for 5 zł" counts the real price per item', () {
    final r = multibuyUnitPrice('Drugi za 5 zł', 5, 45.99)!;
    expect(r.price, 25.5);
    expect(r.qty, 2);
    expect(multibuyUnitPrice('drugi za 5 zł/kg', 5, 20), isNull);
    expect(multibuyUnitPrice('Drugi za 5 zł', 12.99, 45.99), isNull);
  });
}
