import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/hours.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/calendar.dart';
import '../../data/chains.dart';
import '../../main.dart';
import '../../services/stores.dart';
import '../../widgets/ui.dart';
import '../list/add_item_screen.dart';
import '../list/item_sheet.dart';
import '../trip/trip_screen.dart' show TripCalc;
import 'checklist_screen.dart';
import '../history/history_screen.dart';

/// The night-before screen: which shops, when they are open, what it will cost,
/// and one route through all of them.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

/// One stop on the route: a shop (or fuel station) and what to buy there.
class _Stop {
  _Stop(this.chain, this.store, this.items);
  final String chain;
  final Store? store;
  final List<ListItem> items;
}

/// Average door-to-door speed for the drive estimate (towns, border, S61).
const _avgKmh = 70;
/// Rough time spent in each shop when working out the latest departure.
const _minutesPerShop = 35;

void _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
String _gmaps(Store st) => 'https://www.google.com/maps/dir/?api=1&destination=${st.lat},${st.lon}&travelmode=driving';
String _waze(Store st) => 'https://waze.com/ul?ll=${st.lat},${st.lon}&navigate=yes';

class _PlanScreenState extends State<PlanScreen> {
  late DateTime _day; // Polish calendar date of the trip

  @override
  void initState() {
    super.initState();
    final p = plNow();
    // After 18:00 in Poland the shopper is planning tomorrow.
    _day = DateTime(p.year, p.month, p.day + (p.hour >= 18 ? 1 : 0));
  }

  bool get _isToday {
    final p = plNow();
    return _day.year == p.year && _day.month == p.month && _day.day == p.day;
  }

  List<_Stop> _stops(AppState s) {
    final byChain = <String, List<ListItem>>{};
    for (final i in s.items.where((e) => !e.checked && e.chain != null)) {
      byChain.putIfAbsent(i.chain!, () => []).add(i);
    }
    final shops = [for (final e in byChain.entries) _Stop(e.key, s.storeFor(e.key), e.value)];
    // Nearest-next from home: a short loop through town, fuel last on the way out.
    final ordered = <_Stop>[];
    var lat = s.origin.lat, lon = s.origin.lon;
    final rest = shops.where((x) => x.store != null).toList();
    while (rest.isNotEmpty) {
      rest.sort((a, b) => kmBetween(lat, lon, a.store!.lat, a.store!.lon).compareTo(kmBetween(lat, lon, b.store!.lat, b.store!.lon)));
      final next = rest.removeAt(0);
      ordered.add(next);
      lat = next.store!.lat;
      lon = next.store!.lon;
    }
    ordered.addAll(shops.where((x) => x.store == null));
    if (s.refuelLitres > 0) ordered.add(_Stop('fuel', s.storeFor('fuel'), const []));
    return ordered;
  }

