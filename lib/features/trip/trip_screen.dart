import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/hours.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/calendar.dart';
import '../../data/chains.dart';
import '../../data/geo.dart';
import '../../main.dart' show shellTab, Tabs;
import '../../services/fuel.dart';
import '../../services/stores.dart';
import '../more/more_screen.dart' show SettingsButton, UpdateBanner;
import '../../widgets/ui.dart';
import '../history/history_screen.dart';
import '../list/add_item_screen.dart';
import '../list/deal_pick.dart' show dealName;
import '../../data/dictionary.dart';
import '../../services/deals.dart';
import '../../services/match.dart';
import '../plan/checklist_screen.dart';
import '../map/map_screen.dart' show osmTiles;
import '../calc/calc_screen.dart' show openCalc;

/// Trip economics. Every number shown is derived here from the trip, the list and the NBP rate.
class TripCalc {
  TripCalc(AppState s)
      : km = (s.origin.km[s.destId] ?? 0) * 2,
        litres = (s.origin.km[s.destId] ?? 0) * 2 * s.consumption / 100,
        fuelCost = s.ltFuel == null ? null : (s.origin.km[s.destId] ?? 0) * 2 * s.consumption / 100 * s.ltFuel!,
        plFuelEur = s.plFuel == null ? null : s.toEur(s.plFuel!),
        basket = s.basket(),
        refuelLitres = s.refuelLitres,
        travellers = s.travellers,
        ltFuel = s.ltFuel;

  final int km;
  final double litres;
  final double? fuelCost; // trip fuel at LT price
  final double? plFuelEur;
  final ({double plEur, double ltEur, double saving, int priced, int missing}) basket;
  final int refuelLitres, travellers;
  final double? ltFuel;

  double _r(double v) => (v * 100).roundToDouble() / 100;

  double get refuelSaving => (ltFuel == null || plFuelEur == null) ? 0 : _r(refuelLitres * (ltFuel! - plFuelEur!));
  double get tripCost => _r(fuelCost ?? 0);
  double get shopping => _r(basket.saving);
  double get net => _r(shopping + refuelSaving - tripCost);
  bool get ready => fuelCost != null && plFuelEur != null;

  /// LT-priced basket at which shopping savings cover the trip, if the savings rate is known.
  double? get breakEven {
    if (basket.ltEur <= 0 || basket.saving <= 0) return null;
    final rate = basket.saving / basket.ltEur;
    final need = tripCost - refuelSaving;
    return need <= 0 ? 0 : need / rate;
  }
}

/// Average door-to-door speed for the drive estimate (towns, border, S61).
const _avgKmh = 70;
/// Rough time spent in each shop when working out the latest departure.
const _minutesPerShop = 35;

void _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
String _gmaps(Store st) => 'https://www.google.com/maps/dir/?api=1&destination=${st.lat},${st.lon}&travelmode=driving';
String _waze(Store st) => 'https://waze.com/ul?ll=${st.lat},${st.lon}&navigate=yes';

String _fuelName(BuildContext context, FuelType f) =>
    context.s(switch (f) { FuelType.diesel => 'fuelDiesel', FuelType.petrol => 'fuelPetrol', FuelType.lpg => 'fuelLpg' });

String _dayLabel(BuildContext context, DateTime d) {
  final p = plNow();
  final today = DateTime(p.year, p.month, p.day);
  final diff = d.difference(today).inDays;
  final wd = weekday(d, context.lang);
  final name = diff == 0 ? context.s('planToday') : diff == 1 ? context.s('planTomorrow') : wd[0].toUpperCase() + wd.substring(1);
  return '$name, ${dayMonth(d, context.lang)}';
}

/// The first tab. No trip yet → a few one-tap questions. Otherwise → the trip itself.
class TripScreen extends StatelessWidget {
  const TripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: s.tripReady ? const _Overview(key: ValueKey('o')) : const _Setup(key: ValueKey('s')),
      ),
    );
  }
}

// ───────────────────────────── Setup: one question per screen

enum _Q { from, to, shops, cards, home, day, car }

class _Setup extends StatefulWidget {
  const _Setup({super.key});

  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  int _i = 0;

  List<_Q> _steps(AppState s) => [
        _Q.from,
        _Q.to,
        _Q.shops,
        if (s.tripChains.any((c) => chainById(c)?.card != null)) _Q.cards,
        _Q.home,
        _Q.day,
        _Q.car,
      ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final steps = _steps(s);
    final i = _i.clamp(0, steps.length - 1);
    final q = steps[i];
    final last = i == steps.length - 1;
    void next() => last ? s.update((x) => x.tripReady = true) : setState(() => _i = i + 1);
    final canNext = q != _Q.shops || s.tripChains.isNotEmpty;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
        child: Row(children: [
          if (i > 0)
            IconButton(onPressed: () => setState(() => _i = i - 1), icon: const Icon(Icons.arrow_back_rounded, size: 28), tooltip: context.s('back'))
          else
            const SizedBox(width: 12),
          Expanded(child: Text(context.s('tripStep', {'i': i + 1, 'n': steps.length}), style: context.tt.labelMedium)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(children: [
          for (var k = 0; k < steps.length; k++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: k == steps.length - 1 ? 0 : 6),
                decoration: BoxDecoration(color: k <= i ? Brand.yellow : c.raised, borderRadius: BorderRadius.circular(3)),
              ),
            ),
        ]),
      ),
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: ListView(
            key: ValueKey(q),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: switch (q) {
              _Q.from => [_title(context, 'tripFrom'), _FromPicker(onPicked: next)],
              _Q.to => [_title(context, 'tripTo'), _DestPicker(onPicked: next)],
              _Q.shops => [_title(context, 'tripShops', 'tripShopsSub'), const _ShopsPicker()],
              _Q.cards => [_title(context, 'tripCards', 'tripCardsSub'), const _CardsPicker()],
              _Q.home => [_title(context, 'tripHome', 'tripHomeSub'), _LtShopPicker(onPicked: next)],
              _Q.day => [_title(context, 'tripDay', 'tripDaySub'), _DayPicker(onPicked: next)],
              _Q.car => [_title(context, 'tripCar'), const _CarForm()],
            },
          ),
        ),
      ),
      if (q != _Q.from && q != _Q.to && q != _Q.day && q != _Q.home)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
          child: BigButton(
            label: context.s(last ? 'tripCalc' : 'next'),
            icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
            onPressed: canNext ? next : null,
          ),
        ),
    ]);
  }
}

Widget _title(BuildContext context, String key, [String? sub]) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.s(key), style: context.tt.headlineMedium),
        if (sub != null) ...[const SizedBox(height: 8), Text(context.s(sub), style: context.tt.bodyLarge!.copyWith(color: context.c.text2))],
      ]),
    );

class _FromPicker extends StatelessWidget {
  const _FromPicker({required this.onPicked});
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      for (final o in origins)
        ChoiceRow(
          title: o.name,
          selected: s.originId == o.id,
          leading: const Icon(Icons.home_rounded),
          onTap: () {
            s.update((x) => x.originId = o.id);
            onPicked();
          },
        ),
    ]);
  }
}

