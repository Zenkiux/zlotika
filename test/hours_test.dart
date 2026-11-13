import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zlotika/core/hours.dart';
import 'package:zlotika/services/stores.dart';

void main() {
  group('Polish time', () {
    test('winter is UTC+1, summer UTC+2, switches on the last Sundays', () {
      expect(plUtcOffset(DateTime.utc(2026, 1, 15, 12)), 1);
      expect(plUtcOffset(DateTime.utc(2026, 7, 15, 12)), 2);
      // 2026: DST from 29 March 01:00 UTC to 25 October 01:00 UTC.
      expect(plUtcOffset(DateTime.utc(2026, 3, 29, 0, 59)), 1);
      expect(plUtcOffset(DateTime.utc(2026, 3, 29, 1)), 2);
      expect(plUtcOffset(DateTime.utc(2026, 10, 25, 0, 59)), 2);
      expect(plUtcOffset(DateTime.utc(2026, 10, 25, 1)), 1);
    });

    test('plNow gives Polish wall clock from any instant', () {
      final p = plNow(DateTime.utc(2026, 11, 13, 21, 30)); // 22:30 in Warsaw, 23:30 in Vilnius
      expect([p.day, p.hour, p.minute], [13, 22, 30]);
    });
  });

  group('opening_hours', () {
    List<Span>? on(String raw, int wd) => OpeningHours.parse(raw)!.weekday(wd);

    test('simple ranges and Sunday unspecified', () {
      expect(on('Mo-Sa 06:00-22:00', 1), [const Span(360, 1320)]);
      expect(on('Mo-Sa 06:00-22:00', 6), [const Span(360, 1320)]);
      expect(on('Mo-Sa 06:00-22:00', 7), isNull);
    });

    test('day lists and overriding rules', () {
      const r = 'Mo-Th 06:00-22:00; Fr,Sa 06:00-23:30; Su 08:00-20:00';
      expect(on(r, 4), [const Span(360, 1320)]);
      expect(on(r, 5), [const Span(360, 1410)]);
      expect(on(r, 6), [const Span(360, 1410)]);
      expect(on(r, 7), [const Span(480, 1200)]);
    });

    test('comma between rules, off, PH', () {
      final oh = OpeningHours.parse('Mo-Sa 06:00-22:00, Su 09:00-20:00; PH off')!;
      expect(oh.weekday(3), [const Span(360, 1320)]);
      expect(oh.weekday(7), [const Span(540, 1200)]);
      expect(oh.holiday, isEmpty);
      expect(OpeningHours.parse('Mo-Sa 07:00-22:00;Su, PH off')!.weekday(7), isEmpty);
    });

    test('24/7, no days, midnight, wrap-around range', () {
      expect(on('24/7', 7), [const Span(0, 1440)]);
      expect(on('05:00-23:00', 3), [const Span(300, 1380)]);
      expect(on('Mo-Fr 00:00-24:00; Sa 07:00-23:00', 2), [const Span(0, 1440)]);
      expect(on('Sa-Mo 10:00-12:00', 1), [const Span(600, 720)]);
      expect(on('Sa-Mo 10:00-12:00', 2), isNull);
    });

    test('broken values are ignored, not guessed', () {
      expect(OpeningHours.parse('Mo-Sa 19:00-19:00'), isNull);
      expect(OpeningHours.parse('by appointment'), isNull);
      expect(OpeningHours.parse(''), isNull);
      // Date-specific rule skipped, the rest kept.
      final oh = OpeningHours.parse('Mo-Fr 09:00-19:30; Sa 09:00-18:00; Jan 25,Mar 29 Su 10:00-17:00; PH off')!;
      expect(oh.weekday(6), [const Span(540, 1080)]);
    });

    test('every value in the shipped shop list parses or is cleanly rejected', () {
      final j = jsonDecode(File('assets/data/stores.json').readAsStringSync()) as Map<String, dynamic>;
      final hours = {for (final s in j['stores'] as List) (s as Map)['hours']}.whereType<String>();
      var parsed = 0;
      for (final h in hours) {
        if (OpeningHours.parse(h) != null) parsed++;
      }
      expect(parsed / hours.length, greaterThan(.9));
    });
  });

  group('day hours with the Polish trading law', () {
    final shop = OpeningHours.parse('Mo-Sa 06:00-22:00; Su 08:00-20:00')!;

    test('ordinary Sunday: shops closed by law, fuel stations not', () {
      final sun = DateTime(2026, 11, 15);
      expect(dayHours(shop, sun).kind, HoursKind.lawClosed);
      expect(dayHours(shop, sun, fuel: true).kind, HoursKind.open);
    });

    test('trading Sunday uses the Sunday hours', () {
      final h = dayHours(shop, DateTime(2026, 12, 13));
      expect(h.kind, HoursKind.open);
      expect([h.opens, h.closes], [480, 1200]);
    });

    test('holiday closed for shops; Saturday open', () {
      expect(dayHours(shop, DateTime(2026, 11, 11)).kind, HoursKind.lawClosed);
      expect(dayHours(shop, DateTime(2026, 11, 14)).kind, HoursKind.open);
      expect(dayHours(null, DateTime(2026, 11, 14)).kind, HoursKind.unknown);
    });

    test('open now / opens later / closed for the day', () {
      final h = dayHours(shop, DateTime(2026, 11, 14));
      expect(nowStatus(h, 300), (kind: NowKind.opensLater, at: 360));
      expect(nowStatus(h, 600), (kind: NowKind.open, at: 1320));
      expect(nowStatus(h, 1330).kind, NowKind.closedForDay);
    });
  });

  test('store feed: own hours first, else the chain’s usual hours flagged as a guess', () {
    final f = StoreFeed([
      const Store(id: 'a', chain: 'lidl', brand: 'Lidl', town: 'suwalki', lat: 54.1, lon: 22.9, hours: 'Mo-Sa 06:00-22:00'),
      const Store(id: 'b', chain: 'lidl', brand: 'Lidl', town: 'suwalki', lat: 54.1, lon: 22.9, hours: 'Mo-Sa 06:00-22:00'),
      const Store(id: 'c', chain: 'lidl', brand: 'Lidl', town: 'suwalki', lat: 54.1, lon: 22.9),
    ], null);
    expect(f.hoursOf(f.byId('a')!).guessed, isFalse);
    final g = f.hoursOf(f.byId('c')!);
    expect(g.guessed, isTrue);
    expect(g.hours!.weekday(1), [const Span(360, 1320)]);
    expect(f.inTown('suwalki', 'lidl').last.id, 'c');
  });
}