  String _routeUrl(AppState s, List<_Stop> stops) {
    final pts = [for (final x in stops) if (x.store != null) '${x.store!.lat},${x.store!.lon}'].take(9).join('|');
    final home = Uri.encodeComponent('${s.origin.name}, Lithuania');
    return 'https://www.google.com/maps/dir/?api=1&origin=$home&destination=$home'
        '${pts.isEmpty ? '' : '&waypoints=${Uri.encodeComponent(pts)}'}&travelmode=driving';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final stops = _stops(s);
    final shopStops = stops.where((x) => x.chain != 'fuel').toList();
    final loose = s.items.where((e) => !e.checked && e.chain == null).toList();
    final law = shopDay(_day);
    final lawClosed = law == ShopDay.sundayClosed || law == ShopDay.holiday;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('planTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text('${s.origin.name} → ${s.dest.name}', style: context.tt.headlineSmall),
          const SizedBox(height: 14),
          _DayPicker(value: _day, onChanged: (d) => setState(() => _day = d)),
          const SizedBox(height: 14),
          if (lawClosed)
            Panel(
              color: c.badSoft,
              child: Row(children: [
                Icon(Icons.block_rounded, color: c.bad, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(context.s(law == ShopDay.holiday ? 'planDayHoliday' : 'planDaySunday'), style: context.tt.bodyLarge)),
              ]),
            )
          else
            _Timing(day: _day, isToday: _isToday, stops: shopStops),
          const SizedBox(height: 12),
          _Money(onTrip: () {
            Navigator.pop(context);
            shellTab.value = 3;
          }),
          if (s.items.isEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(context.s('planEmpty'), style: context.tt.titleMedium),
                const SizedBox(height: 12),
                BigButton(
                  label: context.s('listAdd'),
                  icon: Icons.add_rounded,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddItemScreen(), fullscreenDialog: true)),
                ),
              ]),
            ),
          ],
          if (stops.isNotEmpty) SectionTitle(context.s('planStops', {'n': stops.length})),
          for (var i = 0; i < stops.length; i++) _StopCard(n: i + 1, stop: stops[i], day: _day, isToday: _isToday),
          if (loose.isNotEmpty) ...[
            SectionTitle(context.s('planLoose')),
            Panel(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.s('planLooseSub'), style: context.tt.bodyMedium),
                const SizedBox(height: 6),
                for (final i in loose) _ItemLine(item: i),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          if (stops.any((x) => x.store != null))
            BigButton(label: context.s('planRoute'), icon: Icons.alt_route_rounded, onPressed: () => _open(_routeUrl(s, stops))),
          const SizedBox(height: 10),
          if (s.items.isNotEmpty) ...[
            BigButton(label: context.s('finishOpen'), icon: Icons.flag_rounded, kind: BtnKind.secondary, onPressed: () => showFinishTrip(context)),
            const SizedBox(height: 10),
          ],
          BigButton(
            label: context.s('planChecklist'),
            icon: Icons.fact_check_rounded,
            kind: BtnKind.secondary,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChecklistScreen())),
          ),
          const SizedBox(height: 18),
          Text(context.s('planOsm', {'date': s.storeFeed?.generatedAt == null ? '—' : dayMonth(s.storeFeed!.generatedAt!.toLocal(), lang)}),
              style: context.tt.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lang = context.lang;
    final p = plNow();
    final days = [for (var i = 0; i < 7; i++) DateTime(p.year, p.month, p.day + i)];
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final sel = d == value;
          final open = shopsOpen(d);
          final label = i == 0 ? context.s('planToday') : i == 1 ? context.s('planTomorrow') : weekday(d, lang);
          return Semantics(
            selected: sel,
            button: true,
            child: GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? Brand.yellow : c.raised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: open ? Colors.transparent : c.bad.withValues(alpha: .6), width: 1.5),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, style: context.tt.titleMedium!.copyWith(color: sel ? Brand.ink : c.text, fontWeight: FontWeight.w700)),
                  Text(open ? dayMonth(d, lang) : context.s('planClosedShort'),
                      style: context.tt.bodySmall!.copyWith(color: sel ? Brand.ink.withValues(alpha: .7) : open ? c.text2 : c.bad)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// When to leave: shops' hours that day in both clocks, and the latest sensible departure.
class _Timing extends StatelessWidget {
  const _Timing({required this.day, required this.isToday, required this.stops});
  final DateTime day;
  final bool isToday;
  final List<_Stop> stops;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final km = s.origin.km[s.destId] ?? 0;
    final driveMin = (km / _avgKmh * 60).round();
    final f = s.storeFeed;
    int? opens, closes;
    for (final x in stops) {
      if (x.store == null || f == null) continue;
      final h = dayHours(f.hoursOf(x.store!).hours, day);
      if (h.kind != HoursKind.open) continue;
      opens = opens == null ? h.opens : (h.opens! > opens ? h.opens : opens); // all open
      closes = closes == null ? h.closes : (h.closes! < closes ? h.closes : closes); // first to close
    }
    String both(int m) => '${fmtMin(m)} (LT ${fmtMin(m + 60)})';
    // Latest departure, Lithuanian time: arrive, shop everywhere, before the first shop closes.
    final latest = closes == null ? null : closes + 60 - driveMin - _minutesPerShop * stops.length;
    final now = DateTime.now();
    final late = isToday && latest != null && now.hour * 60 + now.minute > latest;

    Widget line(IconData icon, String text, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 24, color: color ?? c.text2),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: context.tt.bodyLarge!.copyWith(color: color))),
          ]),
        );

    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        line(Icons.route_rounded, context.s('planDrive', {'km': km, 'h': fmtNum(driveMin / 60, context.lang)})),
        if (opens != null && closes != null) line(Icons.storefront_rounded, context.s('planHours', {'from': both(opens), 'to': both(closes)})),
        if (latest != null && latest > 0)
          line(late ? Icons.warning_amber_rounded : Icons.schedule_rounded, context.s(late ? 'planLate' : 'planLeaveBy', {'t': fmtMin(latest)}),
              color: late ? c.bad : null),
        line(Icons.access_time_rounded, context.s('planTz')),
      ]),
    );
  }
}