class _FromChips extends StatelessWidget {
  const _FromChips();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in origins)
        ChoiceChip(label: Text(o.name), selected: s.originId == o.id, onSelected: (_) => s.update((x) => x.originId = o.id)),
    ]);
  }
}

class _DestPicker extends StatelessWidget {
  const _DestPicker({required this.onPicked});
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      for (final d in destinations)
        ChoiceRow(
          title: d.name,
          subtitle: context.s('tripToSub', {'km': s.origin.km[d.id] ?? '?', 'from': s.origin.name}),
          selected: s.destId == d.id,
          leading: const Icon(Icons.location_on_rounded, color: Brand.plRed),
          onTap: () {
            s.setDest(d.id);
            onPicked();
          },
        ),
    ]);
  }
}

/// Shops in the destination town; several can be picked. Order of picking = order of importance.
class _ShopsPicker extends StatelessWidget {
  const _ShopsPicker();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final here = s.chainsInTown;
    final list = chains.where((c) => here.isEmpty || here.contains(c.id)).toList();
    final dealCount = <String, int>{};
    for (final d in s.deals) {
      dealCount[d.chain] = (dealCount[d.chain] ?? 0) + 1;
    }
    // Most shops in town first (the chains people actually use), then by deals known.
    int shops(Chain ch) => s.storeFeed?.inTown(s.destId, ch.id).length ?? 0;
    list.sort((a, b) {
      final d = shops(b).compareTo(shops(a));
      return d != 0 ? d : (dealCount[b.id] ?? 0).compareTo(dealCount[a.id] ?? 0);
    });
    return Column(children: [
      for (final ch in list)
        ChoiceRow(
          title: ch.name,
          subtitle: context.s((dealCount[ch.id] ?? 0) > 0 ? 'tripShopSub' : 'tripShopSubNoDeals',
              {'n': s.storeFeed?.inTown(s.destId, ch.id).length ?? 0, 'm': dealCount[ch.id] ?? 0}),
          selected: s.tripChains.contains(ch.id),
          leading: ChainDot(ch),
          onTap: () {
            HapticFeedback.selectionClick();
            s.toggleTripChain(ch.id);
          },
        ),
    ]);
  }
}

/// A chain's colour as a small rounded square with its initial.
class ChainDot extends StatelessWidget {
  const ChainDot(this.chain, {super.key, this.size = 40, this.label});
  final Chain chain;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: chain.color, borderRadius: BorderRadius.circular(size * .3)),
        child: Text(label ?? chain.name[0], style: context.tt.titleLarge!.copyWith(color: chain.ink, fontWeight: FontWeight.w800, fontSize: size * .45)),
      );
}

class _CardsPicker extends StatelessWidget {
  const _CardsPicker();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final withCard = s.tripChains.map(chainById).whereType<Chain>().where((c) => c.card != null);
    return Column(children: [
      for (final ch in withCard)
        ChoiceRow(
          title: context.s('tripCardHave', {'card': ch.card!}),
          subtitle: ch.name,
          selected: s.cards.contains(ch.id),
          leading: const Icon(Icons.credit_card_rounded),
          onTap: () => s.toggleCard(ch.id),
        ),
    ]);
  }
}

String _ltShopName(BuildContext context, String id) =>
    switch (id) { 'rimi' => 'Rimi', 'lidl' => 'Lidl', 'iki' => 'IKI', 'norfa' => 'Norfa', 'cheapest' => context.s('tripHomeCheapest'), _ => 'Maxima' };

/// Where the shopper buys at home: savings are compared with that shop's prices.
class _LtShopPicker extends StatelessWidget {
  const _LtShopPicker({required this.onPicked});
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      for (final id in AppState.ltShops)
        ChoiceRow(
          title: _ltShopName(context, id),
          subtitle: switch (id) { 'cheapest' => context.s('tripHomeCheapestSub'), 'lidl' || 'iki' || 'norfa' => context.s('tripHomeLeafletSub'), _ => null },
          selected: s.ltShop == id,
          leading: Icon(id == 'cheapest' ? Icons.savings_rounded : Icons.storefront_rounded, color: Brand.yellow),
          onTap: () {
            s.update((x) => x.ltShop = id);
            onPicked();
          },
        ),
      const SizedBox(height: 8),
      Text(context.s('tripHomeMore'), style: context.tt.bodySmall),
    ]);
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.onPicked});
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final p = plNow();
    final days = [for (var i = 0; i < 7; i++) DateTime(p.year, p.month, p.day + i)];
    final sel = s.tripDay;
    return Column(children: [
      for (final d in days)
        if (shopsOpen(d))
          ChoiceRow(
            title: _dayLabel(context, d),
            selected: d == sel,
            leading: const Icon(Icons.event_rounded),
            onTap: () {
              s.update((x) => x.tripDate = isoDay(d));
              onPicked();
            },
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Row(children: [
              Icon(Icons.block_rounded, color: c.bad, size: 22),
              const SizedBox(width: 14),
              Expanded(child: Text('${_dayLabel(context, d)} · ${context.s('planClosedShort')}', style: context.tt.bodyLarge!.copyWith(color: c.text3))),
            ]),
          ),
    ]);
  }
}

class _CarForm extends StatelessWidget {
  const _CarForm();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Segmented<FuelType>(
        value: s.fuel,
        options: [for (final f in FuelType.values) (f, _fuelName(context, f))],
        onChanged: (v) => s.update((x) => x.fuel = v),
      ),
      const SizedBox(height: 14),
      Panel(
        child: Row(children: [
          Expanded(child: Text(context.s('consumption'), style: context.tt.titleMedium)),
          Stepper2(value: s.consumption, min: 3, max: 20, step: .1, format: (v) => '${fmtNum(v, lang)} l', onChanged: (v) => s.update((x) => x.consumption = v)),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.s('refuel'), style: context.tt.titleMedium),
          const SizedBox(height: 12),
          Stepper2(
            value: s.refuelLitres.toDouble(),
            min: 0,
            max: 90,
            step: 5,
            format: (v) => v == 0 ? context.s('refuelNone') : '${fmtNum(v, lang, digits: 0)} l',
            onChanged: (v) => s.update((x) => x.refuelLitres = v.toInt()),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('tripPeople'), style: context.tt.titleMedium),
              Text(context.s('tripPeopleSub'), style: context.tt.bodyMedium),
            ]),
          ),
          Stepper2(value: s.travellers.toDouble(), min: 1, max: 7, onChanged: (v) => s.update((x) => x.travellers = v.toInt())),
        ]),
      ),
    ]);
  }
}

