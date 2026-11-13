import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../widgets/ui.dart';
import 'deal_pick.dart';
import '../scan/scan_screen.dart';
import 'add_item_screen.dart';
import 'item_sheet.dart';
import '../plan/plan_screen.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({super.key});

  void _add(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddItemScreen(), fullscreenDialog: true));
  void _scan(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Expanded(
          child: s.items.isEmpty
              ? _Empty(onAdd: () => _add(context), onScan: () => _scan(context))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Row(children: [
                      Expanded(child: Text(context.s('listTitle'), style: context.tt.headlineMedium)),
                      IconButton.filledTonal(
                        tooltip: context.s('planTitle'),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanScreen())),
                        icon: const Icon(Icons.alt_route_rounded),
                      ),
                      if (s.items.any((e) => e.checked))
                        TextButton(onPressed: s.clearChecked, child: Text(context.s('listClearChecked'), style: context.tt.labelMedium)),
                    ]),
                    const SizedBox(height: 16),
                    const _Summary(),
                    const SizedBox(height: 16),
                    for (var i = 0; i < s.items.length; i++) _ItemRow(item: s.items[i], index: i),
                  ],
                ),
        ),
        if (s.items.isNotEmpty)
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

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd, required this.onScan});
  final VoidCallback onAdd, onScan;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        children: [
          Center(child: IconTile(Icons.shopping_bag_rounded, size: 96, bg: Brand.yellow.withValues(alpha: .16), color: Brand.yellow)),
          const SizedBox(height: 24),
          Text(context.s('listEmpty'), textAlign: TextAlign.center, style: context.tt.headlineMedium),
          const SizedBox(height: 10),
          Text(context.s('listEmptySub'), textAlign: TextAlign.center, style: context.tt.bodyLarge!.copyWith(color: context.c.text2)),
          const SizedBox(height: 28),
          BigButton(label: context.s('listAdd'), icon: Icons.add_rounded, onPressed: onAdd),
          const SizedBox(height: 12),
          BigButton(label: context.s('actionScan'), icon: Icons.qr_code_scanner_rounded, kind: BtnKind.secondary, onPressed: onScan),
        ],
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
    if (b.priced == 0 && plOnly.n > 0) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.s('listPlOnly'), style: context.tt.bodyMedium),
          const SizedBox(height: 2),
          Text(eur(plOnly.plEur, lang), style: context.tt.headlineSmall),
          const SizedBox(height: 8),
          Text(context.s('listPlOnlySub', {'n': plOnly.n, 'm': s.items.length}), style: context.tt.bodyMedium),
        ]),
      );
    }
    if (b.priced == 0) {
      return Panel(
        color: c.warnSoft,
        child: Row(children: [
          Icon(Icons.edit_note_rounded, color: c.warn, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Text(context.s('listNoPrices'), style: context.tt.bodyLarge)),
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
    Widget priceLine() {
      if (pl != null && lt == null) {
        final shop = item.chain == null ? null : chainById(item.chain!)?.name;
        return Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(['${approx(pl)}${zl(pl.price, lang)}', ?shop].join(' · '), style: context.tt.bodyMedium),
          Pill(context.s('itemNeedLt'), fg: Brand.ink, bg: Brand.yellow, icon: Icons.edit_rounded),
        ]);
      }
      if (pl == null || lt == null) {
        final m = s.dealsFor(item.plName);
        if (m.isNotEmpty) return DealCountPill(m);
        return Pill(context.s('itemAddPrices'), fg: Brand.ink, bg: Brand.yellow, icon: Icons.edit_rounded);
      }
      final good = (saving ?? 0) > 0.009;
      final bad = (saving ?? 0) < -0.009;
      return Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${approx(pl)}${zl(pl.price, lang)} · ${approx(lt)}${eur(lt.price, lang)} LT', style: context.tt.bodyMedium),
        if (saving != null)
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
