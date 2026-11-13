import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../data/dictionary.dart';
import '../../services/deals.dart';
import '../../widgets/ui.dart';
import '../list/add_item_screen.dart' show newId;
import '../list/deal_pick.dart' show showAddedSnack;
import 'leaflet_reader.dart';

String agoText(BuildContext context, DateTime t) {
  final h = DateTime.now().difference(t).inHours;
  if (h < 1) return context.s('agoNow');
  if (h < 24) return context.s('agoH', {'n': h});
  return context.s('agoD', {'n': h ~/ 24});
}

String? dealTranslation(BuildContext context, Deal d) {
  final t = guessTerm(d.name);
  if (t == null) return null;
  return context.lang == Lang.lt ? t.lt : t.en;
}

class ChainBadge extends StatelessWidget {
  const ChainBadge(this.chainId, {super.key, this.size = 44});
  final String chainId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = chainById(chainId);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c?.color ?? context.c.raised, borderRadius: BorderRadius.circular(size * .3)),
      child: Text((c?.name ?? chainId).substring(0, 1),
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: size * .45, color: c?.ink ?? context.c.text)),
    );
  }
}

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _q = TextEditingController();
  String? _chain; // a single chain, or null
  bool? _mine; // only the trip's shops; defaults to yes when a trip is set
  int _view = 0; // 0 deals, 1 leaflets

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final all = s.deals.where((d) => !d.crowd).toList();
    final query = foldText(_q.text.trim());
    final present = {for (final d in all) d.chain};
    final mine = _chain == null && (_mine ?? s.tripChains.isNotEmpty);
    final list = all.where((d) {
      if (_chain != null && d.chain != _chain) return false;
      if (mine && !s.tripChains.contains(d.chain)) return false;
      if (query.isEmpty) return true;
      final tr = guessTerm(d.name);
      final hay = foldText('${d.name} ${tr?.lt ?? ''} ${tr?.en ?? ''} ${chainById(d.chain)?.name ?? ''}');
      return query.split(RegExp(r'\s+')).every(hay.contains);
    }).toList()
      ..sort((a, b) => (b.discountPct ?? 0).compareTo(a.discountPct ?? 0));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Brand.ink,
        backgroundColor: Brand.yellow,
        onRefresh: s.refreshFeed,
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverList.list(children: [
              Text(context.s('dealsTitle'), style: context.tt.headlineMedium),
              const SizedBox(height: 4),
              Text(
                s.feed != null ? context.s('dealsUpdated', {'ago': agoText(context, s.feed!.generatedAt)}) : context.s('leafletsSub'),
                style: context.tt.bodyMedium,
              ),
              const SizedBox(height: 16),
              Segmented<int>(
                value: _view,
                options: [(0, context.s('dealsTabDeals')), (1, context.s('dealsTabLeaflets'))],
                onChanged: (v) => setState(() => _view = v),
              ),
              const SizedBox(height: 14),
            ]),
          ),
          if (_view == 1)
            const _Leaflets()
          else if (all.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList.list(children: [
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (s.feedLoading) ...[
                      const LinearProgressIndicator(color: Brand.yellow),
                      const SizedBox(height: 14),
                      Text(context.s('dealsLoading'), style: context.tt.titleMedium),
                    ] else ...[
                      Text(context.s('dealsEmpty'), style: context.tt.titleLarge),
                      const SizedBox(height: 6),
                      Text(context.s('dealsEmptySub'), style: context.tt.bodyLarge!.copyWith(color: c.text2)),
                      const SizedBox(height: 16),
                      BigButton(label: context.s('dealsShowLeaflets'), icon: Icons.menu_book_rounded, onPressed: () => setState(() => _view = 1)),
                    ],
                  ]),
                ),
              ]),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.list(children: [
                TextField(
                  controller: _q,
                  style: context.tt.titleMedium,
                  decoration: InputDecoration(
                    hintText: context.s('dealsSearch'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(_q.clear)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
              ]),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (s.tripChains.isNotEmpty)
                      _ChainChip(label: context.s('dealsMine'), selected: mine, onTap: () => setState(() {
                            _chain = null;
                            _mine = true;
                          })),
                    _ChainChip(label: context.s('dealsAll'), selected: _chain == null && !mine, onTap: () => setState(() {
                          _chain = null;
                          _mine = false;
                        })),
                    for (final ch in chains.where((x) => present.contains(x.id)))
                      _ChainChip(label: ch.name, color: ch.color, selected: _chain == ch.id, onTap: () => setState(() => _chain = _chain == ch.id ? null : ch.id)),
                  ],
                ),
              ),
            ),
            if (list.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(28),
                sliver: SliverToBoxAdapter(child: Text(context.s('dealsNone'), textAlign: TextAlign.center, style: context.tt.titleMedium)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList.builder(itemCount: list.length, itemBuilder: (_, i) => DealCard(deal: list[i])),
              ),
          ],
        ]),
      ),
    );
  }
}

