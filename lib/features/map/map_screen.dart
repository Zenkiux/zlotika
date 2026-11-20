import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/hours.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../data/geo.dart';
import '../../main.dart' show shellTab, Tabs;
import '../../services/stores.dart';
import '../../services/wallet.dart';
import '../../services/ltfuel.dart' show PlReport;
import '../../widgets/ui.dart';
import '../cards/cards_screen.dart' show showCard;
import '../more/more_screen.dart';

/// Shops and fuel stations on a map. Tap a pin: hours, prices, and drive there.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  LatLng? _me;
  bool _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('off');
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('denied');
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 12)));
      _me = LatLng(pos.latitude, pos.longitude);
      _map.move(_me!, 13);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s('mapNoLocation'))));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<Store> _visible(AppState s) {
    final f = s.storeFeed;
    if (f == null) return const [];
    final p = plNow();
    // Lithuanian stations: LEA's list (with today's prices) replaces OpenStreetMap's where loaded.
    final lt = s.ltStations;
    final all = [
      for (final st in f.stores)
        if (!(lt != null && st.isFuel && st.country == 'LT')) st,
      if (lt != null) for (final x in lt.stations) x.store,
    ];
    return all.where((st) {
      if (st.isFuel) {
        if (!s.mapLayers.contains('fuel')) return false;
        if (!s.mapLayers.contains('fuel${st.country}')) return false;
      } else {
        if (!s.mapLayers.contains('shops')) return false;
        if (s.mapChains.isNotEmpty && !s.mapChains.contains(st.chain)) return false;
      }
      if (s.mapOpenOnly) {
        final now = _localNow(st, p);
        final h = dayHours(f.hoursOf(st).hours, now, fuel: st.isFuel);
        if (nowStatus(h, now.hour * 60 + now.minute).kind != NowKind.open) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dest = destById(s.destId);
    final stores = _visible(s);

    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: LatLng(dest.lat, dest.lon),
          initialZoom: 12.5,
          minZoom: 6,
          maxZoom: 18,
          backgroundColor: dark ? const Color(0xFF0D0E14) : const Color(0xFFF2F2F2),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          osmTiles(context),
          MarkerLayer(markers: [
            for (final st in stores)
              Marker(
                point: LatLng(st.lat, st.lon),
                width: 34,
                height: 34,
                child: GestureDetector(onTap: () => showPlace(context, st), child: _Pin(st)),
              ),
            if (_me != null)
              Marker(
                point: _me!,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                ),
              ),
          ]),
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors', onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))),
            ],
          ),
        ],
      ),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.c.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.s('mapTitle'), style: context.tt.titleLarge),
                    Text(context.s('mapCount', {'n': stores.length}), style: context.tt.bodySmall),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              const SettingsButton(),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _Chip(label: context.s('mapShops'), icon: Icons.storefront_rounded, on: s.mapLayers.contains('shops'), onTap: () => s.update((x) => x.mapLayers.contains('shops') ? x.mapLayers.remove('shops') : x.mapLayers.add('shops'))),
                _Chip(label: context.s('mapFuel'), icon: Icons.local_gas_station_rounded, on: s.mapLayers.contains('fuel'), onTap: () => s.update((x) => x.mapLayers.contains('fuel') ? x.mapLayers.remove('fuel') : x.mapLayers.add('fuel'))),
                _Chip(label: context.s('mapOpenNow'), icon: Icons.schedule_rounded, on: s.mapOpenOnly, onTap: () => s.update((x) => x.mapOpenOnly = !x.mapOpenOnly)),
                _Chip(label: context.s('mapFilter'), icon: Icons.tune_rounded, on: s.mapChains.isNotEmpty, onTap: () => _filters(context)),
              ]),
            ),
          ]),
        ),
      ),
      Positioned(
        right: 16,
        bottom: 24,
        child: Column(children: [
          RoundIcon(Icons.flag_rounded, tooltip: dest.name, onTap: () => _map.move(LatLng(dest.lat, dest.lon), 12.5)),
          const SizedBox(height: 10),
          RoundIcon(_locating ? Icons.more_horiz_rounded : Icons.my_location_rounded, filled: true, tooltip: context.s('mapMe'), onTap: _locate),
        ]),
      ),
    ]);
  }
}

