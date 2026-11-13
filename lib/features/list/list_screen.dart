import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../main.dart';
import '../../widgets/ui.dart';
import '../scan/scan_screen.dart';
import '../trip/trip_screen.dart' show ChainDot;
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
      child: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Row(children: [
                Expanded(child: Text(context.s('listTitle'), style: context.tt.headlineMedium)),
                if (s.items.any((e) => e.checked))
                  TextButton(onPressed: s.clearChecked, child: Text(context.s('listClearChecked'), style: context.tt.labelMedium)),
              ]),
              const SizedBox(height: 10),
              const _TripLine(),
              const SizedBox(height: 14),
              if (s.items.isEmpty)
                const _Empty()
              else ...[
                const _Summary(),
                for (final e in groups.entries) ...[
                  _GroupHeader(chain: e.key, items: e.value),
                  for (final i in e.value) _ItemRow(item: i, index: s.items.indexOf(i)),
                ],
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
          child: Row(children: [
            Expanded(flex: 5, child: BigButton(label: context.s('listAdd'), icon: Icons.add_rounded, onPressed: () => _add(context))),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: BigButton(label: context.s('listScan'), icon: Icons.qr_code_scanner_rounded, kind: BtnKind.secondary, onPressed: () => _scan(context))),
          ]),
        ),
      ]),
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
      return Panel(
        color: c.warnSoft,
        onTap: () => shellTab.value = 0,
        child: Row(children: [
          Icon(Icons.storefront_rounded, color: c.warn, size: 28),
          const SizedBox(width: 14),
          Expanded(child: Text(context.s('listNoTrip'), style: context.tt.bodyLarge)),
          Icon(Icons.chevron_right_rounded, color: c.text3),
        ]),
      );
    }
    final shops = s.tripChains.map((x) => chainById(x)?.name ?? x).join(', ');
    return Panel(
      onTap: () => shellTab.value = 0,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        Icon(Icons.storefront_rounded, color: c.text2),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s('listPricesAt'), style: context.tt.bodySmall),
            Text('$shops · ${s.dest.name}', style: context.tt.titleMedium),
          ]),
        ),
        Text(context.s('edit'), style: context.tt.labelMedium!.copyWith(color: Brand.yellow)),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
        child: Column(children: [
          IconTile(Icons.shopping_bag_rounded, size: 96, bg: Brand.yellow.withValues(alpha: .16), color: Brand.yellow),
          const SizedBox(height: 24),
          Text(context.s('listEmpty'), textAlign: TextAlign.center, style: context.tt.headlineMedium),
          const SizedBox(height: 10),
          Text(context.s('listEmptySub'), textAlign: TextAlign.center, style: context.tt.bodyLarge!.copyWith(color: context.c.text2)),
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
      return Panel(
        color: plOnly.n > 0 ? null : c.warnSoft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (plOnly.n > 0) ...[
            Text(context.s('listPlOnly'), style: context.tt.bodyMedium),
            Text(eur(plOnly.plEur, lang), style: context.tt.headlineSmall),
            const SizedBox(height: 6),
          ],
          Text(context.s(plOnly.n > 0 ? 'listPlOnlySub' : 'listNoPrices', {'n': plOnly.n, 'm': s.items.length}), style: context.tt.bodyMedium),
        ]),
      );
    }
    Widget col(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: context.tt.bodyMedium),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: context.tt.headlineSmall!.copyWith(color: color))),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          col(context.s('listInPl'), eur(b.plEur, lang)),
          col(context.s('listInLt'), eur(b.ltEur, lang)),
          col(context.s('listSave'), eur(b.saving, lang), color: c.good),
        ]),
        if (b.missing > 0) ...[
          const SizedBox(height: 12),
          Text(context.s('listMissing', {'n': b.missing}), style: context.tt.bodyMedium),
        ],
      ]),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.chain, required this.items});
  final String? chain;
  final List<ListItem> items;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(children: [
        if (ch != null) ...[ChainDot(ch, size: 28), const SizedBox(width: 10)],
        Expanded(child: Text(ch?.name ?? context.s('listNoShop'), style: context.tt.titleLarge)),
        if (sum > 0) Text('${unknown ? '≥ ' : ''}${zl(sum, context.lang)}', style: context.tt.titleMedium!.copyWith(color: context.c.text2)),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.index});
  final ListItem item;
  final int index;

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

    Widget priceLine() {
      if (pl == null) {
        final ch = s.chainOf(item);
        return Pill(
          ch == null ? context.s('itemAddPrices') : context.s('itemNoPriceAt', {'shop': chainById(ch)?.name ?? ch}),
          fg: Brand.ink,
          bg: Brand.yellow,
          icon: Icons.edit_rounded,
        );
      }
      final good = (saving ?? 0) > 0.009;
      final bad = (saving ?? 0) < -0.009;
      return Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${approx(pl)}${zl(pl.price, lang)} · ${kind(pl)}', style: context.tt.bodyMedium),
        if (lt == null)
          Pill(context.s('itemNeedLt'), fg: Brand.ink, bg: Brand.yellow, icon: Icons.edit_rounded)
        else if (saving != null)
          Pill(
            good ? context.s('itemSaving', {'v': eur(saving, lang)}) : bad ? context.s('itemCheaperLt', {'v': eur(-saving, lang)}) : context.s('itemSame'),
            fg: good ? c.good : bad ? c.bad : c.text2,
            bg: good ? c.goodSoft : bad ? c.badSoft : c.raised,
          ),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(color: c.badSoft, borderRadius: BorderRadius.circular(24)),
          child: Icon(Icons.delete_rounded, color: c.bad, size: 28),
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
        child: Panel(
          onTap: () => showItemSheet(context, item),
          padding: const EdgeInsets.fromLTRB(10, 14, 18, 14),
          child: Row(children: [
            Semantics(
              checked: done,
              label: item.name,
              child: IconButton(
                iconSize: 32,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  s.changeItem(item.id, (i) => i.checked = !i.checked);
                },
                icon: Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined, color: done ? c.good : c.text3),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Opacity(
                opacity: done ? .5 : 1,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    item.qty > 1 ? '${item.qty} × ${item.name}' : item.name,
                    style: context.tt.titleMedium!.copyWith(decoration: done ? TextDecoration.lineThrough : null),
                  ),
                  if (item.plName != null) ...[const SizedBox(height: 4), PlName(item.plName!)],
                  const SizedBox(height: 10),
                  priceLine(),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