/// Opens one setup question as a sheet, for changing a single thing later.
Future<void> _editSheet(BuildContext context, String title, Widget Function(VoidCallback close) body, {String? sub}) => showSheet(
      context,
      (ctx) {
        void close() => Navigator.pop(ctx);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(ctx.s(title), style: ctx.tt.headlineSmall),
            if (sub != null) ...[const SizedBox(height: 6), Text(ctx.s(sub), style: ctx.tt.bodyMedium)],
            const SizedBox(height: 16),
            body(close),
            const SizedBox(height: 8),
            BigButton(label: ctx.s('done'), icon: Icons.check_rounded, onPressed: close),
          ]),
        );
      },
    );

// ───────────────────────────── Overview

/// One stop on the route: a shop (or fuel station) and what to buy there.
class _Stop {
  _Stop(this.chain, this.store, this.items);
  final String chain;
  final Store? store;
  final List<ListItem> items;
  bool get fuel => chain == 'fuel';
}

List<_Stop> _stops(AppState s) {
  final byChain = <String, List<ListItem>>{for (final ch in s.tripChains) ch: []};
  for (final i in s.items.where((e) => !e.checked)) {
    final ch = s.chainOf(i);
    if (ch != null) byChain.putIfAbsent(ch, () => []).add(i);
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
  // The shopper's own order wins where they set one; new stops keep the nearest-next place.
  if (s.routeOrder.isNotEmpty) {
    int rank(_Stop x) {
      final i = s.routeOrder.indexOf(x.chain);
      return i < 0 ? 1000 + ordered.indexOf(x) : i;
    }
    ordered.sort((a, b) => rank(a).compareTo(rank(b)));
  }
  return ordered;
}


class _Overview extends StatelessWidget {
  const _Overview({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final day = s.tripDay;
    final law = shopDay(day);
    final lawClosed = law == ShopDay.sundayClosed || law == ShopDay.holiday;
    final stops = _stops(s);
    final shopStops = stops.where((x) => !x.fuel).toList();
    final open = s.items.where((e) => !e.checked).length;
    final r = s.rate;
    final t = TripCalc(s);
    final usable = s.deals.where(s.dealUsable).length;
    final cardsHeld = s.wallet.length;

    return RefreshIndicator(
      color: Brand.ink,
      backgroundColor: Brand.yellow,
      onRefresh: () async {
        await Future.wait([s.refreshRate(), s.refreshFeed()]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          PageHeader(context.s('tabTrip'), subtitle: '${_dayLabel(context, day)} · ${s.tripChains.map((x) => chainById(x)?.name ?? x).join(', ')}', trailing: const SettingsButton()),
          if (s.appUpdate != null) ...[const UpdateBanner(), const SizedBox(height: 12)],
          _Hero(day: day, stops: shopStops),
          if (lawClosed) ...[
            const SizedBox(height: 12),
            AlertBanner(title: context.s(law == ShopDay.holiday ? 'heroHoliday' : 'heroSunday'), body: context.s(law == ShopDay.holiday ? 'planDayHoliday' : 'planDaySunday')),
          ],
          const SizedBox(height: 12),
          const _ConvertBar(),
          SectionTitle(context.s('quickAccess')),
          RowGroup(children: [
            RowTile(
              icon: Icons.calculate_outlined,
              tone: Tone.accent,
              title: context.s('calcTitle'),
              subtitle: s.calc.isEmpty
                  ? context.s('calcRowSub')
                  : '${zl(s.calcTotal, lang)}${s.toEur(s.calcTotal) == null ? '' : ' ≈ ${eur(s.toEur(s.calcTotal)!, lang)}'} · ${context.s('calcItems', {'n': s.calcCount})}',
              onTap: () => openCalc(context),
            ),
            RowTile(
              icon: Icons.format_list_bulleted_rounded,
              tone: Tone.accent,
              title: context.s('listRowTitle'),
              subtitle: open == 0
                  ? context.s('listRowEmpty')
                  : '${context.items(open)}${t.basket.priced > 0 && r != null ? ' · ${context.s('listRowSave', {'v': eur(t.shopping, lang)})}' : ''}',
              onTap: () => shellTab.value = Tabs.list,
            ),
            RowTile(
              icon: Icons.local_gas_station_rounded,
              tone: Tone.blue,
              title: '${context.s('fuelRowTitle')} · ${_fuelName(context, s.fuel)}',
              subtitle: t.ready
                  ? 'PL ${eur(t.plFuelEur!, lang, digits: 3)}/l · LT ${eur(t.ltFuel!, lang, digits: 3)}/l${s.refuelLitres > 0 ? ' · ${eurSigned(t.refuelSaving, lang)}' : ''}'
                  : context.s('rateNone'),
              onTap: () => _fuelSheet(context),
            ),
            RowTile(
              icon: Icons.local_offer_rounded,
              tone: Tone.good,
              title: context.s('dealsRowTitle'),
              subtitle: context.s('dealsRowSub', {'n': usable}),
              onTap: () => shellTab.value = Tabs.deals,
            ),
            RowTile(
              icon: Icons.credit_card_rounded,
              title: context.s('cardsRowTitle'),
              subtitle: cardsHeld > 0
                  ? context.s('cardsRowSub', {'n': cardsHeld})
                  : s.cards.isNotEmpty
                      ? context.s('cardsRowAddCode', {'c': s.cards.map((x) => chainById(x)?.card ?? x).join(', ')})
                      : context.s('cardsRowNone'),
              onTap: () => shellTab.value = Tabs.cards,
              last: true,
            ),
          ]),
          SectionTitle(context.s('pcTitle')),
          const _PriceCheck(),
          SectionTitle(context.s('tripFactsLbl'), action: context.s('editTrip'), onAction: () => s.update((x) => x.tripReady = false)),
          const _TripFacts(),
          if (s.items.any((e) => !e.checked)) ...[
            SectionTitle(context.s('calcLbl')),
            const _Result(),
          ],
          SectionTitle(context.s('planStops', {'n': stops.length})),
          RowGroup(children: [
            for (var i = 0; i < stops.length; i++)
              _StopCard(n: i + 1, stop: stops[i], day: day, canRemove: stops[i].fuel || s.tripChains.length > 1, last: i == stops.length - 1),
          ]),
          const SizedBox(height: 10),
          Pair(
            BigButton(label: context.s('tripAddShop'), icon: Icons.add_business_rounded, kind: BtnKind.secondary, onPressed: () => _addShop(context)),
            s.refuelLitres == 0
                ? BigButton(label: context.s('tripAddFuel'), icon: Icons.local_gas_station_rounded, kind: BtnKind.secondary, onPressed: () => s.update((x) => x.refuelLitres = 40))
                : BigButton(label: context.s('planOpenMap'), icon: Icons.map_outlined, kind: BtnKind.secondary, onPressed: () => shellTab.value = Tabs.map),
          ),
          if (stops.any((x) => x.store != null)) ...[
            const SizedBox(height: 16),
            BigButton(label: context.s('routePlan'), icon: Icons.alt_route_rounded, onPressed: () => showRoute(context)),
          ],
          const SizedBox(height: 10),
          Pair(
            BigButton(
              label: context.s('planChecklistShort'),
              kind: BtnKind.secondary,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChecklistScreen())),
            ),
            BigButton(label: context.s('finishShort'), kind: BtnKind.secondary, onPressed: s.items.isEmpty ? null : () => showFinishTrip(context)),
          ),
          const SizedBox(height: 18),
          if (r != null) Text(context.s('convRate', {'r': fmtNum(r.mid, lang, digits: 4), 'd': r.date}), style: context.tt.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(context.s('estimate'), style: context.tt.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(context.s('planOsm', {'date': s.storeFeed?.generatedAt == null ? '—' : dayMonth(s.storeFeed!.generatedAt!.toLocal(), lang)}),
              style: context.tt.bodySmall!.copyWith(color: c.text3), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Latest sensible departure (LT time) for the day's shops.
({int? latest, bool late, int? opens, int? closes, int driveMin}) _leaveBy(AppState s, DateTime day, List<_Stop> stops) {
  final p = plNow();
  final isToday = day.year == p.year && day.month == p.month && day.day == p.day;
  final km = s.origin.km[s.destId] ?? 0;
  final driveMin = (km / _avgKmh * 60).round();
  final f = s.storeFeed;
  int? opens, closes;
  for (final x in stops) {
    if (x.store == null || f == null) continue;
    final h = dayHours(f.hoursOf(x.store!).hours, day);
    if (h.kind != HoursKind.open) continue;
    opens = opens == null ? h.opens : (h.opens! > opens ? h.opens : opens);
    closes = closes == null ? h.closes : (h.closes! < closes ? h.closes : closes);
  }
  final latest = closes == null ? null : closes + 60 - driveMin - _minutesPerShop * stops.length;
  final now = DateTime.now();
  final late = isToday && latest != null && now.hour * 60 + now.minute > latest;
  return (latest: latest, late: late, opens: opens, closes: closes, driveMin: driveMin);
}

/// The yellow card: when to leave, the route, and whether the trip pays off.
class _Hero extends StatelessWidget {
  const _Hero({required this.day, required this.stops});
  final DateTime day;
  final List<_Stop> stops;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final t = TripCalc(s);
    final lb = _leaveBy(s, day, stops);
    final law = shopDay(day);
    final lawClosed = law == ShopDay.sundayClosed || law == ShopDay.holiday;
    const ink = Brand.ink;
    final soft = ink.withValues(alpha: .72);
    final hasPrices = t.ready && t.basket.priced > 0;

    String leave;
    if (lawClosed) {
      leave = context.s('heroClosed');
    } else if (lb.latest == null || lb.latest! <= 0) {
      leave = '—';
    } else {
      leave = lb.late ? context.s('heroLate') : fmtMin(lb.latest!);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment(-.6, -1), end: Alignment(.6, 1), colors: [Color(0xFFF7CB4D), Brand.yellowDeep]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x29F5C43D), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('leaveBy'), style: context.tt.labelMedium!.copyWith(color: soft, fontSize: 12)),
              const SizedBox(height: 2),
              Text(leave, style: context.tt.displayMedium!.copyWith(color: ink, fontSize: 28, letterSpacing: -.85, fontFeatures: const [FontFeature.tabularFigures()])),
              if (lb.opens != null && lb.closes != null && !lawClosed)
                Text(context.s('heroHours', {'from': fmtMin(lb.opens! + 60), 'to': fmtMin(lb.closes! + 60), 'h': fmtNum(lb.driveMin / 60, lang)}),
                    style: context.tt.bodySmall!.copyWith(color: soft)),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: ink.withValues(alpha: .11), borderRadius: BorderRadius.circular(999)),
            child: Text('${s.origin.name} → ${s.dest.name}', style: context.tt.labelMedium!.copyWith(color: ink, fontSize: 12)),
          ),
        ]),
        Container(height: 1, color: ink.withValues(alpha: .12), margin: const EdgeInsets.fromLTRB(0, 14, 0, 12)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('netSaving'), style: context.tt.labelMedium!.copyWith(color: soft, fontSize: 12)),
              const SizedBox(height: 1),
              if (hasPrices)
                Text(eurSigned(t.net, lang), style: context.tt.headlineMedium!.copyWith(color: ink, fontSize: 24, fontFeatures: const [FontFeature.tabularFigures()]))
              else if (t.ready) ...[
                // No shopping prices yet: the fuel part of the trip is still known.
                Text(eurSigned(t.refuelSaving - t.tripCost, lang), style: context.tt.headlineMedium!.copyWith(color: ink, fontSize: 24, fontFeatures: const [FontFeature.tabularFigures()])),
                Text(context.s('heroFuelOnly'), style: context.tt.bodySmall!.copyWith(color: soft)),
              ] else
                Text(context.s(s.items.any((e) => !e.checked) ? 'heroNoPrices' : 'heroNoItems'), style: context.tt.titleMedium!.copyWith(color: ink)),
              if (hasPrices && s.travellers > 1) Text(context.s('resultPerPerson', {'v': eur(t.net / s.travellers, lang)}), style: context.tt.bodySmall!.copyWith(color: soft)),
            ]),
          ),
          if (hasPrices && t.breakEven != null && t.breakEven! > 0)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(context.s('breakevenLbl'), style: context.tt.bodySmall!.copyWith(color: ink.withValues(alpha: .78))),
              Text(context.s('breakevenVal', {'v': eur(t.breakEven!, lang, digits: 0)}), style: context.tt.labelMedium!.copyWith(color: ink, fontWeight: FontWeight.w700)),
            ])
          else if (!hasPrices)
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddItemScreen(), fullscreenDialog: true)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(10)),
                child: Text('+ ${context.s('listAdd')}', style: context.tt.labelMedium!.copyWith(color: Brand.yellow)),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Type a price in złoty, see it in euro (NBP rate plus the card fee).