DateTime _localNow(Store st, DateTime pl) => st.country == 'LT' ? pl.add(const Duration(hours: 1)) : pl;

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.on, required this.onTap});
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? Brand.yellow : c.surface,
        shape: StadiumBorder(side: on ? BorderSide.none : BorderSide(color: c.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(on ? Icons.check_rounded : icon, size: 17, color: on ? Brand.ink : c.text2),
              const SizedBox(width: 6),
              Text(label, style: context.tt.labelMedium!.copyWith(color: on ? Brand.ink : c.text)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin(this.st);
  final Store st;

  @override
  Widget build(BuildContext context) {
    final ch = chainById(st.chain);
    final fuel = st.isFuel;
    final bg = fuel ? (st.country == 'LT' ? const Color(0xFF2B2E3C) : const Color(0xFF1F2430)) : (ch?.color ?? Brand.ink3);
    final fg = fuel ? Brand.yellow : (ch?.ink ?? Colors.white);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: fuel
          ? Icon(Icons.local_gas_station_rounded, size: 17, color: fg)
          : Text((ch?.name ?? st.brand).characters.first, style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 15, color: fg)),
    );
  }
}

Future<void> _filters(BuildContext context) => showSheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, setLocal) {
        final s = AppScope.of(ctx);
        final present = {for (final st in s.storeFeed?.stores ?? const <Store>[]) st.chain};
        final list = chains.where((c) => present.contains(c.id)).toList();
        Widget check(String title, bool v, VoidCallback onTap, {Widget? leading}) => CheckboxListTile(
              value: v,
              onChanged: (_) {
                onTap();
                setLocal(() {});
              },
              controlAffinity: ListTileControlAffinity.trailing,
              contentPadding: EdgeInsets.zero,
              secondary: leading ?? const SizedBox(width: 30, height: 30, child: Icon(Icons.local_gas_station_rounded)),
              title: Text(title, style: ctx.tt.titleMedium),
            );
        bool chainOn(String id) => s.mapChains.isEmpty || s.mapChains.contains(id);
        bool fuelOn(String cc) => s.mapLayers.contains('fuel') && s.mapLayers.contains('fuel$cc');
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(ctx.s('mapFilterTitle'), style: ctx.tt.headlineSmall),
            const SizedBox(height: 4),
            Text(ctx.s('mapFilterSub'), style: ctx.tt.bodyMedium),
            SectionTitle(ctx.s('mapShops')),
            for (final ch in list)
              check(ch.name, chainOn(ch.id), leading: SizedBox(width: 30, height: 30, child: _Pin(Store(id: '', chain: ch.id, brand: ch.name, town: '', lat: 0, lon: 0))), () {
                s.update((x) {
                  if (x.mapChains.isEmpty) x.mapChains.addAll(list.map((e) => e.id));
                  x.mapChains.contains(ch.id) ? x.mapChains.remove(ch.id) : x.mapChains.add(ch.id);
                  if (x.mapChains.length == list.length) x.mapChains.clear();
                  x.mapLayers.add('shops');
                });
              }),
            SectionTitle(ctx.s('mapFuel')),
            for (final cc in ['LT', 'PL'])
              check(ctx.s(cc == 'LT' ? 'mapFuelLT' : 'mapFuelPL'), fuelOn(cc), () {
                s.update((x) {
                  final on = fuelOn(cc);
                  if (on) {
                    x.mapLayers.remove('fuel$cc');
                    if (!x.mapLayers.contains('fuelLT') && !x.mapLayers.contains('fuelPL')) x.mapLayers.remove('fuel');
                  } else {
                    x.mapLayers..add('fuel')..add('fuel$cc');
                  }
                });
              }),
            const SizedBox(height: 14),
            BigButton(label: ctx.s('done'), onPressed: () => Navigator.pop(ctx)),
          ],
        );
      });
    });

