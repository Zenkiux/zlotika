import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../widgets/ui.dart';
import 'deal_pick.dart';
import 'add_item_screen.dart' show newId;
import '../report/report_screen.dart';

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
  late String? _chain = widget.item.chain; // null = wherever it's cheapest on this trip
  late String? _dealId = widget.item.dealId;

  @override
  void dispose() {
    _pl.dispose();
    _lt.dispose();
    super.dispose();
  }

  /// The line as it would be saved, so the sheet shows the same numbers as the list.
  ListItem _draft() => ListItem(
        id: widget.item.id,
        name: widget.item.name,
        plName: widget.item.plName,
        qty: _qty,
        plPrice: parseAmount(_pl.text),
        ltPrice: parseAmount(_lt.text),
        barcode: widget.item.barcode,
        chain: _chain,
        dealId: _dealId,
      );

  void _save() {
    final d = _draft();
    AppScope.read(context).changeItem(widget.item.id, (i) {
      i.qty = d.qty;
      i.chain = d.chain;
      i.dealId = d.dealId;
      i.plPrice = d.plPrice;
      i.ltPrice = d.ltPrice;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final item = widget.item;
    final draft = _draft();
    final typedPl = draft.plPrice;
    final est = s.plFor(draft);
    final chosen = s.dealOf(draft);
    final deals = s.itemDeals(draft);
    final elsewhere = s.cheaperElsewhere(draft);
    final ltEst = s.ltFor(ListItem(id: '', name: item.name, plName: item.plName, chain: _chain, dealId: _dealId)); // without the typed LT price
    final saving = s.itemSaving(draft);
    final ltRef = s.ltRef(item);
    final shopName = chainById(s.chainOf(draft) ?? '')?.name;
    String unitName(String u) => u == 'units' ? context.s('unitPiece') : u;
    String fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

    // Unit always visible (suffixText only shows while focused).
    InputDecoration dec(String suffix, String hint) => InputDecoration(
          hintText: hint,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Text(suffix, style: context.tt.titleMedium!.copyWith(color: c.text3)),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        );

    Widget note(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 18, color: c.text3),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: context.tt.bodySmall)),
          ]),
        );

    // What the Polish price is based on, in words.
    String? plBasis() {
      if (est == null || typedPl != null) return null;
      return switch (est.kind) {
        PriceKind.deal => context.s('itemUsingDeal', {'v': zl(est.price, lang), 'shop': chainById(chosen!.chain)?.name ?? chosen.chain}),
        PriceKind.ref => context.s('itemUsingRef', {'v': zl(est.price, lang), 'src': est.ref!.source, 'ex': est.ref!.exName}),
        PriceKind.last => context.s('itemUsingLast', {'v': zl(est.price, lang), 'd': s.lastPrice(item)?.date ?? ''}),
        PriceKind.typed => null,
      };
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(item.name, style: context.tt.headlineSmall),
        if (item.plName != null) ...[
          const SizedBox(height: 8),
          PlName(item.plName!, large: true),
          const SizedBox(height: 6),
          Wrap(spacing: 4, children: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StaffScreen(item: item), fullscreenDialog: true)),
              icon: const Icon(Icons.record_voice_over_rounded, size: 20),
              label: Text(context.s('itemShowStaff')),
            ),
            if (!s.isWatched(item.plName!))
              TextButton.icon(
                onPressed: () {
                  s.addWatch(WatchItem(id: newId(), name: item.name, pl: item.plName!, term: true));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s('watchAdded', {'name': item.name}))));
                  setState(() {});
                },
                icon: const Icon(Icons.notifications_active_rounded, size: 20),
                label: Text(context.s('watchAdd')),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text(context.s('itemQty'), style: context.tt.titleMedium)),
          Stepper2(value: _qty.toDouble(), onChanged: (v) => setState(() => _qty = v.toInt())),
        ]),
        if (s.tripChains.length > 1) ...[
          const SizedBox(height: 20),
          Text(context.s('itemWhere'), style: context.tt.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: Text(context.s('itemWhereAuto')), selected: !s.inTrip(_chain), onSelected: (_) => setState(() => _chain = null)),
            for (final id in s.tripChains)
              ChoiceChip(
                label: Text(chainById(id)?.name ?? id),
                selected: _chain == id,
                avatar: CircleAvatar(backgroundColor: chainById(id)?.color, radius: 6),
                onSelected: (_) => setState(() => _chain = id),
              ),
          ]),
        ],

        // ── Polish price
        const SizedBox(height: 22),
        Text(context.s('itemPricePl'), style: context.tt.titleMedium),
        if (deals.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(context.s('itemDealsHere'), style: context.tt.bodyMedium),
          const SizedBox(height: 10),
          for (final d in deals.take(4))
            Stack(children: [
              DealPickRow(
                deal: d,
                onTap: () => setState(() {
                  _dealId = d.id;
                  if (s.inTrip(_chain) && _chain != d.chain) _chain = d.chain;
                  _pl.clear();
                }),
              ),
              if (typedPl == null && chosen?.id == d.id)
                const Positioned(right: 6, top: 6, child: Icon(Icons.check_circle_rounded, color: Brand.yellow, size: 22)),
            ]),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _pl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: context.tt.headlineSmall,
          decoration: dec('zł  ${context.s('itemEach')}', est != null && typedPl == null ? '≈ ${fmt(est.price)}' : '0,00'),
          onChanged: (_) => setState(() {}),
        ),
        if (plBasis() case final b?) note(b),
        if (chosen != null && (chosen.crowd || chosen.ocr)) note(context.s(chosen.crowd ? 'priceCrowd' : 'priceLeaflet', {'d': chosen.validFrom ?? ''})),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportPriceScreen(item: item))),
            icon: const Icon(Icons.add_a_photo_rounded, size: 20),
            label: Text(context.s('itemReport')),
          ),
        ),
        if (est == null) note(context.s('itemNoPlPrice', {'shop': shopName ?? '—'})),
        if (est != null && s.toEur(est.price) != null)
          Padding(padding: const EdgeInsets.fromLTRB(4, 6, 0, 0), child: Text('≈ ${eur(s.toEur(est.price)!, lang)} ${context.s('itemEach')}', style: context.tt.bodyMedium)),
        if (elsewhere.isNotEmpty) ...[
          const SizedBox(height: 14),
          Panel(
            color: c.raised,
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('itemElsewhere'), style: context.tt.titleMedium),
              for (final d in elsewhere)
                Row(children: [
                  Expanded(
                    child: Text('${chainById(d.chain)?.name ?? d.chain}: ${zl(s.dealPrice(d), lang)} · ${shortDealName(d.name)}',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium),
                  ),
                  TextButton(
                    onPressed: () {
                      s.addTripChain(d.chain);
                      setState(() => _dealId = d.id);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s('itemAddedStop', {'chain': chainById(d.chain)?.name ?? d.chain}))));
                    },
                    child: Text(context.s('itemAddStop')),
                  ),
                ]),
            ]),
          ),
        ],

        // ── Lithuanian price
        const SizedBox(height: 22),
        Text(context.s('itemPriceLt'), style: context.tt.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _lt,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: context.tt.headlineSmall,
          decoration: dec('€  ${context.s('itemEach')}', ltEst == null ? '0,00' : '≈ ${fmt(ltEst.price)}'),
          onChanged: (_) => setState(() {}),
        ),
        if (ltRef != null && parseAmount(_lt.text) == null)
          note(context.s(ltEst == null ? 'refLt' : 'refLtPack', {'v': eur(ltRef.unitMedian, lang), 'u': unitName(ltRef.unit), 'src': ltRef.source, 'p': eur(ltEst?.price ?? 0, lang)})),
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