/// Expected spend in Poland: deal prices, typed prices, then last time's price.
class _Money extends StatelessWidget {
  const _Money({required this.onTrip});
  final VoidCallback onTrip;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    var pln = 0.0;
    var guessed = 0, unknown = 0;
    for (final i in s.items.where((e) => !e.checked)) {
      final p = s.plFor(i);
      if (p == null) {
        unknown++;
        continue;
      }
      if (p.kind == PriceKind.last || p.kind == PriceKind.ref) guessed++;
      pln += p.price * i.qty;
    }
    final e = s.toEur(pln);
    final t = TripCalc(s);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.s('planSpend'), style: context.tt.bodyMedium),
        const SizedBox(height: 2),
        Text('${zl(pln, lang)}${e == null ? '' : '  ≈ ${eur(e, lang)}'}', style: context.tt.headlineSmall),
        if (guessed > 0) Text(context.s('planGuessed', {'n': guessed}), style: context.tt.bodyMedium),
        if (unknown > 0) Text(context.s('planUnknown', {'n': unknown}), style: context.tt.bodyMedium!.copyWith(color: c.warn)),
        if (t.ready && s.rate != null) ...[
          Divider(color: c.line, height: 22),
          InkWell(
            onTap: onTrip,
            child: Row(children: [
              Icon(t.net >= 0 ? Icons.savings_rounded : Icons.trending_down_rounded, color: t.net >= 0 ? c.good : c.bad),
              const SizedBox(width: 10),
              Expanded(child: Text(context.s('planNet', {'v': eurSigned(t.net, lang)}), style: context.tt.titleMedium!.copyWith(color: t.net >= 0 ? c.good : c.bad))),
              Icon(Icons.chevron_right_rounded, color: c.text3),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.n, required this.stop, required this.day, required this.isToday});
  final int n;
  final _Stop stop;
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final fuel = stop.chain == 'fuel';
    final chain = chainById(stop.chain);
    final st = stop.store;
    final title = fuel ? (st?.brand ?? context.s('planFuel')) : (chain?.name ?? stop.chain);
    var sub = 0.0;
    var subKnown = true;
    for (final i in stop.items) {
      final p = s.plFor(i)?.price;
      if (p == null) {
        subKnown = false;
      } else {
        sub += p * i.qty;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fuel ? Brand.green : chain?.color ?? c.raised, borderRadius: BorderRadius.circular(12)),
              child: fuel
                  ? const Icon(Icons.local_gas_station_rounded, color: Colors.white)
                  : Text('$n', style: context.tt.titleLarge!.copyWith(color: chain?.ink ?? c.text, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fuel ? '${context.s('planFuel')} · $title' : title, style: context.tt.titleLarge),
                if (st == null)
                  Text(context.s('planNoShop', {'town': s.dest.name}), style: context.tt.bodyMedium!.copyWith(color: c.warn))
                else ...[
                  Text(st.address ?? st.name ?? context.s('planNoAddress'), style: context.tt.bodyMedium),
                  const SizedBox(height: 6),
                  _HoursPill(store: st, day: day, isToday: isToday),
                ],
              ]),
            ),
          ]),
          if (st != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 4, children: [
              TextButton.icon(onPressed: () => _open(_gmaps(st)), icon: const Icon(Icons.map_rounded, size: 20), label: const Text('Google Maps')),
              TextButton.icon(onPressed: () => _open(_waze(st)), icon: const Icon(Icons.navigation_rounded, size: 20), label: const Text('Waze')),
              if ((s.storeFeed?.inTown(s.destId, stop.chain).length ?? 0) > 1)
                TextButton.icon(
                  onPressed: () => _pickStore(context, stop.chain),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  label: Text(context.s('planOtherShop')),
                ),
            ]),
          ],
          if (fuel)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(context.s('planFuelLitres', {'l': s.refuelLitres}), style: context.tt.bodyMedium),
            ),
          if (stop.items.isNotEmpty) ...[
            Divider(color: c.line),
            for (final i in stop.items) _ItemLine(item: i),
            Divider(color: c.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: Row(children: [
                Expanded(child: Text(context.s('planSubtotal'), style: context.tt.titleMedium)),
                Text('${subKnown ? '' : '≥ '}${zl(sub, lang)}', style: context.tt.titleLarge),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _HoursPill extends StatelessWidget {
  const _HoursPill({required this.store, required this.day, required this.isToday});
  final Store store;
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final (:hours, :guessed) = s.storeFeed!.hoursOf(store);
    final h = dayHours(hours, day, fuel: store.isFuel);
    String text;
    Color fg, bg;
    switch (h.kind) {
      case HoursKind.lawClosed:
      case HoursKind.closed:
        (text, fg, bg) = (context.s('hoursClosed'), c.bad, c.badSoft);
      case HoursKind.unknown:
        (text, fg, bg) = (context.s('hoursUnknown'), c.text2, c.raised);
      case HoursKind.open when h.spans.length == 1 && h.opens == 0 && h.closes == 1440:
        (text, fg, bg) = (context.s('hours247'), c.good, c.goodSoft);
      case HoursKind.open:
        final range = h.spans.map((x) => '$x').join(', ');
        text = '$range (LT ${fmtMin(h.opens! + 60)}–${fmtMin(h.closes! + 60)})';
        (fg, bg) = (c.good, c.goodSoft);
        if (isToday) {
          final p = plNow();
          final now = nowStatus(h, p.hour * 60 + p.minute);
          text = switch (now.kind) {
            NowKind.open => context.s('hoursOpenUntil', {'t': fmtMin(now.at!), 'lt': fmtMin(now.at! + 60)}),
            NowKind.opensLater => context.s('hoursOpensAt', {'t': fmtMin(now.at!), 'lt': fmtMin(now.at! + 60), 'c': fmtMin(h.closes!), 'lc': fmtMin(h.closes! + 60)}),
            _ => context.s('hoursClosedNow'),
          };
          if (now.kind == NowKind.closedForDay) (fg, bg) = (c.bad, c.badSoft);
        }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Pill(text, fg: fg, bg: bg, icon: Icons.schedule_rounded),
      if (guessed && h.kind == HoursKind.open)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.s('hoursGuessed'), style: context.tt.bodySmall)),
    ]);
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});
  final ListItem item;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final est = s.plFor(item);
    final last = est?.kind == PriceKind.last ? s.lastPrice(item) : null;
    final exact = est?.kind == PriceKind.deal || est?.kind == PriceKind.typed;
    final price = est == null ? null : '${exact ? '' : '≈ '}${zl(est.price * item.qty, lang)}';
    final lt = s.ltFor(item);
    final saving = s.itemSaving(item);
    return InkWell(
      onTap: () => showItemSheet(context, item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.qty > 1 ? '${item.qty} × ${item.name}' : item.name, style: context.tt.titleMedium),
              if (item.plName != null) ...[const SizedBox(height: 2), PlName(item.plName!)],
              if (last != null) Text(context.s('planLastTime', {'d': last.date}), style: context.tt.bodySmall),
              if (est?.kind == PriceKind.ref) Text(context.s('refUsualPl', {'src': est!.ref!.source}), style: context.tt.bodySmall),
              if (lt != null && saving != null)
                Text(
                  context.s(saving >= 0 ? 'planVsLt' : 'planVsLtWorse', {'lt': '${lt.kind == PriceKind.ref ? '≈ ' : ''}${eur(lt.price * item.qty, lang)}', 'v': eur(saving.abs(), lang)}),
                  style: context.tt.bodySmall!.copyWith(color: saving >= 0 ? c.good : c.bad),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          Text(price ?? context.s('planNoPrice'), style: context.tt.titleMedium!.copyWith(color: price == null ? c.warn : null)),
        ]),
      ),
    );
  }
}