class _ChainChip extends StatelessWidget {
  const _ChainChip({required this.label, required this.selected, required this.onTap, this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            if (color != null) ...[Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8)],
            Text(label),
          ]),
          labelStyle: context.tt.titleMedium!.copyWith(color: selected ? Brand.ink : context.c.text, fontSize: 15),
          selected: selected,
          showCheckmark: false,
          selectedColor: Brand.yellow,
          backgroundColor: context.c.surface,
          side: BorderSide(color: selected ? Brand.yellow : context.c.line),
          onSelected: (_) => onTap(),
        ),
      );
}

class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.deal});
  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final price = s.dealPrice(deal);
    final fixed = s.priceFixes.containsKey(deal.id);
    final eurV = s.toEur(price);
    final tr = dealTranslation(context, deal);
    final pct = deal.discountPct;
    final chain = chainById(deal.chain);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: () => showDealSheet(context, deal),
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChainBadge(deal.chain),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(deal.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium),
              if (tr != null) ...[
                const SizedBox(height: 3),
                Text('≈ $tr', style: context.tt.bodyMedium!.copyWith(color: c.text2)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (deal.card == true) Pill(chain?.card != null ? context.s('dealsCard', {'card': chain!.card!}) : context.s('dealsCardGeneric'), fg: c.bad, bg: c.badSoft, icon: Icons.credit_card_rounded),
                if (deal.multibuy != null) Pill(deal.multibuy!, fg: Brand.ink, bg: Brand.yellow),
                if (deal.minQty != null && deal.minQty! > 1) Pill(context.s('dealsMinQty', {'n': deal.minQty!}), fg: c.text2, bg: c.raised),
                if (deal.validTo != null)
                  Pill(context.s('dealsUntil', {'date': dayMonth(DateTime.parse(deal.validTo!), lang)}), fg: c.text2, bg: c.raised, icon: Icons.event_rounded),
                if (fixed) Pill(context.s('dealsFix'), fg: c.good, bg: c.goodSoft, icon: Icons.edit_rounded),
                if (deal.ocr) Pill(context.s('dealOcr'), fg: c.text2, bg: c.raised, icon: Icons.menu_book_rounded),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (pct != null && pct >= .05)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: Brand.plRed, borderRadius: BorderRadius.circular(8)),
                child: Text('−${(pct * 100).round()}%', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
              ),
            Text(zl(price, lang), style: context.tt.titleLarge),
            if (eurV != null) Text('≈ ${eur(eurV, lang)}', style: context.tt.bodyMedium),
            if (deal.oldPrice != null && !fixed)
              Text(zl(deal.oldPrice!, lang), style: context.tt.bodySmall!.copyWith(decoration: TextDecoration.lineThrough)),
          ]),
        ]),
      ),
    );
  }
}

Future<void> showDealSheet(BuildContext context, Deal deal) => showSheet(context, (_) => _DealSheet(deal: deal));

class _DealSheet extends StatefulWidget {
  const _DealSheet({required this.deal});
  final Deal deal;

  @override
  State<_DealSheet> createState() => _DealSheetState();
}

class _DealSheetState extends State<_DealSheet> {
  bool _fixing = false;
  final _fix = TextEditingController();
  int _qty = 1;

