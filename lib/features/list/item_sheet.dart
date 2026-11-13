import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../services/prices.dart';
import '../../services/deals.dart';
import '../../widgets/ui.dart';
import 'deal_pick.dart';
import 'add_item_screen.dart' show newId;

Future<void> showItemSheet(BuildContext context, ListItem item) => showSheet(context, (_) => _ItemSheet(item: item));

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.item});
  final ListItem item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _pl = TextEditingController(text: widget.item.plPrice?.toStringAsFixed(2).replaceAll('.', ','));
  late final _lt = TextEditingController(text: widget.item.ltPrice?.toStringAsFixed(2).replaceAll('.', ','));
  late int _qty = widget.item.qty;
  late String? _chain = widget.item.chain;
  Deal? _picked; // deal chosen in this sheet; its price fills the PL field

  @override
  void dispose() {
    _pl.dispose();
    _lt.dispose();
    super.dispose();
  }

  void _save() {
    final s = AppScope.read(context);
    s.changeItem(widget.item.id, (i) {
      i.qty = _qty;
      i.chain = _chain;
      i.plPrice = parseAmount(_pl.text);
      if (_picked != null && i.plPrice == s.dealPrice(_picked!)) {
        i.chain = _picked!.chain;
        i.dealId = _picked!.id;
      }
      i.ltPrice = parseAmount(_lt.text);
    });
    Navigator.pop(context);
  }

  /// Which chain to buy it at: puts the item on that shop's stop in the trip plan.
  List<Widget> _where(BuildContext context, AppState s) {
    final ids = {...?s.storeFeed?.chainsIn(s.destId), ?_chain};
    final opts = chains.where((c) => ids.contains(c.id)).toList();
    if (opts.isEmpty) return const [];
    Widget chip(String label, String? id, {Color? color}) => ChoiceChip(
          label: Text(label),
          selected: _chain == id,
          avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 6),
          onSelected: (_) => setState(() => _chain = id),
        );
    return [
      const SizedBox(height: 20),
      Text(context.s('itemWhere'), style: context.tt.titleMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in opts) chip(c.name, c.id, color: c.color),
        chip(context.s('itemWhereAny'), null),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final item = widget.item;
    final pl = parseAmount(_pl.text);
    final lt = parseAmount(_lt.text);
    final plEur = pl == null ? null : s.toEur(pl);
    // Reference prices: typical shelf prices for this kind of product.
    final plRef = s.plRef(item), ltRef = s.ltRef(item);
    final Qty? size = _picked != null ? dealQty(_picked!) : (s.basis(item) ?? (pl == null && plRef != null ? (qty: plRef.exQty, unit: plRef.unit) : null));
    final ltEst = ltRef == null || size == null ? null : AppState.ltFromRef(ltRef, size);
    final ltUse = lt ?? ltEst;
    final saving = (plEur != null && ltUse != null) ? (ltUse - plEur) * _qty : null;
    String unitName(String u) => u == 'units' ? context.s('unitPiece') : u;
    Widget refLine(String text, String? fill, TextEditingController ctl) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 18, color: c.text3),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: context.tt.bodySmall)),
            if (fill != null)
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => setState(() => ctl.text = fill),
                child: Text(context.s('refUse')),
              ),
          ]),
        );

    // Unit always visible (suffixText only shows while focused).
    InputDecoration dec(String suffix) => InputDecoration(
          hintText: '0,00',
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Text(suffix, style: context.tt.titleMedium!.copyWith(color: c.text3)),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(item.name, style: context.tt.headlineSmall),
        if (item.plName != null) ...[
          const SizedBox(height: 8),
          PlName(item.plName!, large: true),
          const SizedBox(height: 14),
          BigButton(
            label: context.s('itemShowStaff'),
            icon: Icons.record_voice_over_rounded,
            kind: BtnKind.secondary,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StaffScreen(item: item), fullscreenDialog: true)),
          ),
          if (!s.isWatched(item.plName!)) ...[
            const SizedBox(height: 10),
            BigButton(
              label: context.s('watchAdd'),
              icon: Icons.notifications_active_rounded,
              kind: BtnKind.secondary,
              onPressed: () {
                s.addWatch(WatchItem(id: newId(), name: item.name, pl: item.plName!, term: true));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s('watchAdded', {'name': item.name}))));
              },
            ),
          ],
        ],
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: Text(context.s('itemQty'), style: context.tt.titleMedium)),
          Stepper2(value: _qty.toDouble(), onChanged: (v) => setState(() => _qty = v.toInt())),
        ]),
        ..._where(context, s),
        if (item.dealId == null && _picked == null && s.dealsFor(item.plName).isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(context.s('matchPickTitle', {'name': item.name}), style: context.tt.titleMedium),
          const SizedBox(height: 4),
          Text(context.s('matchPickSub'), style: context.tt.bodyMedium),
          const SizedBox(height: 10),
          for (final d in s.dealsFor(item.plName).take(4))
            DealPickRow(
              deal: d,
              onTap: () => setState(() {
                _picked = d;
                _chain = d.chain;
                _pl.text = s.dealPrice(d).toStringAsFixed(2).replaceAll('.', ',');
              }),
            ),
        ],
        const SizedBox(height: 20),
        Text(context.s('itemPricePl'), style: context.tt.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _pl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: context.tt.headlineSmall,
          decoration: dec('zł  ${context.s('itemEach')}'),
          onChanged: (_) => setState(() {}),
        ),
        if (plEur != null) Padding(padding: const EdgeInsets.fromLTRB(4, 6, 0, 0), child: Text('≈ ${eur(plEur, lang)}', style: context.tt.bodyMedium)),
        if (plRef != null)
          refLine(
            context.s('refPl', {'v': zl(plRef.unitMedian, lang), 'u': unitName(plRef.unit), 'src': plRef.source, 'ex': plRef.exName, 'p': zl(plRef.exPrice, lang)}),
            pl == null ? plRef.exPrice.toStringAsFixed(2).replaceAll('.', ',') : null,
            _pl,
          ),
        const SizedBox(height: 18),
        Text(context.s('itemPriceLt'), style: context.tt.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _lt,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: context.tt.headlineSmall,
          decoration: dec('€  ${context.s('itemEach')}').copyWith(hintText: ltEst == null ? '0,00' : '≈ ${ltEst.toStringAsFixed(2).replaceAll('.', ',')}'),
          onChanged: (_) => setState(() {}),
        ),
        if (ltRef != null)
          refLine(
            context.s(ltEst == null ? 'refLt' : 'refLtPack', {'v': eur(ltRef.unitMedian, lang), 'u': unitName(ltRef.unit), 'src': ltRef.source, 'p': eur(ltEst ?? 0, lang)}),
            lt == null && ltEst != null ? ltEst.toStringAsFixed(2).replaceAll('.', ',') : null,
            _lt,
          ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: saving == null
              ? const SizedBox.shrink()
              : Panel(
                  key: ValueKey(saving > 0),
                  color: saving > 0.009 ? c.goodSoft : c.badSoft,
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(saving > 0.009 ? Icons.savings_rounded : Icons.info_rounded, color: saving > 0.009 ? c.good : c.bad, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        saving > 0.009 ? context.s('itemSaving', {'v': eur(saving, lang)}) : context.s('itemCheaperLt', {'v': eur(-saving, lang)}),
                        style: context.tt.titleLarge!.copyWith(color: saving > 0.009 ? c.good : c.bad),
                      ),
                    ),
                  ]),
                ),
        ),
        const SizedBox(height: 20),
        BigButton(label: context.s('save'), icon: Icons.check_rounded, onPressed: _save),
        const SizedBox(height: 10),
        BigButton(
          label: context.s('itemDelete'),
          icon: Icons.delete_outline_rounded,
          kind: BtnKind.danger,
          onPressed: () {
            s.removeItem(item.id);
            Navigator.pop(context);
          },
        ),
      ]),
    );
  }
}

