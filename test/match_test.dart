import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zlotika/data/dictionary.dart';
import 'package:zlotika/services/deals.dart';
import 'package:zlotika/services/match.dart';

void main() {
  test('inflected Polish names match', () {
    Deal d(String n) => Deal(id: n, chain: 'lidl', name: n, price: 1);
    final ds = [d('Masło Extra Mlekovita 200 g'), d('Chleb z masłem'), d('Filet z piersi kurczaka 1 kg'), d('Kurczak cały'), Deal(id: 'x', chain: 'aldi', name: 'MLEKOVITA · Masło polskie extra', price: 1), d('Cukierki owocowe'), d('Cukier biały 1 kg')];
    expect(matchDeals('Masło', ds).map((e) => e.name), ['Masło Extra Mlekovita 200 g', 'MLEKOVITA · Masło polskie extra']);
    expect(matchDeals('Mleko', ds), isEmpty);
    expect(matchDeals('Cukier', ds).map((e) => e.name), ['Cukier biały 1 kg']);
    expect(matchDeals('Filet z piersi kurczaka', ds).map((e) => e.name), ['Filet z piersi kurczaka 1 kg']);
  });

  test('coverage on the live feed', () {
    final f = File('/private/tmp/claude-501/-Volumes-ADATA-Zlotika/d975f933-264b-4a33-aae5-2f54787ce537/scratchpad/deals.json');
    if (!f.existsSync()) return;
    final deals = DealFeed.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>).deals;
    var hit = 0;
    for (final t in terms) {
      final m = matchDeals(t.pl, deals, food: const {'meat', 'dairy', 'pantry', 'drinks'}.contains(t.cat));
      if (m.isNotEmpty) hit++;
      // ignore: avoid_print
      print('${t.pl.padRight(28)} ${m.length.toString().padLeft(2)}  ${m.take(3).map((e) => '${e.chain}: ${e.name} ${e.price}').join(' | ')}');
    }
    // ignore: avoid_print
    print('terms with deals: $hit / ${terms.length}');
  });
}