Future<void> _pickStore(BuildContext context, String chain) => showSheet(context, (ctx) {
      final s = AppScope.of(ctx);
      final f = s.storeFeed!;
      final list = f.inTown(s.destId, chain);
      final current = s.storeFor(chain);
      final p = plNow();
      final today = DateTime(p.year, p.month, p.day);
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(chain == 'fuel' ? ctx.s('planFuel') : chainById(chain)?.name ?? chain, style: ctx.tt.headlineSmall),
          const SizedBox(height: 12),
          for (final st in list)
            ChoiceRow(
              title: st.address ?? st.name ?? ctx.s('planNoAddress'),
              subtitle: () {
                final h = dayHours(f.hoursOf(st).hours, today, fuel: st.isFuel);
                final brand = chain == 'fuel' ? '${st.brand} · ' : '';
                return h.kind == HoursKind.open ? '$brand${ctx.s('planToday')}: ${h.spans.join(', ')}' : '$brand${ctx.s(h.kind == HoursKind.unknown ? 'hoursUnknown' : 'hoursClosed')}';
              }(),
              selected: st.id == current?.id,
              leading: const Icon(Icons.location_on_rounded, color: Brand.plRed),
              onTap: () {
                s.chooseStore(chain, st.id);
                Navigator.pop(ctx);
              },
            ),
        ],
      );
    });
