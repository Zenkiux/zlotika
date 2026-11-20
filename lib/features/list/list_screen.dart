import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../main.dart' show shellTab, Tabs;
import '../more/more_screen.dart' show SettingsButton;
import '../../widgets/ui.dart';
import '../scan/scan_screen.dart';
import 'add_item_screen.dart';
import 'item_sheet.dart';

/// The shopping list, grouped by the trip's shops. Prices come only from those shops.
class ListScreen extends StatelessWidget {
  const ListScreen({super.key});

  void _add(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddItemScreen(), fullscreenDialog: true));
  void _scan(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;

    // Group lines by the shop they'll be bought at, in the trip's shop order.
    final groups = <String?, List<ListItem>>{for (final ch in s.tripChains) ch: []};
    for (final i in s.items) {
      groups.putIfAbsent(s.chainOf(i), () => []).add(i);
    }
    groups.removeWhere((_, v) => v.isEmpty);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          PageHeader(context.s('listTitle'), subtitle: context.s('listHeaderSub'), trailing: const SettingsButton()),
          if (s.items.isNotEmpty) ...[const _Summary(), const SizedBox(height: 14)],
          Row(children: [
            Expanded(
              child: Press(
                onTap: () => _add(context),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                  child: Row(children: [
                    Icon(Icons.add_rounded, size: 20, color: c.accentText),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.s('addPlaceholder'), overflow: TextOverflow.ellipsis, style: context.tt.bodyLarge!.copyWith(color: c.text3, fontSize: 14.5))),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Press(
              onTap: () => _scan(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                child: Icon(Icons.qr_code_scanner_rounded, size: 21, color: c.text),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          const _TripLine(),
          if (s.items.isEmpty)
            const _Empty()
          else
            for (final e in groups.entries) ...[
              _GroupHeader(chain: e.key, items: e.value),
              RowGroup(children: [
                for (var k = 0; k < e.value.length; k++) _ItemRow(item: e.value[k], index: s.items.indexOf(e.value[k]), last: k == e.value.length - 1),
              ]),
            ],
          if (s.items.any((e) => e.checked)) ...[
            const SizedBox(height: 16),
            BigButton(label: context.s('listClearChecked'), icon: Icons.done_all_rounded, kind: BtnKind.ghost, onPressed: s.clearChecked),
          ],
        ],
      ),
    );
  }
}

/// Which trip these prices are for; tapping goes to the trip.
class _TripLine extends StatelessWidget {
  const _TripLine();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    if (!s.tripReady || s.tripChains.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GestureDetector(
          onTap: () => shellTab.value = Tabs.trip,
          child: AlertBanner(title: context.s('listNoTrip'), tone: Tone.warn, icon: Icons.storefront_outlined),
        ),
      );
    }
    final shops = s.tripChains.map((x) => chainById(x)?.name ?? x).join(', ');
    return GestureDetector(
      onTap: () => shellTab.value = Tabs.trip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(children: [
          Icon(Icons.storefront_outlined, size: 15, color: c.text3),
          const SizedBox(width: 6),
          Expanded(child: Text('${context.s('listPricesAt')} $shops · ${s.dest.name}', style: context.tt.bodySmall, overflow: TextOverflow.ellipsis)),
          Text(context.s('edit'), style: context.tt.labelMedium!.copyWith(color: c.accentText)),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 36, 8, 8),
        child: Column(children: [
          const IconTile(Icons.shopping_bag_outlined, size: 64, tone: Tone.accent),
          const SizedBox(height: 18),
          Text(context.s('listEmpty'), textAlign: TextAlign.center, style: context.tt.headlineSmall),
          const SizedBox(height: 8),
          Text(context.s('listEmptySub'), textAlign: TextAlign.center, style: context.tt.bodyMedium),
        ]),
      );
}

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final b = s.basket();
    final plOnly = s.plOnlyTotal();
    if (b.priced == 0) {
      return Pair(
        StatCard(label: context.s('totalPl'), value: plOnly.n > 0 ? eur(plOnly.plEur, lang) : '—', sub: context.s('pricedOf', {'n': plOnly.n, 'm': s.items.length})),
        StatCard(label: context.s('estSaving'), value: '—', sub: context.s('needLtShort')),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Pair(
        StatCard(label: context.s('totalPl'), value: eur(b.plEur, lang), sub: 'LT ≈ ${eur(b.ltEur, lang)}'),
        StatCard(label: context.s('estSaving'), value: eurSigned(b.saving, lang), valueColor: b.saving >= 0 ? c.good : c.bad, sub: context.s('pricedOf', {'n': b.priced, 'm': b.priced + b.missing})),
      ),
      if (b.missing > 0) Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(context.s('listMissing', {'n': b.missing}), style: context.tt.bodySmall)),
    ]);
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.chain, required this.items});
  final String? chain;
  final List<ListItem> items;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final ch = chain == null ? null : chainById(chain!);
    var sum = 0.0;
    var unknown = false;
    for (final i in items.where((e) => !e.checked)) {
      final p = s.plFor(i)?.price;
      if (p == null) {
        unknown = true;
      } else {
        sum += p * i.qty;
      }
    }
    final label = context.tt.labelSmall!.copyWith(color: c.text3, letterSpacing: .66, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        if (ch != null) ...[Dot(ch.color), const SizedBox(width: 7)],
        Expanded(child: Text((ch?.name ?? context.s('listNoShop')).toUpperCase(), style: label)),
        Text(sum > 0 ? '${unknown ? '≥ ' : ''}${zl(sum, context.lang)} · ${items.length}' : '${items.length}', style: label),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.index, this.last = false});
  final ListItem item;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final saving = s.itemSaving(item);
    final done = item.checked;

    final pl = s.plFor(item), lt = s.ltFor(item);
    String approx(Est e) => e.kind == PriceKind.ref || e.kind == PriceKind.last ? '≈ ' : '';
    final deal = s.dealOf(item);
    String kind(Est e) => deal != null && deal.crowd ? context.s('priceCrowd', {'d': deal.validFrom ?? ''}) : context.s(switch (e.kind) {
          PriceKind.deal => 'priceDeal',
          PriceKind.ref => 'priceUsual',
          PriceKind.last => 'priceLast',
          PriceKind.typed => 'priceTyped',
        });

    Widget? chip() {
      if (pl == null) {
        final ch = s.chainOf(item);
        return Pill(ch == null ? context.s('itemAddPrices') : context.s('itemNoPriceAt', {'shop': chainById(ch)?.name ?? ch}), tone: Tone.accent, icon: Icons.edit_outlined);
      }
      if (lt == null) return Pill(context.s('itemNeedLt'), tone: Tone.accent, icon: Icons.edit_outlined);
      if (saving == null) return null;
      final good = saving > 0.009, bad = saving < -0.009;
      return Pill(
        good ? context.s('itemSaving', {'v': eur(saving, lang)}) : bad ? context.s('itemCheaperLt', {'v': eur(-saving, lang)}) : context.s('itemSame'),
        tone: good ? Tone.good : bad ? Tone.bad : Tone.neutral,
      );
    }

    final total = pl == null ? null : pl.price * item.qty;
    final totalEur = total == null ? null : s.toEur(total);
    final ch = chip();

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: c.badSoft,
        child: Icon(Icons.delete_outline_rounded, color: c.bad, size: 24),
      ),
      onDismissed: (_) {
        s.removeItem(item.id);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(context.s('itemRemoved', {'name': item.name})),
            action: SnackBarAction(label: context.s('undo'), textColor: Brand.yellow, onPressed: () => s.restoreItem(item, index)),
          ));
      },
      child: InkWell(
        onTap: () => showItemSheet(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                checked: done,
                label: item.name,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    s.changeItem(item.id, (i) => i.checked = !i.checked);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 2, 12, 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? c.good : Colors.transparent,
                        border: Border.all(color: done ? c.good : c.lineStrong, width: 2),
                      ),
                      child: done ? const Icon(Icons.check_rounded, size: 15, color: Color(0xFF08120D)) : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Opacity(
                  opacity: done ? .5 : 1,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: item.name),
                        if (item.qty > 1) TextSpan(text: '  ×${item.qty}', style: TextStyle(color: c.text2, fontWeight: FontWeight.w500)),
                      ]),
                      style: context.tt.titleMedium!.copyWith(decoration: done ? TextDecoration.lineThrough : null),
                    ),
                    if (item.plName != null) PlName(item.plName!, maxLines: 1),
                    if (pl != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(kind(pl), style: context.tt.bodySmall)),
                    if (ch != null && !done) Padding(padding: const EdgeInsets.only(top: 7), child: ch),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (total != null) ...[
                  Text('${approx(pl!)}${zl(total, lang)}', style: context.tt.titleLarge!.copyWith(fontSize: 15.5, fontFeatures: const [FontFeature.tabularFigures()])),
                  if (totalEur != null) Text(eur(totalEur, lang), style: context.tt.bodySmall!.copyWith(color: c.text2)),
                ] else if (lt != null)
                  Text('LT ≈ ${eur(lt.price * item.qty, lang)}', style: context.tt.bodySmall!.copyWith(color: c.text2)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
