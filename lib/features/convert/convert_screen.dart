import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  final _pln = TextEditingController();
  final _eur = TextEditingController();

  @override
  void dispose() {
    _pln.dispose();
    _eur.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', context.lang == Lang.lt ? ',' : '.');

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final r = s.rate;
    final factor = r == null ? null : (1 + s.cardFeePct / 100) / r.mid; // EUR per PLN

    Widget field(TextEditingController ctl, String label, String suffix, void Function(double?) onVal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.tt.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: ctl,
              enabled: r != null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: context.tt.displayMedium,
              decoration: InputDecoration(
                hintText: '0',
                suffixIcon: Padding(padding: const EdgeInsets.only(right: 18), child: Text(suffix, style: context.tt.headlineSmall!.copyWith(color: c.text3))),
                suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              onChanged: (v) => onVal(parseAmount(v)),
            ),
          ],
        );

    return Scaffold(
      appBar: AppBar(backgroundColor: c.bg, surfaceTintColor: Colors.transparent, title: Text(context.s('convTitle'), style: context.tt.titleLarge)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (r == null) Panel(color: c.warnSoft, child: Text(context.s('rateNone'), style: context.tt.bodyLarge)),
            field(_pln, context.s('convPln'), 'zł', (v) => setState(() => _eur.text = (v == null || factor == null) ? '' : _fmt(v * factor))),
            const SizedBox(height: 6),
            Center(child: Icon(Icons.swap_vert_rounded, color: c.text3, size: 30)),
            field(_eur, context.s('convEur'), '€', (v) => setState(() => _pln.text = (v == null || factor == null) ? '' : _fmt(v / factor))),
            if (r != null) ...[
              const SizedBox(height: 10),
              Text(context.s('convRate', {'r': fmtNum(r.mid, lang, digits: 4), 'd': r.date}), style: context.tt.bodyMedium),
            ],
            const SizedBox(height: 22),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.s('convFee'), style: context.tt.titleMedium),
                Text(context.s('convFeeSub'), style: context.tt.bodyMedium),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final f in [0.0, 1.0, 2.0, 3.0])
                    ChoiceChip(
                      label: Text('${fmtNum(f, lang, digits: 0)} %', style: context.tt.titleMedium),
                      selected: s.cardFeePct == f,
                      selectedColor: Brand.yellow,
                      labelStyle: TextStyle(color: s.cardFeePct == f ? Brand.ink : c.text),
                      onSelected: (_) {
                        s.update((x) => x.cardFeePct = f);
                        _pln.clear();
                        _eur.clear();
                      },
                    ),
                ]),
              ]),
            ),
            if (factor != null) ...[
              SectionTitle(context.s('convQuick')),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Column(children: [
                  for (final (i, v) in [10, 20, 50, 100, 200, 500].indexed) ...[
                    if (i > 0) Divider(color: c.line),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Expanded(child: Text(zl(v.toDouble(), lang), style: context.tt.titleMedium)),
                        Text(eur(v * factor, lang), style: context.tt.titleLarge),
                      ]),
                    ),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