class _ConvertBar extends StatefulWidget {
  const _ConvertBar();

  @override
  State<_ConvertBar> createState() => _ConvertBarState();
}

class _ConvertBarState extends State<_ConvertBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.').trim());
    final e = v == null ? null : s.toEur(v);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: context.tt.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            decoration: InputDecoration(
              isDense: true,
              hintText: context.s('convHint'),
              fillColor: c.raised,
              suffixText: 'zł',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.line)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 96),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(e == null ? eur(0, lang) : eur(e, lang), style: context.tt.titleLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            Text(s.rate == null ? '—' : '1 € = ${fmtNum(s.rate!.mid, lang, digits: 2)} zł', style: context.tt.bodySmall!.copyWith(fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

Future<void> _addShop(BuildContext context) => showSheet(context, (ctx) {
      final s = AppScope.of(ctx);
      final here = s.chainsInTown;
      final left = chains.where((c) => (here.isEmpty || here.contains(c.id)) && !s.tripChains.contains(c.id)).toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.s('tripAddShopTitle'), style: ctx.tt.headlineSmall),
          const SizedBox(height: 14),
          if (left.isEmpty) Text(ctx.s('tripAddShopNone'), style: ctx.tt.bodyLarge),
          for (final ch in left)
            ChoiceRow(
              title: ch.name,
              subtitle: ctx.s('tripShopCount', {'n': s.storeFeed?.inTown(s.destId, ch.id).length ?? 0}),
              selected: false,
              leading: ChainDot(ch),
              onTap: () {
                s.addTripChain(ch.id);
                Navigator.pop(ctx);
              },
            ),
        ]),
      );
    });