void _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Details for one shop or station, with "drive with Waze / Google Maps".
Future<void> showPlace(BuildContext context, Store st) => showSheet(context, (ctx) => _PlaceSheet(st));

class _PlaceSheet extends StatelessWidget {
  const _PlaceSheet(this.st);
  final Store st;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final ch = chainById(st.chain);
    final title = st.isFuel ? st.brand : (ch?.name ?? st.brand);
    final where = [st.address, if (st.name != null && st.isFuel) st.name].whereType<String>().join(' · ');
    final card = s.wallet.where((w) => w.t.chain == st.chain).firstOrNull;
    final dealCount = st.isFuel ? 0 : s.deals.where((d) => d.chain == st.chain).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _Pin(st),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.tt.headlineSmall),
              Text(
                [if (where.isNotEmpty) where, st.country == 'LT' ? context.s('mapInLT') : context.s('mapInPL')].join(' · '),
                style: context.tt.bodyMedium,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        _Hours(st),
        if (st.isFuel) ...[const SizedBox(height: 14), _FuelPrices(st)],
        if (!st.isFuel && (dealCount > 0 || card != null)) ...[
          const SizedBox(height: 14),
          RowGroup(children: [
            if (dealCount > 0)
              RowTile(
                icon: Icons.local_offer_rounded,
                title: context.s('mapDeals', {'n': dealCount}),
                last: card == null,
                onTap: () {
                  Navigator.pop(context);
                  shellTab.value = Tabs.deals;
                },
              ),
            if (card != null) RowTile(icon: Icons.credit_card_rounded, title: context.s('mapShowCard', {'c': card.title}), last: true, onTap: () => showCard(context, card)),
          ]),
        ],
        const SizedBox(height: 18),
        Text(context.s('mapDrive'), style: context.tt.labelMedium),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _DriveButton(
              label: 'Waze',
              color: const Color(0xFF33CCFF),
              onTap: () => _open('https://waze.com/ul?ll=${st.lat},${st.lon}&navigate=yes'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DriveButton(
              label: 'Google Maps',
              color: Brand.yellow,
              onTap: () => _open('https://www.google.com/maps/dir/?api=1&destination=${st.lat},${st.lon}&travelmode=driving'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(context.s('mapOsm'), style: context.tt.bodySmall!.copyWith(color: c.text3), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _DriveButton extends StatelessWidget {
  const _DriveButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: SizedBox(
            height: 54,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.navigation_rounded, size: 20, color: Brand.ink),
              const SizedBox(width: 8),
              Text(label, style: context.tt.labelLarge!.copyWith(color: Brand.ink)),
            ]),
          ),
        ),
      );
}

class _Hours extends StatelessWidget {
  const _Hours(this.st);
  final Store st;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final f = s.storeFeed!;
    final (:hours, :guessed) = f.hoursOf(st);
    final now = _localNow(st, plNow());
    final h = dayHours(hours, now, fuel: st.isFuel);
    final status = nowStatus(h, now.hour * 60 + now.minute);
    final (text, fg, bg) = switch (h.kind) {
      HoursKind.lawClosed => (context.s('mapLawClosed'), c.bad, c.badSoft),
      HoursKind.closed => (context.s('hoursClosed'), c.bad, c.badSoft),
      HoursKind.unknown => (context.s('hoursUnknown'), c.text2, c.raised),
      HoursKind.open when h.opens == 0 && h.closes == 1440 => (context.s('hours247'), c.good, c.goodSoft),
      HoursKind.open => switch (status.kind) {
          NowKind.open => (context.s('mapOpenUntil', {'t': fmtMin(status.at!)}), c.good, c.goodSoft),
          NowKind.opensLater => (context.s('mapOpensAt', {'t': fmtMin(status.at!)}), c.warn, c.warnSoft),
          _ => (context.s('hoursClosedNow'), c.bad, c.badSoft),
        },
    };
    final week = <(String, String)>[];
    if (hours != null) {
      final names = context.lang == Lang.lt ? ['Pr', 'An', 'Tr', 'Kt', 'Pn', 'Št', 'Sk'] : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var d = 1; d <= 7; d++) {
        final sp = hours.weekday(d);
        week.add((names[d - 1], sp == null ? '—' : sp.isEmpty ? context.s('hoursClosed') : sp.join(', ')));
      }
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(text, fg: fg, bg: bg, icon: Icons.schedule_rounded),
          const Spacer(),
          Text(context.s(st.country == 'LT' ? 'mapTimeLT' : 'mapTimePL'), style: context.tt.bodySmall),
        ]),
        if (week.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final (d, v) in week)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(width: 48, child: Text(d, style: context.tt.bodyMedium!.copyWith(fontWeight: d == week[now.weekday - 1].$1 ? FontWeight.w700 : null, color: d == week[now.weekday - 1].$1 ? c.text : null))),
                Expanded(child: Text(v, style: context.tt.bodyMedium)),
              ]),
            ),
        ],
        if (guessed) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.s('hoursGuessed'), style: context.tt.bodySmall)),
      ]),
    );
  }
}

