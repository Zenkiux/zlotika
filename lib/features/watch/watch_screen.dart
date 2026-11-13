import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/dictionary.dart';
import '../../services/alerts.dart';
import '../../widgets/ui.dart';
import '../list/add_item_screen.dart' show newId;
import '../list/deal_pick.dart';

/// Things the shopper buys regularly; we tell them when one goes on promotion.
class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  final _q = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(WatchItem w) {
    AppScope.read(context).addWatch(w);
    _q.clear();
    _focus.unfocus();
    setState(() {});
  }

  Future<void> _toggleAlerts(bool on) async {
    final s = AppScope.read(context);
    if (on && !await Alerts.requestPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s('watchNoPermission'))));
      return;
    }
    s.update((x) => x.alertsOn = on);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;
    final q = _q.text.trim().toLowerCase();
    final suggestions = q.length < 2
        ? const <Term>[]
        : terms.where((t) => '${t.lt} ${t.en} ${t.pl}'.toLowerCase().contains(q) && !s.isWatched(t.pl)).take(6).toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.s('watchTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(context.s('watchSub'), style: context.tt.bodyLarge!.copyWith(color: c.text2)),
          const SizedBox(height: 16),
          if (Alerts.supported)
            Panel(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
              child: Row(children: [
                Icon(Icons.notifications_active_rounded, color: s.alertsOn ? Brand.yellow : c.text3),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.s('watchAlerts'), style: context.tt.titleMedium),
                    Text(context.s('watchAlertsSub'), style: context.tt.bodySmall),
                  ]),
                ),
                Switch(value: s.alertsOn, onChanged: _toggleAlerts),
              ]),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _q,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: context.s('watchHint'), prefixIcon: const Icon(Icons.add_alert_rounded)),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              if (v.trim().length >= 2) _add(WatchItem(id: newId(), name: v.trim(), pl: v.trim()));
            },
          ),
          if (q.length >= 2) ...[
            const SizedBox(height: 8),
            for (final t in suggestions)
              ChoiceRow(
                title: lang == Lang.lt ? t.lt : t.en,
                subtitle: t.pl,
                selected: false,
                leading: const Icon(Icons.add_rounded),
                onTap: () => _add(WatchItem(id: newId(), name: lang == Lang.lt ? t.lt : t.en, pl: t.pl, term: true)),
              ),
            ChoiceRow(
              title: context.s('watchCustom', {'q': _q.text.trim()}),
              subtitle: context.s('watchCustomSub'),
              selected: false,
              leading: const Icon(Icons.search_rounded),
              onTap: () => _add(WatchItem(id: newId(), name: _q.text.trim(), pl: _q.text.trim())),
            ),
          ],
          if (s.watch.isEmpty && q.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(context.s('watchEmpty'), textAlign: TextAlign.center, style: context.tt.bodyLarge!.copyWith(color: c.text2)),
            ),
          const SizedBox(height: 12),
          for (final w in s.watch) _WatchRow(item: w),
        ],
      ),
    );
  }
}

class _WatchRow extends StatelessWidget {
  const _WatchRow({required this.item});
  final WatchItem item;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final hits = s.watchDeals(item);
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
        onDismissed: (_) => s.removeWatch(item.id),
        child: Panel(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          onTap: hits.isEmpty
              ? null
              : () async {
                  final d = await pickDeal(context, context.s('matchPickTitle', {'name': item.name}), hits);
                  if (d == null || !context.mounted) return;
                  final li = ListItem(id: newId(), name: item.name, plName: item.term ? item.pl : null);
                  applyDeal(li, d, s.dealPrice(d));
                  s.addItem(li);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s('addAdded', {'name': item.name}))));
                },
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: context.tt.titleMedium),
                if (item.term) ...[const SizedBox(height: 2), PlName(item.pl)],
                const SizedBox(height: 8),
                if (hits.isEmpty)
                  Text(context.s('watchNoDeals'), style: context.tt.bodyMedium)
                else
                  DealCountPill(hits),
              ]),
            ),
            if (hits.isNotEmpty) Icon(Icons.chevron_right_rounded, color: c.text3),
          ]),
        ),
      ),
    );
  }
}
