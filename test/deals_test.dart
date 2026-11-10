import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zlotika/core/app_state.dart';
import 'package:zlotika/data/dictionary.dart';
import 'package:zlotika/services/deals.dart';

void main() {
  test('Polish deal titles get a best-effort translation', () {
    expect(guessTerm('Masło Extra 82% Łaciate 200 g')?.lt, 'Sviestas');
    expect(guessTerm('Kawa mielona Jacobs Krönung 500 g')?.lt, 'Malta kava');
    expect(guessTerm('Pieluchy Pampers Active Baby 4, 58 szt.')?.lt, 'Sauskelnės');
    expect(guessTerm('Xyz 123'), isNull);
    expect(guessTerm('AA Ideal Tone podkład do twarzy'), isNull); // not 'twaróg' (curd)
  });

  test('Remote switches hide disabled chains and expired deals', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    final today = DateTime.now();
    String day(int add) => today.add(Duration(days: add)).toIso8601String().substring(0, 10);
    s.feed = DealFeed.fromJson(jsonDecode(jsonEncode({
      'generatedAt': today.toIso8601String(),
      'sources': [],
      'deals': [
        {'id': 'a', 'chain': 'lidl', 'name': 'Masło', 'price': 5.99, 'validTo': day(2)},
        {'id': 'b', 'chain': 'biedronka', 'name': 'Kawa', 'price': 19.99, 'validTo': day(2)},
        {'id': 'c', 'chain': 'lidl', 'name': 'Old', 'price': 1.0, 'validTo': day(-1)},
      ],
    })) as Map<String, dynamic>);
    expect(s.deals.map((d) => d.id), ['a', 'b']);
    s.feedConfig = FeedConfig.fromJson({'collectedEnabled': true, 'disabledChains': ['biedronka']});
    expect(s.deals.map((d) => d.id), ['a']);
    s.feedConfig = FeedConfig.fromJson({'collectedEnabled': false});
    expect(s.deals, isEmpty);
    s.setPriceFix('a', 4.49);
    expect(s.dealPrice(s.feed!.deals.first), 4.49);
  });

  test('Leaflets parse and respect the leaflet off switch', () {
    final l = Leaflet.fromJson({
      'id': 'kaufland-1', 'chain': 'kaufland', 'title': 'Kaufland · 05.11 - 10.11', 'link': 'https://x',
      'validTo': '2999-01-01',
      'pages': [
        {'n': 1, 'image': 'https://img/1.jpg', 'link': 'https://x#page=1'},
        {'n': 2, 'image': 'https://img/2.jpg', 'thumb': 'https://img/2s.jpg', 'link': 'https://x#page=2'},
      ],
    });
    expect(l.pages.length, 2);
    expect(l.pages[1].thumb, 'https://img/2s.jpg');
    final d = Deal.fromJson({'id': 'k', 'chain': 'kaufland', 'name': 'Masło', 'price': 5.99, 'ocr': true, 'leaflet': 'kaufland-1', 'page': 2});
    expect(d.ocr, isTrue);
    expect(d.page, 2);
    expect(FeedConfig.fromJson({'leafletsEnabled': false}).leafletsEnabled, isFalse);
  });
}