/// Where, when, which car, which cards — each row opens just that question.
class _TripFacts extends StatelessWidget {
  const _TripFacts();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final cardChains = s.tripChains.map(chainById).whereType<Chain>().where((x) => x.card != null).toList();
    final held = cardChains.where((x) => s.cards.contains(x.id)).map((x) => x.card!).toList();
    final dayOpen = shopsOpen(s.tripDay);

    return RowGroup(children: [
      RowTile(
        title: context.s('tripRouteRow'),
        subtitle: '${s.origin.name} → ${s.dest.name} · ${context.s('kmRound', {'km': (s.origin.km[s.destId] ?? 0) * 2})}',
        onTap: () => _editSheet(context, 'tripRouteRow', (close) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('tripFromRow'), style: context.tt.titleMedium),
              const SizedBox(height: 8),
              const _FromChips(),
              const SizedBox(height: 18),
              Text(context.s('tripTo'), style: context.tt.titleMedium),
              const SizedBox(height: 8),
              _DestPicker(onPicked: close),
            ])),
      ),
      RowTile(
        title: context.s('tripShopsRow'),
        subtitle: s.tripChains.map((x) => chainById(x)?.name ?? x).join(', '),
        onTap: () => _editSheet(context, 'tripShopsRow', (_) => const _ShopsPicker()),
      ),
      RowTile(
        title: context.s('tripDayRow'),
        subtitle: _dayLabel(context, s.tripDay),
        subtitleColor: dayOpen ? null : c.bad,
        onTap: () => _editSheet(context, 'tripDay', (close) => _DayPicker(onPicked: close), sub: 'tripDaySub'),
      ),
      RowTile(
        title: context.s('tripCarRow'),
        subtitle: context.s('tripCarVal', {'fuel': _fuelName(context, s.fuel), 'c': fmtNum(s.consumption, lang)}) +
            (s.refuelLitres > 0 ? ' · ${context.s('refuelL', {'l': s.refuelLitres})}' : '') +
            (s.travellers > 1 ? context.s('tripCarPeople', {'n': s.travellers}) : ''),
        onTap: () => _editSheet(context, 'tripCar', (_) => const _CarForm()),
      ),
      RowTile(
        title: context.s('tripHomeRow'),
        subtitle: _ltShopName(context, s.ltShop),
        onTap: () => _editSheet(context, 'tripHome', (close) => _LtShopPicker(onPicked: close), sub: 'tripHomeSub'),
        last: cardChains.isEmpty,
      ),
      if (cardChains.isNotEmpty)
        RowTile(
          title: context.s('tripCardsRow'),
          subtitle: held.isEmpty ? context.s('tripCardsNone') : held.join(', '),
          onTap: () => _editSheet(context, 'tripCards', (_) => const _CardsPicker(), sub: 'tripCardsSub'),
          last: true,
        ),
    ]);
  }
}

/// How the net number is made: shopping, fuel there and back, refuelling in Poland.
class _Result extends StatelessWidget {
  const _Result();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final t = TripCalc(s);
    final open = s.items.where((e) => !e.checked).toList();
    if (open.isEmpty) return const SizedBox.shrink();

    var pln = 0.0;
    var unknown = 0;
    for (final i in open) {
      final p = s.plFor(i);
      if (p == null) {
        unknown++;
      } else {
        pln += p.price * i.qty;
      }
    }
    final plEur = s.toEur(pln);
    if (s.rate == null || !t.ready) return AlertBanner(title: context.s('rateNone'), tone: Tone.warn);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RowGroup(children: [
        RowTile(
          icon: Icons.shopping_bag_outlined,
          tone: Tone.good,
          title: context.s('rowShopping'),
          subtitle: context.s('tripPriced', {'n': t.basket.priced, 'm': open.length}),
          trailing: Text(eurSigned(t.shopping, lang), style: context.tt.titleMedium!.copyWith(color: c.good, fontWeight: FontWeight.w700)),
          onTap: () => shellTab.value = Tabs.list,
        ),
        RowTile(
          icon: Icons.route_rounded,
          tone: Tone.bad,
          title: context.s('rowFuelTrip'),
          subtitle: '${t.km} km · ${fmtNum(t.litres, lang)} l × ${eur(t.ltFuel!, lang, digits: 3)}',
          trailing: Text(eurSigned(-t.tripCost, lang), style: context.tt.titleMedium!.copyWith(color: c.bad, fontWeight: FontWeight.w700)),
          onTap: () => _fuelSheet(context),
        ),
        if (s.refuelLitres > 0)
          RowTile(
            icon: Icons.local_gas_station_outlined,
            tone: Tone.blue,
            title: context.s('rowRefuel'),
            subtitle: '${s.refuelLitres} l × ${eur(t.plFuelEur!, lang, digits: 3)}',
            trailing: Text(eurSigned(t.refuelSaving, lang),
                style: context.tt.titleMedium!.copyWith(color: t.refuelSaving >= 0 ? c.good : c.bad, fontWeight: FontWeight.w700)),
            onTap: () => _fuelSheet(context),
          ),
        RowTile(
          title: context.s('rowTotal'),
          trailing: Text(eurSigned(t.net, lang), style: context.tt.titleLarge!.copyWith(color: t.net >= 0 ? c.good : c.bad)),
          last: true,
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(
          [
            context.s('tripSpend', {'v': '${zl(pln, lang)}${plEur == null ? '' : ' ≈ ${eur(plEur, lang)}'}'}),
            if (unknown > 0) context.s('planUnknown', {'n': unknown}),
          ].join(' · '),
          style: context.tt.bodySmall,
        ),
      ),
    ]);
  }
}