class _FuelPrices extends StatelessWidget {
  const _FuelPrices(this.st);
  final Store st;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final rate = s.rate?.mid;
    final f = s.fuelFeed;
    final lt = st.country == 'LT';
    final seen = s.seenFuel[st.id];
    final real = st.id.startsWith('lea:') ? s.ltStations?.byId(st.id) : null;
    final reported = !lt ? s.plReports?.near(st.lat, st.lon) : null;
    PlReport? rep(String k) => reported == null ? null : switch (k) { 'pb95' => reported.pb95, 'diesel' => reported.diesel, _ => reported.lpg };

    // Published country prices in the station's own currency.
    double? pick(String k) {
      if (real != null) return switch (k) { 'pb95' => real.pb95, 'diesel' => real.diesel, _ => real.lpg };
      if (lt) {
        final p = f?.lt;
        return switch (k) { 'pb95' => p?.pb95, 'diesel' => p?.diesel, _ => p?.lpg };
      }
      double? v;
      for (final p in [f?.plRegion, f?.pl]) {
        v ??= switch (k) { 'pb95' => p?.pb95, 'diesel' => p?.diesel, _ => p?.lpg };
      }
      if (v == null && rate != null) {
        final e = switch (k) { 'pb95' => f?.plEu?.pb95, 'diesel' => f?.plEu?.diesel, _ => f?.plEu?.lpg };
        if (e != null) v = e * rate;
      }
      final cap = switch (k) { 'pb95' => f?.plCap?.pb95, 'diesel' => f?.plCap?.diesel, _ => null };
      if (v == null) return cap;
      return cap != null && cap < v ? cap : v;
    }

    String both(double? v) {
      if (v == null) return '—';
      if (rate == null) return lt ? eur(v, lang) : zl(v, lang);
      return lt ? '${eur(v, lang, digits: 3)}\n${zl(v * rate, lang)}' : '${zl(v, lang)}\n${eur(v / rate, lang, digits: 3)}';
    }