  @override
  void dispose() {
    _fix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = widget.deal;
    final lang = context.lang;
    final c = context.c;
    final chain = chainById(d.chain);
    final price = s.dealPrice(d);
    final fixed = s.priceFixes.containsKey(d.id);
    final tr = dealTranslation(context, d);
    final eurV = s.toEur(price);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ChainBadge(d.chain, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text(chain?.name ?? d.chain, style: context.tt.titleLarge)),
        ]),
        const SizedBox(height: 14),
        PlName(d.name, large: true),
        if (tr != null) ...[
          const SizedBox(height: 6),
          Text('${context.s('dealsTranslated')}: $tr', style: context.tt.bodyLarge!.copyWith(color: c.text2)),
        ],
        if (d.ocr) ...[
          const SizedBox(height: 14),
          Panel(
            color: c.warnSoft,
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_rounded, color: c.warn),
              const SizedBox(width: 10),
              Expanded(child: Text(context.s('dealOcrNote'), style: context.tt.bodyMedium!.copyWith(color: c.text))),
            ]),
          ),
          if (d.imageUrl != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                final lf = s.leafletById(d.leaflet);
                if (lf != null) openLeaflet(context, lf, page: d.page ?? 1);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(color: c.raised, height: 220, width: double.infinity, child: LeafletImage(d.imageUrl!, fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 8),
            BigButton(
              label: context.s('dealSeePage'),
              icon: Icons.menu_book_rounded,
              kind: BtnKind.secondary,
              onPressed: () {
                final lf = s.leafletById(d.leaflet);
                if (lf != null) {
                  openLeaflet(context, lf, page: d.page ?? 1);
                } else {
                  launchUrl(Uri.parse(d.url ?? chain?.leafletUrl ?? 'https://www.google.com'), mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ],
        const SizedBox(height: 18),
        Panel(
          color: c.raised,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(zl(price, lang), style: context.tt.displayMedium),
                if (eurV != null) Text('≈ ${eur(eurV, lang)}', style: context.tt.titleMedium!.copyWith(color: c.text2)),
                if (d.unitPrice != null && d.unit != null)
                  Text(context.s('dealPerUnit', {'v': zl(d.unitPrice!, lang), 'unit': d.unit!}), style: context.tt.bodyMedium),
              ]),
            ),
            if (d.oldPrice != null && !fixed) Text(zl(d.oldPrice!, lang), style: context.tt.titleMedium!.copyWith(decoration: TextDecoration.lineThrough, color: c.text3)),
          ]),
        ),
        const SizedBox(height: 12),
        if (d.card == true)
          _Note(Icons.credit_card_rounded, chain?.card != null ? context.s('dealsCard', {'card': chain!.card!}) : context.s('dealsCardGeneric'), c.bad),
        if (d.multibuy != null) _Note(Icons.local_offer_rounded, d.multibuy!, c.warn),
        if (d.minQty != null && d.minQty! > 1) _Note(Icons.shopping_basket_rounded, context.s('dealsMinQty', {'n': d.minQty!}), c.text2),
        if (d.limit != null) _Note(Icons.block_rounded, context.s('dealsLimit', {'n': d.limit!}), c.text2),
        if (d.validTo != null) _Note(Icons.event_rounded, context.s('dealsUntil', {'date': dayMonth(DateTime.parse(d.validTo!), lang)}), c.text2),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text(context.s('itemQty'), style: context.tt.titleMedium)),
          Stepper2(value: _qty.toDouble(), onChanged: (v) => setState(() => _qty = v.toInt())),
        ]),
        const SizedBox(height: 14),
        BigButton(
          label: context.s('dealAdd'),
          icon: Icons.add_shopping_cart_rounded,
          onPressed: () {
            s.addItem(ListItem(id: newId(), name: tr ?? d.name, plName: d.name, qty: _qty, dealId: d.id));
            final outer = Navigator.of(context).context;
            Navigator.pop(context);
            showAddedSnack(outer, tr ?? d.name, d.chain);
          },
        ),
        const SizedBox(height: 10),
        if (!_fixing)
          BigButton(
            label: context.s('dealFixTitle'),
            icon: Icons.edit_rounded,
            kind: BtnKind.secondary,
            onPressed: () => setState(() {
              _fixing = true;
              _fix.text = price.toStringAsFixed(2).replaceAll('.', ',');
            }),
          )
        else
          Panel(
            color: c.raised,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(context.s('dealFixTitle'), style: context.tt.titleMedium),
              Text(context.s('dealFixHint'), style: context.tt.bodyMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _fix,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: context.tt.headlineSmall,
                decoration: InputDecoration(
                  fillColor: c.surface,
                  suffixIcon: Padding(padding: const EdgeInsets.only(right: 18), child: Text('zł', style: context.tt.titleLarge!.copyWith(color: c.text3))),
                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 10),
              BigButton(
                label: context.s('dealFixSave'),
                icon: Icons.check_rounded,
                onPressed: () {
                  final v = parseAmount(_fix.text);
                  if (v == null || v <= 0) return;
                  s.setPriceFix(d.id, v);
                  setState(() => _fixing = false);
                },
              ),
              if (fixed) ...[
                const SizedBox(height: 8),
                BigButton(label: context.s('dealFixClear'), kind: BtnKind.ghost, onPressed: () {
                  s.setPriceFix(d.id, null);
                  setState(() => _fixing = false);
                }),
              ],
            ]),
          ),
        const SizedBox(height: 10),
        BigButton(
          label: context.s('dealOpen'),
          icon: Icons.open_in_new_rounded,
          kind: BtnKind.ghost,
          onPressed: () => launchUrl(Uri.parse(d.url ?? chain?.leafletUrl ?? 'https://www.google.com'), mode: LaunchMode.externalApplication),
        ),
        const SizedBox(height: 6),
        Text(context.s('dealSource', {'chain': chain?.name ?? d.chain}), textAlign: TextAlign.center, style: context.tt.bodySmall),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: context.tt.bodyLarge)),
        ]),
      );
}

