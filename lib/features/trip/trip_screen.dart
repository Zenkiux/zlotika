import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/hours.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/calendar.dart';
import '../../data/chains.dart';
import '../../data/geo.dart';
import '../../main.dart';
import '../../services/fuel.dart';
import '../../services/stores.dart';
import '../../widgets/ui.dart';
import '../history/history_screen.dart';
import '../list/add_item_screen.dart';
import '../list/deal_pick.dart' show shortDealName;
import '../../data/dictionary.dart';
import '../../services/deals.dart';
import '../../services/match.dart';
import '../plan/checklist_screen.dart';

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

enum _Q { from, to, shops, cards, day, car }

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
              _Q.day => [_title(context, 'tripDay', 'tripDaySub'), _DayPicker(onPicked: next)],
              _Q.car => [_title(context, 'tripCar'), const _CarForm()],
            },
          ),
        ),
      ),
      if (q != _Q.from && q != _Q.to && q != _Q.day)
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
  return ordered;
}

String _routeUrl(AppState s, List<_Stop> stops) {
  final pts = [for (final x in stops) if (x.store != null) '${x.store!.lat},${x.store!.lon}'].take(9).join('|');
  final home = Uri.encodeComponent('${s.origin.name}, Lithuania');
  return 'https://www.google.com/maps/dir/?api=1&origin=$home&destination=$home'
      '${pts.isEmpty ? '' : '&waypoints=${Uri.encodeComponent(pts)}'}&travelmode=driving';
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

    return RefreshIndicator(
      color: Brand.ink,
      backgroundColor: Brand.yellow,
      onRefresh: () async {
        await Future.wait([s.refreshRate(), s.refreshFeed()]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Row(children: [
            const LogoMark(size: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(context.s('tripHeader'), style: context.tt.headlineMedium)),
          ]),
          const SizedBox(height: 16),
          const _PriceCheck(),
          const SizedBox(height: 12),
          const _TripFacts(),
          const SizedBox(height: 12),
          if (lawClosed) ...[
            Panel(
              color: c.badSoft,
              child: Row(children: [
                Icon(Icons.block_rounded, color: c.bad, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(context.s(law == ShopDay.holiday ? 'planDayHoliday' : 'planDaySunday'), style: context.tt.bodyLarge)),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          const _Result(),
          SectionTitle(context.s('planStops', {'n': stops.length})),
          for (var i = 0; i < stops.length; i++) _StopCard(n: i + 1, stop: stops[i], day: day, canRemove: stops[i].fuel || s.tripChains.length > 1),
          Row(children: [
            Expanded(child: BigButton(label: context.s('tripAddShop'), icon: Icons.add_business_rounded, kind: BtnKind.secondary, onPressed: () => _addShop(context))),
            if (s.refuelLitres == 0) ...[
              const SizedBox(width: 10),
              Expanded(
                child: BigButton(
                  label: context.s('tripAddFuel'),
                  icon: Icons.local_gas_station_rounded,
                  kind: BtnKind.secondary,
                  onPressed: () => s.update((x) => x.refuelLitres = 40),
                ),
              ),
            ],
          ]),
          if (!lawClosed) ...[
            const SizedBox(height: 12),
            _Timing(day: day, stops: shopStops),
          ],
          const SizedBox(height: 20),
          if (stops.any((x) => x.store != null)) ...[
            BigButton(label: context.s('planRoute'), icon: Icons.alt_route_rounded, onPressed: () => _open(_routeUrl(s, stops))),
            const SizedBox(height: 10),
          ],
          BigButton(
            label: context.s('tripList', {'n': open}),
            icon: Icons.shopping_bag_rounded,
            kind: BtnKind.secondary,
            onPressed: () => shellTab.value = 1,
          ),
          const SizedBox(height: 10),
          BigButton(
            label: context.s('planChecklist'),
            icon: Icons.fact_check_rounded,
            kind: BtnKind.secondary,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChecklistScreen())),
          ),
          if (s.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            BigButton(label: context.s('finishOpen'), icon: Icons.flag_rounded, kind: BtnKind.secondary, onPressed: () => showFinishTrip(context)),
          ],
          const SizedBox(height: 18),
          if (r != null) Text(context.s('convRate', {'r': fmtNum(r.mid, lang, digits: 4), 'd': r.date}), style: context.tt.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(context.s('estimate'), style: context.tt.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(context.s('planOsm', {'date': s.storeFeed?.generatedAt == null ? '—' : dayMonth(s.storeFeed!.generatedAt!.toLocal(), lang)}),
              style: context.tt.bodySmall, textAlign: TextAlign.center),
        ],
      ),
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

/// Where, when, which car, which cards — each line opens just that question.
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

    Widget row(IconData icon, String label, String value, VoidCallback onTap, {Color? color}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Row(children: [
              Icon(icon, size: 24, color: color ?? c.text2),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: context.tt.bodySmall),
                  Text(value, style: context.tt.titleMedium!.copyWith(color: color)),
                ]),
              ),
              Icon(Icons.edit_rounded, size: 20, color: c.text3),
            ]),
          ),
        );

    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(children: [
        row(Icons.route_rounded, context.s('tripRouteRow'), '${s.origin.name} → ${s.dest.name} · ${s.origin.km[s.destId] ?? '?'} km', () {
          _editSheet(context, 'tripRouteRow', (close) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.s('tripFromRow'), style: context.tt.titleMedium),
                const SizedBox(height: 8),
                const _FromChips(),
                const SizedBox(height: 18),
                Text(context.s('tripTo'), style: context.tt.titleMedium),
                const SizedBox(height: 8),
                _DestPicker(onPicked: close),
              ]));
        }),
        Divider(color: c.line, height: 1),
        row(Icons.event_rounded, context.s('tripDayRow'), _dayLabel(context, s.tripDay), () {
          _editSheet(context, 'tripDay', (close) => _DayPicker(onPicked: close), sub: 'tripDaySub');
        }, color: dayOpen ? null : c.bad),
        Divider(color: c.line, height: 1),
        row(
          Icons.directions_car_rounded,
          context.s('tripCarRow'),
          context.s('tripCarVal', {'fuel': _fuelName(context, s.fuel), 'c': fmtNum(s.consumption, lang)}) +
              (s.travellers > 1 ? context.s('tripCarPeople', {'n': s.travellers}) : ''),
          () => _editSheet(context, 'tripCar', (_) => const _CarForm()),
        ),
        if (cardChains.isNotEmpty) ...[
          Divider(color: c.line, height: 1),
          row(Icons.credit_card_rounded, context.s('tripCardsRow'), held.isEmpty ? context.s('tripCardsNone') : held.join(', '),
              () => _editSheet(context, 'tripCards', (_) => const _CardsPicker(), sub: 'tripCardsSub')),
        ],
      ]),
    );
  }
}

