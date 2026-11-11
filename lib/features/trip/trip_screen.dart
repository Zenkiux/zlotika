import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/calendar.dart';
import '../../data/geo.dart';
import '../../services/fuel.dart';
import '../../main.dart';
import '../../widgets/ui.dart';

/// Trip economics. Every number shown is derived here from user inputs + live NBP rate.
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

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  static const _steps = 4;
  int? _step; // null = result

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.read(context);
    _step ??= (s.ltFuel == null || s.plFuel == null) ? 0 : null;
  }

  void _go(int? step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    final step = _step;
    return SafeArea(
      bottom: false,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(a), child: child),
        ),
        child: step == null
            ? _Result(key: const ValueKey('r'), onEdit: () => _go(0))
            : _Wizard(
                key: ValueKey(step),
                step: step,
                total: _steps,
                onBack: step == 0 ? null : () => _go(step - 1),
                onNext: () => _go(step + 1 >= _steps ? null : step + 1),
              ),
      ),
    );
  }
}

class _Wizard extends StatelessWidget {
  const _Wizard({super.key, required this.step, required this.total, required this.onNext, this.onBack});
  final int step, total;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final canNext = step != 3 || (s.ltFuel != null && s.plFuel != null);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
        child: Row(children: [
          if (onBack != null)
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, size: 28), tooltip: context.s('back'))
          else
            const SizedBox(width: 12),
          Expanded(child: Text(context.s('tripStep', {'i': step + 1, 'n': total}), style: context.tt.labelMedium)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                decoration: BoxDecoration(color: i <= step ? Brand.yellow : c.raised, borderRadius: BorderRadius.circular(3)),
              ),
            ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: switch (step) {
            0 => _from(context, s),
            1 => _to(context, s),
            2 => _car(context, s),
            _ => _fuel(context, s),
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
        child: BigButton(label: context.s('next'), icon: Icons.arrow_forward_rounded, onPressed: canNext ? onNext : null),
      ),
    ]);
  }

  List<Widget> _title(BuildContext context, String key, [String? sub]) => [
        Text(context.s(key), style: context.tt.headlineMedium),
        if (sub != null) ...[const SizedBox(height: 8), Text(context.s(sub), style: context.tt.bodyLarge!.copyWith(color: context.c.text2))],
        const SizedBox(height: 22),
      ];

  List<Widget> _from(BuildContext context, AppState s) => [
        ..._title(context, 'tripFrom'),
        for (final o in origins)
          ChoiceRow(
            title: o.name,
            selected: s.originId == o.id,
            leading: const Icon(Icons.home_rounded),
            onTap: () {
              s.update((x) => x.originId = o.id);
              onNext();
            },
          ),
      ];

  List<Widget> _to(BuildContext context, AppState s) => [
        ..._title(context, 'tripTo'),
        for (final d in destinations)
          ChoiceRow(
            title: d.name,
            subtitle: '${s.origin.km[d.id]} km',
            selected: s.destId == d.id,
            leading: const Icon(Icons.location_on_rounded, color: Brand.plRed),
            onTap: () {
              s.update((x) => x.destId = d.id);
              onNext();
            },
          ),
      ];

  List<Widget> _car(BuildContext context, AppState s) {
    final lang = context.lang;
    return [
      ..._title(context, 'tripCar'),
      for (final f in FuelType.values)
        ChoiceRow(
          title: context.s(switch (f) { FuelType.diesel => 'fuelDiesel', FuelType.petrol => 'fuelPetrol', FuelType.lpg => 'fuelLpg' }),
          selected: s.fuel == f,
          leading: const Icon(Icons.local_gas_station_rounded),
          onTap: () => s.update((x) => x.fuel = f),
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
    ];
  }

  List<Widget> _fuel(BuildContext context, AppState s) {
    final lang = context.lang;
    return [
      ..._title(context, 'tripFuel', 'tripFuelSub'),
      _PriceField(
        key: ValueKey('lt-${s.fuel.name}'),
        label: context.s('fuelLt'),
        suffix: '€',
        value: s.ltFuelPrice,
        auto: s.autoLtFuel,
        autoSource: s.autoLtSource,
        onChanged: (v) => s.update((x) => x.ltFuelPrice = v),
      ),
      if (s.autoLtFuel == null) _SourceLink(text: context.s('srcLt'), url: 'https://degalukainos.ena.lt/'),
      const SizedBox(height: 18),
      _PriceField(
        key: ValueKey('pl-${s.fuel.name}'),
        label: context.s('fuelPl'),
        suffix: 'zł',
        value: s.plFuelPrice,
        auto: s.autoPlFuel,
        autoSource: s.autoPlSource,
        onChanged: (v) => s.update((x) => x.plFuelPrice = v),
      ),
      if (s.autoPlFuel == null) _SourceLink(text: context.s('srcPl'), url: 'https://www.e-petrol.pl/notowania/rynek-krajowy/ceny-stacje-paliw'),
      const SizedBox(height: 18),
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
    ];
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

class _Result extends StatelessWidget {
  const _Result({super.key, required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final t = TripCalc(s);
    final verdict = t.net >= 15 ? 'Worth' : t.net >= 0 ? 'Marginal' : 'Not';
    final (vColor, vBg, vIcon) = switch (verdict) {
      'Worth' => (c.good, c.goodSoft, Icons.check_circle_rounded),
      'Marginal' => (c.warn, c.warnSoft, Icons.help_rounded),
      _ => (c.bad, c.badSoft, Icons.cancel_rounded),
    };
    final sat = nextSaturday(DateTime.now());
    final sundayToday = !shopsOpen(DateTime.now());

    Widget row(IconData icon, String label, String? sub, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: c.text2, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: context.tt.titleMedium),
                if (sub != null) Text(sub, style: context.tt.bodyMedium),
              ]),
            ),
            const SizedBox(width: 10),
            Text(value, style: context.tt.titleLarge!.copyWith(color: color)),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('${s.origin.name} → ${s.dest.name}', style: context.tt.titleMedium!.copyWith(color: c.text2)),
        const SizedBox(height: 4),
        Text(context.s('tripTitle'), style: context.tt.headlineMedium),
        const SizedBox(height: 18),
        if (s.rate == null)
          Panel(color: c.warnSoft, child: Text(context.s('rateNone'), style: context.tt.bodyLarge))
        else ...[
          Panel(
            color: vBg,
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(vIcon, color: vColor, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text(context.s('result$verdict'), style: context.tt.titleLarge!.copyWith(color: vColor))),
              ]),
              const SizedBox(height: 14),
              Text(context.s('resultNet'), style: context.tt.bodyMedium),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(eurSigned(t.net, lang), style: context.tt.displayLarge)),
              if (s.travellers > 1) Text(context.s('resultPerPerson', {'v': eur(t.net / s.travellers, lang)}), style: context.tt.titleMedium),
              const SizedBox(height: 8),
              Text(context.s('result${verdict}Sub'), style: context.tt.bodyLarge),
            ]),
          ),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
            child: Column(children: [
              row(Icons.route_rounded, context.s('rowDistance'), null, '${t.km} km'),
              Divider(color: c.line),
              row(Icons.local_gas_station_rounded, context.s('rowFuelTrip'),
                  '${fmtNum(t.litres, lang)} l × ${eur(t.ltFuel!, lang, digits: 3)}', eurSigned(-t.tripCost, lang), color: c.bad),
              Divider(color: c.line),
              if (t.basket.priced > 0)
                row(Icons.shopping_bag_rounded, context.s('rowShopping'), context.items(t.basket.priced), eurSigned(t.shopping, lang), color: c.good)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(Icons.shopping_bag_outlined, color: c.text3, size: 26),
                    const SizedBox(width: 14),
                    Expanded(child: Text(context.s('rowShoppingNone'), style: context.tt.titleMedium!.copyWith(color: c.text2))),
                    TextButton(onPressed: () => shellTab.value = 2, child: Text(context.s('resultToList'))),
                  ]),
                ),
              if (s.refuelLitres > 0) ...[
                Divider(color: c.line),
                row(Icons.ev_station_rounded, context.s('rowRefuel'),
                    '${s.refuelLitres} l × ${eur(t.plFuelEur!, lang, digits: 3)}', eurSigned(t.refuelSaving, lang),
                    color: t.refuelSaving >= 0 ? c.good : c.bad),
              ],
              Container(height: 2, color: c.text, margin: const EdgeInsets.symmetric(vertical: 6)),
              row(Icons.functions_rounded, context.s('rowTotal'), null, eurSigned(t.net, lang)),
            ]),
          ),
          if (t.breakEven != null) ...[
            const SizedBox(height: 14),
            Panel(
              color: c.raised,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.balance_rounded, color: c.text2),
                const SizedBox(width: 12),
                Expanded(child: Text(context.s('breakEven', {'v': eur(t.breakEven!, lang, digits: 0)}), style: context.tt.bodyLarge)),
              ]),
            ),
          ],
          if (sundayToday || !shopsOpen(sat)) ...[
            const SizedBox(height: 14),
            Panel(color: c.badSoft, child: Text(sundayToday ? context.s('tripSunday') : context.s('shopsNextClosed', {'date': dayMonth(sat, lang)}), style: context.tt.bodyLarge)),
          ],
        ],
        const SizedBox(height: 18),
        BigButton(
          label: context.s('resultMaps'),
          icon: Icons.map_rounded,
          onPressed: () => launchUrl(
            Uri.parse('https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent('${s.origin.name}, Lithuania')}'
                '&destination=${Uri.encodeComponent('${s.dest.name}, Poland')}&travelmode=driving'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: 10),
        BigButton(label: context.s('resultEdit'), icon: Icons.tune_rounded, kind: BtnKind.secondary, onPressed: onEdit),
        const SizedBox(height: 16),
        Text(context.s('estimate'), style: context.tt.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
