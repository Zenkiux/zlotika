import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../services/deals.dart';
import '../../widgets/ui.dart';

/// "JACOBS · Kawa mielona Krönung · Limit: 4 szt." → "Kawa mielona Krönung · JACOBS".
String shortDealName(String name) {
  final p = name.split(' · ');
  return p.length > 1 ? '${p[1]} · ${p[0]}' : name;
}

/// One deal as a tappable row: shop, Polish name, price, how long it lasts.
class DealPickRow extends StatelessWidget {
  const DealPickRow({super.key, required this.deal, required this.onTap});
  final Deal deal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final chain = chainById(deal.chain);
    final price = s.dealPrice(deal);
    final eurV = s.toEur(price);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Container(
            width: 8,
            height: 44,
            decoration: BoxDecoration(color: chain?.color ?? c.text3, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chain?.name ?? deal.chain, style: context.tt.titleMedium),
              const SizedBox(height: 2),
              Text(shortDealName(deal.name), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 4, children: [
                if (deal.validTo != null)
                  Text(context.s('dealsUntil', {'date': dayMonth(DateTime.parse(deal.validTo!), lang)}), style: context.tt.bodySmall),
                if (deal.card == true) Text(chain?.card ?? context.s('dealsCardGeneric'), style: context.tt.bodySmall!.copyWith(color: c.bad)),
                if (deal.ocr) Text(context.s('dealOcr'), style: context.tt.bodySmall!.copyWith(color: c.warn)),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(zl(price, lang), style: context.tt.titleLarge),
            if (eurV != null) Text('≈ ${eur(eurV, lang)}', style: context.tt.bodySmall),
          ]),
        ]),
      ),
    );
  }
}

/// Bottom sheet: "which of this week's deals will you buy?" Returns the deal,
/// or null when the shopper adds the item without a price.
Future<Deal?> pickDeal(BuildContext context, String title, List<Deal> deals) => showSheet<Deal>(
      context,
      (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: ctx.tt.headlineSmall),
          const SizedBox(height: 6),
          Text(ctx.s('matchPickSub'), style: ctx.tt.bodyLarge),
          const SizedBox(height: 16),
          for (final d in deals) DealPickRow(deal: d, onTap: () => Navigator.pop(ctx, d)),
          const SizedBox(height: 8),
          BigButton(label: ctx.s('matchNone'), icon: Icons.add_rounded, kind: BtnKind.secondary, onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    );

/// Pill for a list line or a dictionary row: "3 deals from 4,49 zł".
class DealCountPill extends StatelessWidget {
  const DealCountPill(this.deals, {super.key});
  final List<Deal> deals;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final from = deals.map(s.dealPrice).reduce((a, b) => a < b ? a : b);
    return Pill(
      context.s('matchCount', {'n': deals.length, 'v': zl(from, context.lang)}),
      fg: context.c.good,
      bg: context.c.goodSoft,
      icon: Icons.local_offer_rounded,
    );
  }
}

/// Attaches a picked deal to a list line.
void applyDeal(ListItem i, Deal d, double price) {
  i.plPrice = price;
  i.chain = d.chain;
  i.dealId = d.id;
}