    Widget cell(String label, String k) {
      final mine = switch (k) { 'pb95' => seen?.pb95, 'diesel' => seen?.diesel, _ => seen?.lpg } ?? rep(k)?.price;
      final byDrivers = switch (k) { 'pb95' => seen?.pb95, 'diesel' => seen?.diesel, _ => seen?.lpg } == null && rep(k) != null;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: context.tt.bodySmall),
            const SizedBox(height: 2),
            Text(both(mine ?? pick(k)), style: context.tt.titleMedium!.copyWith(height: 1.25)),
            if (byDrivers)
              Text(context.s('mapDrivers', {'d': rep(k)!.days == 0 ? context.s('today2') : context.s('daysAgo', {'n': rep(k)!.days})}), style: context.tt.bodySmall!.copyWith(color: c.good))
            else if (mine != null)
              Text(context.s('mapSeenYou'), style: context.tt.bodySmall!.copyWith(color: c.good)),
          ]),
        ),
      );
    }

    final src = lt ? f?.lt : (f?.plRegion ?? f?.pl ?? f?.plEu);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [cell('Pb95', 'pb95'), const SizedBox(width: 8), cell(context.s('fuelDiesel'), 'diesel'), const SizedBox(width: 8), cell('LPG', 'lpg')]),
      const SizedBox(height: 8),
      if (real != null)
        Row(children: [
          Icon(Icons.verified_outlined, size: 15, color: c.good),
          const SizedBox(width: 6),
          Expanded(child: Text(context.s('mapFuelReal', {'t': real.at.length >= 16 ? real.at.substring(5, 16).replaceFirst(' ', ' ') : real.at}), style: context.tt.bodySmall!.copyWith(color: c.good))),
        ])
      else
        Text(
          context.s(lt ? 'mapFuelAvgLT' : 'mapFuelAvgPL', {'src': src?.source ?? '—', 'd': src?.date ?? '—'}),
          style: context.tt.bodySmall,
        ),
      if (seen != null) Text(context.s('mapSeenAt', {'t': '${dayMonth(seen.at, lang)} ${fmtMin(seen.at.hour * 60 + seen.at.minute)}'}), style: context.tt.bodySmall),
      const SizedBox(height: 10),
      BigButton(label: context.s('mapSeenAdd'), icon: Icons.edit_rounded, kind: BtnKind.secondary, onPressed: () => _seenSheet(context, st)),
    ]);
  }
}

Future<void> _seenSheet(BuildContext context, Store st) => showSheet(context, (ctx) {
      final s = AppScope.read(ctx);
      final old = s.seenFuel[st.id];
      final cur = st.country == 'LT' ? '€' : 'zł';
      final ctrls = {
        'pb95': TextEditingController(text: old?.pb95?.toString() ?? ''),
        'diesel': TextEditingController(text: old?.diesel?.toString() ?? ''),
        'lpg': TextEditingController(text: old?.lpg?.toString() ?? ''),
      };
      double? n(String k) => double.tryParse(ctrls[k]!.text.replaceAll(',', '.').trim());
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.s('mapSeenTitle'), style: ctx.tt.headlineSmall),
          const SizedBox(height: 4),
          Text(ctx.s('mapSeenSub'), style: ctx.tt.bodyMedium),
          const SizedBox(height: 14),
          for (final (k, label) in [('pb95', 'Pb95'), ('diesel', ctx.s('fuelDiesel')), ('lpg', 'LPG')]) ...[
            TextField(
              controller: ctrls[k],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '$label, $cur/l'),
            ),
            const SizedBox(height: 10),
          ],
          BigButton(
            label: ctx.s('save'),
            onPressed: () {
              s.update((x) {
                if (n('pb95') == null && n('diesel') == null && n('lpg') == null) {
                  x.seenFuel.remove(st.id);
                } else {
                  x.seenFuel[st.id] = SeenFuel(pb95: n('pb95'), diesel: n('diesel'), lpg: n('lpg'), at: DateTime.now());
                }
              });
              Navigator.pop(ctx);
            },
          ),
        ]),
      );
    });


/// The OpenStreetMap base layer used by every map in the app. Every tile you look at stays
/// on the phone for 30 days, so towns you opened at home still show with no signal.
/// (OSM's tile policy forbids bulk pre-downloads, so we only keep what was viewed.)
Widget osmTiles(BuildContext context) => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'lt.zlotika.zlotika',
      tileBuilder: Theme.of(context).brightness == Brightness.dark ? darkModeTileBuilder : null,
      tileProvider: NetworkTileProvider(
        cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(overrideFreshAge: const Duration(days: 30), maxCacheSize: 300000000),
      ),
    );
