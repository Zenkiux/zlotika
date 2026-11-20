import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

void openCalc(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalcScreen(), fullscreenDialog: true));

/// The shopper's running cart total in the shop: type a shelf price in złoty, press +.
/// Total in zł and € (NBP rate + card fee) stays at the top. Entries survive closing the app.
class CalcScreen extends StatefulWidget {
  const CalcScreen({super.key});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  String _input = ''; // what's being typed, e.g. "3,49"
  int _qty = 1;
  int _pct = 0; // discount shown on the shelf, applied to this price
  bool _typingPct = false; // keypad edits the discount instead of the price
  String _pctInput = '';

  double? get _value => double.tryParse(_input.replaceAll(',', '.'));

  void _key(String k) {
    HapticFeedback.selectionClick();
    if (_typingPct) {
      setState(() {
        if (k == '⌫') {
          if (_pctInput.isNotEmpty) _pctInput = _pctInput.substring(0, _pctInput.length - 1);
        } else if (k != ',' && _pctInput.length < 2) {
          _pctInput = _pctInput == '0' ? k : _pctInput + k;
        }
        _pct = int.tryParse(_pctInput) ?? 0;
      });
      return;
    }
    setState(() {
      if (k == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (k == ',') {
        if (!_input.contains(',')) _input = _input.isEmpty ? '0,' : '$_input,';
      } else {
        final dec = _input.indexOf(',');
        if (dec >= 0 && _input.length - dec > 2) return; // two decimals at most
        if (_input.replaceAll(',', '').length >= 6) return;
        _input = _input == '0' ? k : _input + k;
      }
    });
  }

  void _add() {
    final v = _value;
    if (v == null || v <= 0) return;
    HapticFeedback.mediumImpact();
    AppScope.read(context).update((s) => s.calc.add((price: v, qty: _qty, pct: _pct)));
    setState(() {
      _input = '';
      _qty = 1;
      _pct = 0;
      _typingPct = false;
      _pctInput = '';
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('calcClearQ'), style: ctx.tt.headlineSmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.s('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.s('calcClear'), style: TextStyle(color: ctx.c.bad))),
        ],
      ),
    );
    if (ok == true && mounted) AppScope.read(context).update((s) => s.calc.clear());
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final total = s.calcTotal;
    final eurTotal = s.toEur(total);
    final v = _value;
    final pending = v == null ? null : AppState.calcLine((price: v, qty: _qty, pct: _pct));

    Widget key(String label, {Color? bg, Color? fg, VoidCallback? onTap, IconData? icon, int flex = 1}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Press(
              onTap: onTap ?? () => _key(label),
              scale: .95,
              child: Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg ?? c.surface, borderRadius: BorderRadius.circular(14), border: bg == null ? Border.all(color: c.line) : null),
                child: icon != null
                    ? Icon(icon, size: 24, color: fg ?? c.text)
                    : Text(label, style: context.tt.headlineSmall!.copyWith(color: fg ?? c.text, fontSize: 24)),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('calcTitle')),
        actions: [if (s.calc.isNotEmpty) TextButton(onPressed: _clear, child: Text(context.s('calcClear')))],
      ),
      body: SafeArea(
        child: Column(children: [
          // Running total
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment(-.6, -1), end: Alignment(.6, 1), colors: [Color(0xFFF7CB4D), Brand.yellowDeep]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(context.s('calcTotal', {'n': s.calcCount}), style: context.tt.labelMedium!.copyWith(color: Brand.ink.withValues(alpha: .72), fontSize: 12))),
                if (s.calcSaved > 0.004)
                  Text(context.s('calcSaved', {'v': zl(s.calcSaved, lang)}), style: context.tt.labelMedium!.copyWith(color: Brand.ink, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(zl(total, lang), style: context.tt.displayMedium!.copyWith(color: Brand.ink, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              Text(eurTotal == null ? context.s('rateNone') : '≈ ${eur(eurTotal, lang)}',
                  style: context.tt.titleLarge!.copyWith(color: Brand.ink.withValues(alpha: .8), fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
          // Entries, newest first
          Expanded(
            child: s.calc.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(context.s('calcEmpty'), textAlign: TextAlign.center, style: context.tt.bodyMedium),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    reverse: true,
                    itemCount: s.calc.length,
                    itemBuilder: (_, i) {
                      final idx = s.calc.length - 1 - i;
                      final e = s.calc[idx];
                      final line = AppState.calcLine(e);
                      final le = s.toEur(line);
                      return Dismissible(
                        key: ValueKey('$idx-${e.price}-${e.qty}-${s.calc.length}'),
                        direction: DismissDirection.endToStart,
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 18), child: Icon(Icons.delete_outline_rounded, color: c.bad)),
                        onDismissed: (_) => s.update((x) => x.calc.removeAt(idx)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                          child: Row(children: [
                            SizedBox(width: 28, child: Text('${idx + 1}.', style: context.tt.bodySmall)),
                            Expanded(
                              child: Text('${zl(e.price, lang)}${e.pct > 0 ? ' −${e.pct} %' : ''}${e.qty > 1 ? ' × ${e.qty}' : ''}',
                                  style: context.tt.titleMedium!.copyWith(color: c.text2, fontFeatures: const [FontFeature.tabularFigures()])),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(zl(line, lang), style: context.tt.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                              if (le != null) Text(eur(le, lang), style: context.tt.bodySmall),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          if (s.calc.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.s('calcSwipe'), style: context.tt.bodySmall)),
          // Input line
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(children: [
              Text(_input.isEmpty ? '0' : _input,
                  style: context.tt.displayMedium!.copyWith(fontSize: 34, color: _input.isEmpty ? c.text3 : c.text, fontFeatures: const [FontFeature.tabularFigures()])),
              Text(' zł', style: context.tt.headlineSmall!.copyWith(color: c.text2)),
              const Spacer(),
              if (pending != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (_pct > 0 || _qty > 1)
                    Text('= ${zl(pending, lang)}', style: context.tt.titleLarge!.copyWith(color: c.accentText, fontFeatures: const [FontFeature.tabularFigures()])),
                  if (s.toEur(pending) != null) Text('≈ ${eur(s.toEur(pending)!, lang)}', style: context.tt.titleMedium!.copyWith(color: c.text2)),
                ]),
            ]),
          ),
          // Quantity
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(context.s('itemQty'), style: context.tt.labelMedium),
              const SizedBox(width: 10),
              for (final q in [1, 2, 3, 4, 6])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip2(label: '×$q', active: _qty == q, onTap: () => setState(() => _qty = q)),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          // Discount printed on the shelf ("-20 %") when the new price isn't
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Text(context.s('calcDiscount'), style: context.tt.labelMedium),
                const SizedBox(width: 10),
                for (final p in [0, 10, 20, 25, 30, 40, 50])
                  FilterChip2(
                    label: p == 0 ? context.s('calcNoDiscount') : '−$p %',
                    active: !_typingPct && _pct == p,
                    onTap: () => setState(() {
                      _pct = p;
                      _typingPct = false;
                      _pctInput = '';
                    }),
                  ),
                FilterChip2(
                  label: _typingPct ? '−${_pctInput.isEmpty ? '…' : _pctInput} %' : context.s('calcOther'),
                  active: _typingPct || (_pct != 0 && ![10, 20, 25, 30, 40, 50].contains(_pct)),
                  onTap: () => setState(() {
                    _typingPct = !_typingPct;
                    if (_typingPct) _pctInput = '';
                  }),
                ),
              ]),
            ),
          ),
          if (_typingPct) Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.s('calcTypePct'), style: context.tt.bodySmall!.copyWith(color: c.accentText))),
          const SizedBox(height: 6),
          // Keypad
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(children: [
              Row(children: [key('7'), key('8'), key('9'), key('⌫', icon: Icons.backspace_outlined)]),
              Row(children: [key('4'), key('5'), key('6'), key(',', fg: c.text2)]),
              Row(children: [
                key('1'),
                key('2'),
                key('3'),
                key('0'),
              ]),
              Row(children: [
                key('+', flex: 4, bg: c.accent, fg: c.onAccent, icon: Icons.add_rounded, onTap: _add),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