Future<void> _fuelSheet(BuildContext context) => showSheet(context, (ctx) {
      final s = AppScope.of(ctx);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.s('tripFuel'), style: ctx.tt.headlineSmall),
          const SizedBox(height: 6),
          Text(ctx.s('tripFuelSub'), style: ctx.tt.bodyMedium),
          const SizedBox(height: 16),
          _PriceField(
            key: ValueKey('lt-${s.fuel.name}'),
            label: '${ctx.s('fuelLt')} · ${_fuelName(ctx, s.fuel)}',
            suffix: '€',
            value: s.ltFuelPrice,
            auto: s.autoLtFuel,
            autoSource: s.autoLtSource,
            onChanged: (v) => s.update((x) => x.ltFuelPrice = v),
          ),
          if (s.autoLtFuel == null) _SourceLink(text: ctx.s('srcLt'), url: 'https://degalukainos.ena.lt/'),
          const SizedBox(height: 18),
          _PriceField(
            key: ValueKey('pl-${s.fuel.name}'),
            label: '${ctx.s('fuelPl')} · ${_fuelName(ctx, s.fuel)}',
            suffix: 'zł',
            value: s.plFuelPrice,
            auto: s.autoPlFuel,
            autoSource: s.plFuelIsCap ? null : s.autoPlSource,
            onChanged: (v) => s.update((x) => x.plFuelPrice = v),
          ),
          if (s.plCap != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.gavel_rounded, size: 18, color: ctx.c.good),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ctx.s('fuelCapNote', {
                      'v': fmtNum(s.plCap!, ctx.lang, digits: 2),
                      'date': DateTime.tryParse(s.fuelFeed!.plCap!.date) == null ? s.fuelFeed!.plCap!.date : dayMonth(DateTime.parse(s.fuelFeed!.plCap!.date), ctx.lang),
                    }),
                    style: ctx.tt.bodyMedium!.copyWith(color: ctx.c.text2),
                  ),
                ),
              ]),
            ),
          if (s.autoPlFuel == null) _SourceLink(text: ctx.s('srcPl'), url: 'https://www.e-petrol.pl/notowania/rynek-krajowy/ceny-stacje-paliw'),
          const SizedBox(height: 18),
          BigButton(label: ctx.s('done'), icon: Icons.check_rounded, onPressed: () => Navigator.pop(ctx)),
        ]),
      );
    });

class _StopCard extends StatelessWidget {
  const _StopCard({required this.n, required this.stop, required this.day, required this.canRemove, this.last = false});
  final int n;
  final _Stop stop;
  final DateTime day;
  final bool canRemove, last;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final fuel = stop.fuel;
    final chain = chainById(stop.chain);
    final st = stop.store;
    final title = fuel ? '${context.s('planFuel')} · ${st?.brand ?? ''}' : (chain?.name ?? stop.chain);
    var sub = 0.0;
    var unknown = 0;
    for (final i in stop.items) {
      final p = s.plFor(i)?.price;
      if (p == null) {
        unknown++;
      } else {
        sub += p * i.qty;
      }
    }

    Widget mini(String label, IconData icon, VoidCallback onTap) => Expanded(
          child: Press(
            onTap: onTap,
            scale: .96,
            child: Container(
              height: 34,
              decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.line)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 15, color: c.text2),
                const SizedBox(width: 6),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: context.tt.labelMedium!.copyWith(color: c.text))),
              ]),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fuel ? c.blueSoft : c.raised, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.line)),
              child: fuel
                  ? Icon(Icons.local_gas_station_rounded, size: 14, color: c.blue)
                  : Text('$n', style: context.tt.labelSmall!.copyWith(color: c.text, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (chain != null && !fuel) ...[Dot(chain.color), const SizedBox(width: 7)],
                  Flexible(child: Text(title, style: context.tt.titleMedium)),
                ]),
                if (st == null)
                  Text(context.s('planNoShop', {'town': s.dest.name}), style: context.tt.bodySmall!.copyWith(color: c.warn))
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(st.address ?? st.name ?? context.s('planNoAddress'), style: context.tt.bodySmall!.copyWith(color: c.text2, fontSize: 12.5)),
                  ),
                if (st != null) Padding(padding: const EdgeInsets.only(top: 6), child: _HoursPill(store: st, day: day)),
                const SizedBox(height: 6),
                if (fuel)
                  Text(context.s('planFuelLitres', {'l': s.refuelLitres}), style: context.tt.bodySmall!.copyWith(color: c.text2))
                else
                  GestureDetector(
                    onTap: () => shellTab.value = Tabs.list,
                    child: Text(
                      stop.items.isEmpty
                          ? context.s('tripStopNoItems')
                          : context.s('tripStopItems', {'items': context.items(stop.items.length), 'v': '${unknown > 0 ? '≥ ' : ''}${zl(sub, lang)}'}),
                      style: context.tt.bodySmall!.copyWith(color: stop.items.isEmpty ? c.text3 : c.text, fontWeight: FontWeight.w600),
                    ),
                  ),
              ]),
            ),
            if (canRemove)
              GestureDetector(
                onTap: () => fuel ? s.update((x) => x.refuelLitres = 0) : s.toggleTripChain(stop.chain),
                child: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.close_rounded, size: 18, color: c.text3)),
              ),
          ]),
          if (st != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Row(children: [
                mini('Waze', Icons.navigation_outlined, () => _open(_waze(st))),
                const SizedBox(width: 8),
                mini('Maps', Icons.map_outlined, () => _open(_gmaps(st))),
                if ((s.storeFeed?.inTown(s.destId, stop.chain).length ?? 0) > 1) ...[
                  const SizedBox(width: 8),
                  mini(context.s('planOtherShopShort'), Icons.swap_horiz_rounded, () => _pickStore(context, stop.chain)),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _HoursPill extends StatelessWidget {
  const _HoursPill({required this.store, required this.day});
  final Store store;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final p = plNow();
    final isToday = day.year == p.year && day.month == p.month && day.day == p.day;
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

Future<void> _pickStore(BuildContext context, String chain) => showSheet(context, (_) => _StorePicker(chain: chain));

/// Which shop of a chain: a small map with numbered pins plus the same list underneath.
/// Tap a pin to see it, tap again (or the row) to choose it.
class _StorePicker extends StatefulWidget {
  const _StorePicker({required this.chain});
  final String chain;

  @override
  State<_StorePicker> createState() => _StorePickerState();
}

class _StorePickerState extends State<_StorePicker> {
  final _map = MapController();
  String? _focus;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final f = s.storeFeed!;
    final list = f.inTown(s.destId, widget.chain);
    final current = s.storeFor(widget.chain);
    final day = s.tripDay;
    final ch = chainById(widget.chain);
    final focus = _focus ?? current?.id;
    if (list.isEmpty) {
      return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: Text(context.s('planNoShop', {'town': s.dest.name}), style: context.tt.bodyLarge));
    }
    final pts = [for (final st in list) LatLng(st.lat, st.lon)];
    final bounds = LatLngBounds.fromPoints(pts.length == 1 ? [pts.first, LatLng(pts.first.latitude + .004, pts.first.longitude + .004)] : pts);

    void choose(Store st) {
      s.chooseStore(widget.chain, st.id);
      Navigator.pop(context);
    }

    String sub(Store st) {
      final h = dayHours(f.hoursOf(st).hours, day, fuel: st.isFuel);
      final brand = widget.chain == 'fuel' ? '${st.brand} · ' : '';
      final hrs = h.kind == HoursKind.open ? h.spans.join(', ') : context.s(h.kind == HoursKind.unknown ? 'hoursUnknown' : 'hoursClosed');
      return '$brand$hrs';
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
        child: Text(widget.chain == 'fuel' ? context.s('planFuel') : ch?.name ?? widget.chain, style: context.tt.headlineSmall),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 12), child: Text(context.s('pickStoreSub'), style: context.tt.bodyMedium)),
      Container(
        height: 240,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36)),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            osmTiles(context),
            MarkerLayer(markers: [
              for (var i = 0; i < list.length; i++)
                Marker(
                  point: pts[i],
                  width: list[i].id == focus ? 38 : 30,
                  height: list[i].id == focus ? 38 : 30,
                  child: GestureDetector(
                    onTap: () => list[i].id == _focus ? choose(list[i]) : setState(() => _focus = list[i].id),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: list[i].id == focus ? Brand.yellow : (widget.chain == 'fuel' ? const Color(0xFF1F2430) : ch?.color ?? Brand.ink3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 1))],
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 13, color: list[i].id == focus ? Brand.ink : (ch?.ink ?? Colors.white))),
                    ),
                  ),
                ),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            for (var i = 0; i < list.length; i++)
              ChoiceRow(
                title: '${i + 1}. ${list[i].address ?? list[i].name ?? context.s('planNoAddress')}',
                subtitle: sub(list[i]),
                selected: list[i].id == current?.id,
                onTap: () => choose(list[i]),
              ),
          ],
        ),
      ),
    ]);
  }
}