class _Leaflets extends StatelessWidget {
  const _Leaflets();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final inApp = s.leaflets;
    final inAppChains = {for (final l in inApp) l.chain};
    final children = <Widget>[];
    for (final ch in chains.where((x) => inAppChains.contains(x.id))) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Row(children: [ChainBadge(ch.id, size: 30), const SizedBox(width: 10), Text(ch.name, style: context.tt.titleLarge)]),
      ));
      for (final l in inApp.where((x) => x.chain == ch.id)) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            onTap: () => openLeaflet(context, l),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 74,
                  height: 100,
                  color: c.raised,
                  child: (l.pages.isNotEmpty ? (l.pages.first.thumb ?? l.cover ?? l.pages.first.image) : l.cover) == null
                      ? const Icon(Icons.menu_book_rounded)
                      : LeafletImage(l.pages.isNotEmpty ? (l.pages.first.thumb ?? l.cover ?? l.pages.first.image) : l.cover!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium),
                  const SizedBox(height: 4),
                  if (l.validTo != null)
                    Text(context.s('lfUntil', {'date': dayMonth(DateTime.parse(l.validTo!), lang)}), style: context.tt.bodyMedium),
                  Text(context.s('lfPages', {'n': l.pages.length}), style: context.tt.bodySmall),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.text3, size: 28),
            ]),
          ),
        ));
      }
    }
    if (inApp.isEmpty) {
      children.add(Panel(child: Text(context.s('lfNone'), style: context.tt.titleMedium)));
    }
    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 4),
      child: Text(context.s('lfOther'), style: context.tt.titleLarge),
    ));
    children.add(Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text(context.s('lfOtherSub'), style: context.tt.bodyMedium)));
    for (final ch in chains.where((x) => !inAppChains.contains(x.id))) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          onTap: () => launchUrl(Uri.parse(ch.leafletUrl), mode: LaunchMode.externalApplication),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            ChainBadge(ch.id),
            const SizedBox(width: 14),
            Expanded(child: Text(ch.name, style: context.tt.titleMedium)),
            Icon(Icons.open_in_new_rounded, color: c.text3),
          ]),
        ),
      ));
    }
    return SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), sliver: SliverList.list(children: children));
  }
}