/// The answer: is it worth it, and how the number is made.
class _Result extends StatelessWidget {
  const _Result();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final t = TripCalc(s);
    final shops = s.tripChains.map((x) => chainById(x)?.name ?? x).join(', ');
    final open = s.items.where((e) => !e.checked).toList();

    if (open.isEmpty) {
      return Panel(
        color: Brand.yellow,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.s('tripNoItems'), style: context.tt.headlineSmall!.copyWith(color: Brand.ink)),
          const SizedBox(height: 6),
          Text(context.s('tripNoItemsSub', {'shops': shops}), style: context.tt.bodyLarge!.copyWith(color: Brand.ink.withValues(alpha: .8))),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Brand.ink, foregroundColor: Brand.yellow, minimumSize: const Size.fromHeight(56)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddItemScreen(), fullscreenDialog: true)),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.s('listAdd'), style: context.tt.titleMedium!.copyWith(color: Brand.yellow)),
          ),
        ]),
      );
    }

    // Spend in Poland, from the trip's shops only.
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

    if (s.rate == null || !t.ready) {
      return Panel(color: c.warnSoft, child: Text(context.s('rateNone'), style: context.tt.bodyLarge));
    }

    final verdict = t.basket.priced == 0 ? null : t.net >= 15 ? 'Worth' : t.net >= 0 ? 'Marginal' : 'Not';
    final (vColor, vBg, vIcon) = switch (verdict) {
      'Worth' => (c.good, c.goodSoft, Icons.check_circle_rounded),
      'Marginal' => (c.warn, c.warnSoft, Icons.help_rounded),
      'Not' => (c.bad, c.badSoft, Icons.cancel_rounded),
      _ => (c.text2, c.raised, Icons.info_rounded),
    };

    Widget row(IconData icon, String label, String? sub, String value, {Color? color, VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: c.text2, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: context.tt.titleMedium),
                  if (sub != null) Text(sub, style: context.tt.bodyMedium),
                ]),
              ),
              const SizedBox(width: 10),
              Text(value, style: context.tt.titleMedium!.copyWith(color: color, fontWeight: FontWeight.w700)),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        color: vBg,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(vIcon, color: vColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(verdict == null ? context.s('tripNoPrices') : context.s('result$verdict'),
                  style: context.tt.titleLarge!.copyWith(color: vColor)),
            ),
          ]),
          if (verdict != null) ...[
            const SizedBox(height: 12),
            Text(context.s('resultNet'), style: context.tt.bodyMedium),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(eurSigned(t.net, lang), style: context.tt.displayLarge)),
            if (s.travellers > 1) Text(context.s('resultPerPerson', {'v': eur(t.net / s.travellers, lang)}), style: context.tt.titleMedium),
          ] else ...[
            const SizedBox(height: 8),
            Text(context.s('tripNoPricesSub', {'shops': shops}), style: context.tt.bodyLarge),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Column(children: [
          row(Icons.shopping_bag_rounded, context.s('rowShopping'),
              context.s('tripPriced', {'n': t.basket.priced, 'm': open.length}), eurSigned(t.shopping, lang),
              color: c.good, onTap: () => shellTab.value = 1),
          Divider(color: c.line, height: 1),
          row(Icons.local_gas_station_rounded, context.s('rowFuelTrip'),
              '${t.km} km · ${fmtNum(t.litres, lang)} l × ${eur(t.ltFuel!, lang, digits: 3)}', eurSigned(-t.tripCost, lang),
              color: c.bad, onTap: () => _fuelSheet(context)),
          if (s.refuelLitres > 0) ...[
            Divider(color: c.line, height: 1),
            row(Icons.ev_station_rounded, context.s('rowRefuel'), '${s.refuelLitres} l × ${eur(t.plFuelEur!, lang, digits: 3)}', eurSigned(t.refuelSaving, lang),
                color: t.refuelSaving >= 0 ? c.good : c.bad, onTap: () => _fuelSheet(context)),
          ],
          Container(height: 2, color: c.text, margin: const EdgeInsets.symmetric(vertical: 4)),
          row(Icons.functions_rounded, context.s('rowTotal'), null, eurSigned(t.net, lang)),
        ]),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          [
            context.s('tripSpend', {'v': '${zl(pln, lang)}${plEur == null ? '' : ' ≈ ${eur(plEur, lang)}'}'}),
            if (unknown > 0) context.s('planUnknown', {'n': unknown}),
            if (t.breakEven != null && t.net < 0) context.s('breakEven', {'v': eur(t.breakEven!, lang, digits: 0)}),
          ].join(' · '),
          style: context.tt.bodyMedium,
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

/// When to leave: shops' hours that day in both clocks, and the latest sensible departure.
class _Timing extends StatelessWidget {
  const _Timing({required this.day, required this.stops});
  final DateTime day;
  final List<_Stop> stops;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
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

class _StopCard extends StatelessWidget {
  const _StopCard({required this.n, required this.stop, required this.day, required this.canRemove});
  final int n;
  final _Stop stop;
  final DateTime day;
  final bool canRemove;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (fuel)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Brand.green, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_gas_station_rounded, color: Colors.white),
              )
            else if (chain != null)
              ChainDot(chain, label: '$n')
            else
              const SizedBox(width: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleLarge),
                if (st == null)
                  Text(context.s('planNoShop', {'town': s.dest.name}), style: context.tt.bodyMedium!.copyWith(color: c.warn))
                else ...[
                  Text(st.address ?? st.name ?? context.s('planNoAddress'), style: context.tt.bodyMedium),
                  const SizedBox(height: 6),
                  _HoursPill(store: st, day: day),
                ],
                const SizedBox(height: 8),
                if (fuel)
                  Text(context.s('planFuelLitres', {'l': s.refuelLitres}), style: context.tt.bodyMedium)
                else
                  InkWell(
                    onTap: () => shellTab.value = 1,
                    child: Text(
                      stop.items.isEmpty
                          ? context.s('tripStopNoItems')
                          : context.s('tripStopItems', {'items': context.items(stop.items.length), 'v': '${unknown > 0 ? '≥ ' : ''}${zl(sub, lang)}'}),
                      style: context.tt.titleMedium!.copyWith(color: stop.items.isEmpty ? c.text3 : null),
                    ),
                  ),
              ]),
            ),
            if (canRemove)
              IconButton(
                tooltip: context.s('tripRemoveStop'),
                icon: Icon(Icons.close_rounded, color: c.text3),
                onPressed: () => fuel ? s.update((x) => x.refuelLitres = 0) : s.toggleTripChain(stop.chain),
              ),
          ]),
          if (st != null)
            Wrap(spacing: 0, children: [
              TextButton.icon(onPressed: () => _open(_gmaps(st)), icon: const Icon(Icons.map_rounded, size: 20), label: const Text('Google Maps')),
              TextButton.icon(onPressed: () => _open(_waze(st)), icon: const Icon(Icons.navigation_rounded, size: 20), label: const Text('Waze')),
              if ((s.storeFeed?.inTown(s.destId, stop.chain).length ?? 0) > 1)
                TextButton.icon(
                  onPressed: () => _pickStore(context, stop.chain),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  label: Text(context.s('planOtherShop')),
                ),
            ]),
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

Future<void> _pickStore(BuildContext context, String chain) => showSheet(context, (ctx) {
      final s = AppScope.of(ctx);
      final f = s.storeFeed!;
      final list = f.inTown(s.destId, chain);
      final current = s.storeFor(chain);
      final day = s.tripDay;
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
                final h = dayHours(f.hoursOf(st).hours, day, fuel: st.isFuel);
                final brand = chain == 'fuel' ? '${st.brand} · ' : '';
                return h.kind == HoursKind.open ? '$brand${h.spans.join(', ')}' : '$brand${ctx.s(h.kind == HoursKind.unknown ? 'hoursUnknown' : 'hoursClosed')}';
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
          rows.add((title: shortDealName(d.name), pl: null, deal: d, probe: ListItem(id: '', name: shortDealName(d.name), plName: d.name, dealId: d.id)));
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