class _PriceField extends StatefulWidget {
  const _PriceField({super.key, required this.label, required this.suffix, required this.value, required this.onChanged, this.auto, this.autoSource});
  final String label, suffix;
  final double? value; // typed by the user
  final double? auto; // published average, used when nothing is typed
  final FuelPrice? autoSource;
  final ValueChanged<double?> onChanged;

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  static String _fmt(double? v) => v?.toStringAsFixed(3).replaceAll('.', ',') ?? '';
  late final _c = TextEditingController(text: _fmt(widget.value ?? widget.auto));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Leaving the field empty falls back to the published average; show it again.
    _focus.addListener(() {
      if (!_focus.hasFocus && widget.value == null) _c.text = _fmt(widget.auto);
    });
  }

  @override
  void didUpdateWidget(covariant _PriceField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value == null && old.auto != widget.auto) _c.text = _fmt(widget.auto);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final src = widget.autoSource;
    final usingAuto = widget.value == null && widget.auto != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: context.tt.titleMedium),
      const SizedBox(height: 8),
      TextField(
        controller: _c,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: context.tt.headlineSmall,
        decoration: InputDecoration(
          hintText: widget.suffix == '€' ? '1,749' : '5,99',
          suffixIcon: Padding(padding: const EdgeInsets.only(right: 18), child: Text(widget.suffix, style: context.tt.titleLarge!.copyWith(color: context.c.text3))),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        onChanged: (v) {
          final p = parseAmount(v);
          // Typing the average back is the same as using the average.
          widget.onChanged(p != null && widget.auto != null && (p - widget.auto!).abs() < 0.0005 ? null : p);
        },
      ),
      if (src != null) ...[
        const SizedBox(height: 8),
        if (usingAuto)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: context.c.good),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.s(src.region != null ? 'fuelAutoRegion' : 'fuelAuto', {
                  'src': src.source == 'EU Weekly Oil Bulletin' ? context.s('srcEuBulletin') : src.source,
                  'date': DateTime.tryParse(src.date) == null ? src.date : dayMonth(DateTime.parse(src.date), context.lang),
                  'region': src.region ?? '',
                }) +
                    (src.currency == 'EUR' && widget.suffix == 'zł' ? context.s('fuelAutoConverted') : ''),
                style: context.tt.bodyMedium!.copyWith(color: context.c.text2),
              ),
            ),
          ])
        else
          TextButton.icon(
            onPressed: () {
              _c.text = _fmt(widget.auto);
              widget.onChanged(null);
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
            label: Text(context.s('fuelUseAuto', {'v': '${_fmt(widget.auto)} ${widget.suffix}'})),
          ),
      ],
    ]);
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.text, required this.url});
  final String text, url;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(text, style: context.tt.bodyMedium!.copyWith(decoration: TextDecoration.underline)),
        ),
      );
}


/// "How much is it?": one word in, the price at your shops and what you save, right away.
class _PriceCheck extends StatefulWidget {
  const _PriceCheck();

  @override
  State<_PriceCheck> createState() => _PriceCheckState();
}

class _PriceCheckState extends State<_PriceCheck> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final q = _q.text.trim();

    // Dictionary words ("sviestas" → Masło), then brand / free-text matches in this trip's deals.
    final rows = <({String title, String? pl, Deal? deal, ListItem probe})>[];
    if (q.length >= 2) {
      for (final t in searchTerms(q).take(3)) {
        final probe = ListItem(id: '', name: lang == Lang.lt ? t.lt : t.en, plName: t.pl);
        rows.add((title: probe.name, pl: t.pl, deal: s.dealOf(probe), probe: probe));
      }
      if (q.length >= 3) {
        final seen = rows.map((r) => r.deal?.id).toSet();
        for (final d in matchLoose(q, s.deals.where(s.dealUsable)).where((d) => !seen.contains(d.id)).take(3)) {
          rows.add((title: dealName(context, d), pl: null, deal: d, probe: ListItem(id: '', name: dealName(context, d), plName: d.name, dealId: d.id)));
        }
      }
    }

    Widget row(({String title, String? pl, Deal? deal, ListItem probe}) r) {
      final pl = s.plFor(r.probe);
      final lt = s.ltFor(r.probe);
      final saving = s.itemSaving(r.probe);
      final shop = s.chainOf(r.probe);
      final shopName = shop == null ? '' : chainById(shop)?.name ?? shop;
      final plEur = pl == null ? null : s.toEur(pl.price);
      final good = (saving ?? 0) > 0.009;
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: context.tt.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (pl == null)
                Text(context.s('pcNone', {'shop': shopName}), style: context.tt.bodyMedium!.copyWith(color: c.text3))
              else ...[
                Text(
                  '$shopName: ${pl.kind == PriceKind.deal ? '' : '≈ '}${zl(pl.price, lang)}${plEur == null ? '' : ' ≈ ${eur(plEur, lang)}'}'
                  '${r.deal?.card == true ? ' · ${chainById(r.deal!.chain)?.card ?? ''}' : ''}',
                  style: context.tt.bodyLarge,
                ),
                if (lt != null)
                  Text(
                    saving == null
                        ? context.s('pcLt', {'v': eur(lt.price, lang)})
                        : context.s(good ? 'pcSave' : 'pcNoSave', {'v': eur(lt.price, lang), 's': eur(saving.abs(), lang)}),
                    style: context.tt.bodyMedium!.copyWith(color: saving == null ? c.text2 : good ? c.good : c.bad),
                  ),
              ],
            ]),
          ),
          IconButton(
            tooltip: context.s('listAdd'),
            icon: const Icon(Icons.add_circle_rounded, color: Brand.yellow, size: 30),
            onPressed: () {
              s.addItem(ListItem(id: newId(), name: r.title, plName: r.pl ?? r.deal?.name, dealId: r.pl == null ? r.deal?.id : null));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s('addAdded', {'name': r.title})), duration: const Duration(seconds: 2)));
            },
          ),
        ]),
      );
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.s('pcTitle'), style: context.tt.titleLarge),
        const SizedBox(height: 10),
        TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          style: context.tt.titleMedium,
          decoration: InputDecoration(
            hintText: context.s('pcHint'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(_q.clear)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (q.length >= 2 && rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(context.s('pcNothing'), style: context.tt.bodyMedium)),
        for (final r in rows) row(r),
      ]),
    );
  }
}


