import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../trip/trip_screen.dart' show TripCalc;

/// What the trips to Poland actually saved, per trip and per year.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final year = DateTime.now().year;
    final y = s.yearTotals(year);
    return Scaffold(
      appBar: AppBar(title: Text(context.s('histTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Panel(
            color: y.saved >= 0 ? c.goodSoft : c.badSoft,
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('histYear', {'y': year}), style: context.tt.bodyLarge),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(eurSigned(y.saved, lang), style: context.tt.displayLarge!.copyWith(color: y.saved >= 0 ? c.good : c.bad)),
              ),
              Text(context.s('histYearSub', {'n': y.count, 'v': eur(y.spent, lang)}), style: context.tt.bodyMedium),
            ]),
          ),
          const SizedBox(height: 10),
          Text(context.s('histHow'), style: context.tt.bodySmall),
          if (s.trips.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Text(context.s('histEmpty'), textAlign: TextAlign.center, style: context.tt.bodyLarge!.copyWith(color: c.text2)),
            ),
          if (s.trips.isNotEmpty) SectionTitle(context.s('histTrips')),
          for (final t in s.trips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ObjectKey(t),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(color: c.badSoft, borderRadius: BorderRadius.circular(24)),
                  child: Icon(Icons.delete_rounded, color: c.bad, size: 28),
                ),
                onDismissed: (_) => s.removeTrip(t),
                child: Panel(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${dayMonth(DateTime.parse(t.date), lang)} · ${t.dest}', style: context.tt.titleMedium),
                        const SizedBox(height: 2),
                        Text('${context.items(t.items)} · ${zl(t.pln, lang)} ≈ ${eur(t.eur, lang)}', style: context.tt.bodyMedium),
                      ]),
                    ),
                    Text(t.net == null ? '—' : eurSigned(t.net!, lang),
                        style: context.tt.titleLarge!.copyWith(color: t.net == null ? c.text3 : t.net! >= 0 ? c.good : c.bad)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Close the trip: record what was bought and what it saved, clear bought items.
Future<void> showFinishTrip(BuildContext context) => showSheet(context, (_) => const _FinishSheet());

class _FinishSheet extends StatefulWidget {
  const _FinishSheet();

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  final _receipt = TextEditingController();

  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final bought = s.items.where((e) => e.checked).toList();
    var pln = 0.0;
    double? saving;
    for (final i in bought) {
      final p = s.plFor(i)?.price;
      if (p != null) pln += p * i.qty;
      final sv = s.itemSaving(i);
      if (sv != null) saving = (saving ?? 0) + sv;
    }
    final receipt = parseAmount(_receipt.text);
    final spent = receipt ?? pln;
    final t = TripCalc(s);
    final travel = t.ready ? t.tripCost - t.refuelSaving : 0.0;
    final net = saving == null ? null : saving - travel;

    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: context.tt.bodyLarge)),
            Text(value, style: context.tt.titleMedium!.copyWith(color: color)),
          ]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.s('finishTitle'), style: context.tt.headlineSmall),
        const SizedBox(height: 8),
        if (bought.isEmpty) ...[
          Text(context.s('finishNone'), style: context.tt.bodyLarge),
          const SizedBox(height: 14),
          BigButton(
            label: context.s('finishMarkAll'),
            icon: Icons.done_all_rounded,
            onPressed: () => s.update((x) {
              for (final i in x.items) {
                i.checked = true;
              }
            }),
          ),
        ] else ...[
          Text(context.s('finishSub', {'n': bought.length}), style: context.tt.bodyMedium),
          const SizedBox(height: 16),
          Text(context.s('finishReceipt'), style: context.tt.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _receipt,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: context.tt.headlineSmall,
            decoration: InputDecoration(hintText: pln > 0 ? pln.toStringAsFixed(2).replaceAll('.', ',') : '0,00', suffixText: 'zł'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Column(children: [
              row(context.s('finishSpent'), s.toEur(spent) == null ? zl(spent, lang) : '${zl(spent, lang)} ≈ ${eur(s.toEur(spent)!, lang)}'),
              row(context.s('finishSaving'), saving == null ? '—' : eurSigned(saving, lang), color: (saving ?? 0) >= 0 ? c.good : c.bad),
              if (t.ready) row(context.s('finishTravel'), eurSigned(-travel, lang), color: travel > 0 ? c.bad : c.good),
              Divider(color: c.line),
              row(context.s('finishNet'), net == null ? '—' : eurSigned(net, lang), color: (net ?? 0) >= 0 ? c.good : c.bad),
            ]),
          ),
          if (saving == null) ...[
            const SizedBox(height: 8),
            Text(context.s('finishNoLt'), style: context.tt.bodySmall),
          ],
          const SizedBox(height: 18),
          BigButton(
            label: context.s('finishSave'),
            icon: Icons.check_rounded,
            onPressed: () {
              s.addTrip(TripRecord(
                date: DateTime.now().toIso8601String().substring(0, 10),
                dest: s.dest.name,
                pln: spent,
                eur: s.toEur(spent) ?? 0,
                items: bought.length,
                saving: saving,
                travel: travel,
              ));
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
        ],
      ]),
    );
  }
}