/// Full-screen Polish text to show a shop assistant. Deliberately black on white.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key, required this.item});
  final ListItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(context.s('staffHint'), style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF666666)))),
                IconButton(icon: const Icon(Icons.close_rounded, size: 32, color: Brand.ink), onPressed: () => Navigator.pop(context), tooltip: context.s('close')),
              ]),
              const Spacer(),
              const Text('Przepraszam, gdzie znajdę:',
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
              const SizedBox(height: 14),
              Text(item.plName ?? item.name,
                  style: const TextStyle(fontFamily: 'Manrope', fontSize: 46, height: 1.05, fontWeight: FontWeight.w800, color: Brand.ink, letterSpacing: -1)),
              if (item.qty > 1) ...[
                const SizedBox(height: 14),
                Text('${item.qty} szt.', style: const TextStyle(fontFamily: 'Inter', fontSize: 22, color: Color(0xFF444444))),
              ],
              if (item.barcode != null) ...[
                const SizedBox(height: 14),
                Text('EAN ${item.barcode}', style: const TextStyle(fontFamily: 'Inter', fontSize: 20, letterSpacing: 2, color: Color(0xFF333333))),
              ],
              const Spacer(),
              const FlagRibbon(width: 64, height: 4),
              const SizedBox(height: 10),
              Text(context.s('staffTranslation', {'name': item.name}), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF666666))),
            ]),
          ),
        ),
      );
}