// ───────────────────────────── Route planner

String _navUrl(String app, double lat, double lon) => switch (app) {
      'waze' => 'https://waze.com/ul?ll=$lat,$lon&navigate=yes',
      'apple' => 'https://maps.apple.com/?daddr=$lat,$lon&dirflg=d',
      _ => 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    };

/// The day's drive: home → shops in order → fuel → home. Google Maps takes the whole
/// route at once; Waze and Apple Maps go stop by stop ("next stop").
Future<void> showRoute(BuildContext context) => showSheet(context, (_) => const _RouteSheet());

class _RouteSheet extends StatelessWidget {
  const _RouteSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final all = _stops(s).where((x) => x.store != null).toList();
    final left = all.where((x) => !s.routeDone.contains(x.chain)).toList();
    final next = left.isEmpty ? null : left.first;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final km = s.origin.km[s.destId] ?? 0;

    void move(int i, int d) => s.update((x) {
          final ids = all.map((e) => e.chain).toList();
          final j = i + d;
          if (j < 0 || j >= ids.length) return;
          final t = ids[i];
          ids[i] = ids[j];
          ids[j] = t;
          x.routeOrder
            ..clear()
            ..addAll(ids);
        });

    String allUrl() {
      final pts = [for (final x in left) '${x.store!.lat},${x.store!.lon}'];
      final home = Uri.encodeComponent('${s.origin.name}, Lithuania');
      if (pts.isEmpty) return 'https://www.google.com/maps/dir/?api=1&destination=$home&travelmode=driving';
      return 'https://www.google.com/maps/dir/?api=1&destination=$home'
          '&waypoints=${Uri.encodeComponent(pts.take(9).join('|'))}&travelmode=driving';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.s('routeTitle'), style: context.tt.headlineSmall),
        const SizedBox(height: 4),
        Text(context.s('routeSub', {'n': all.length, 'km': km * 2, 'h': fmtNum(km * 2 / _avgKmh, lang)}), style: context.tt.bodyMedium),
        const SizedBox(height: 14),
        Segmented<String>(
          value: s.navApp,
          options: [('gmaps', 'Google Maps'), ('waze', 'Waze'), if (ios) ('apple', 'Apple')],
          onChanged: (v) => s.update((x) => x.navApp = v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(context.s(s.navApp == 'gmaps' ? 'routeGmapsHint' : 'routeStepHint'), style: context.tt.bodySmall),
        ),
        SectionTitle(context.s('routeOrder'), top: 18, action: s.routeOrder.isEmpty && s.routeDone.isEmpty ? null : context.s('routeReset'),
            onAction: () => s.update((x) {
                  x.routeOrder.clear();
                  x.routeDone.clear();
                })),
        RowGroup(children: [
          RowTile(icon: Icons.home_outlined, title: s.origin.name, subtitle: context.s('routeStart')),
          for (var i = 0; i < all.length; i++)
            Builder(builder: (context) {
              final x = all[i];
              final done = s.routeDone.contains(x.chain);
              final ch = chainById(x.chain);
              final h = dayHours(s.storeFeed!.hoursOf(x.store!).hours, s.tripDay, fuel: x.fuel);
              final hours = h.kind == HoursKind.open ? h.spans.join(', ') : context.s(h.kind == HoursKind.unknown ? 'hoursUnknown' : 'hoursClosed');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => s.update((y) => done ? y.routeDone.remove(x.chain) : y.routeDone.add(x.chain)),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done ? c.good : (x.fuel ? c.blueSoft : c.raised),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: done ? c.good : c.line),
                        ),
                        child: done
                            ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF08120D))
                            : x.fuel
                                ? Icon(Icons.local_gas_station_rounded, size: 15, color: c.blue)
                                : Text('${i + 1}', style: context.tt.labelSmall!.copyWith(color: c.text, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: GestureDetector(
                       behavior: HitTestBehavior.opaque,
                       onTap: () => _pickStore(context, x.chain),
                       child: Opacity(
                        opacity: done ? .45 : 1,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            if (ch != null && !x.fuel) ...[Dot(ch.color), const SizedBox(width: 6)],
                            Flexible(child: Text(x.fuel ? '${context.s('planFuel')} · ${x.store!.brand}' : (ch?.name ?? x.chain), style: context.tt.titleMedium)),
                          ]),
                          Text('${x.store!.address ?? x.store!.name ?? ''} · $hours', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall!.copyWith(color: c.text2)),
                        ]),
                      ),
                     ),
                    ),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: i == 0 ? null : () => move(i, -1), icon: const Icon(Icons.keyboard_arrow_up_rounded)),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: i == all.length - 1 ? null : () => move(i, 1), icon: const Icon(Icons.keyboard_arrow_down_rounded)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.s('routeGoHere'),
                      onPressed: () => _open(_navUrl(s.navApp, x.store!.lat, x.store!.lon)),
                      icon: Icon(Icons.navigation_outlined, color: c.accentText),
                    ),
                  ]),
                ),
              );
            }),
          RowTile(icon: Icons.home_outlined, title: s.origin.name, subtitle: context.s('routeEnd'), last: true),
        ]),
        const SizedBox(height: 16),
        if (s.navApp == 'gmaps')
          BigButton(label: context.s(left.length == all.length ? 'routeStartAll' : 'routeContinue', {'n': left.length}), icon: Icons.navigation_rounded, onPressed: () => _open(allUrl()))
        else if (next != null)
          BigButton(
            label: context.s('routeNext', {'name': next.fuel ? context.s('planFuel') : (chainById(next.chain)?.name ?? next.chain)}),
            icon: Icons.navigation_rounded,
            onPressed: () => _open(_navUrl(s.navApp, next.store!.lat, next.store!.lon)),
          )
        else
          BigButton(
            label: context.s('routeHome', {'city': s.origin.name}),
            icon: Icons.home_rounded,
            onPressed: () => _open(_navUrl(s.navApp, s.origin.lat, s.origin.lon)),
          ),
        if (s.navApp != 'gmaps' && next != null) ...[
          const SizedBox(height: 8),
          BigButton(label: context.s('routeArrived'), icon: Icons.check_rounded, kind: BtnKind.secondary, onPressed: () => s.update((x) => x.routeDone.add(next.chain))),
        ],
        const SizedBox(height: 10),
        Text(context.s('routeOrderHint'), style: context.tt.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}
