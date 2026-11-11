import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/dictionary.dart';
import '../../widgets/ui.dart';
import 'deal_pick.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _addTerm(Term t) async {
    final s = AppScope.read(context);
    final name = context.lang == Lang.lt ? t.lt : t.en;
    final item = ListItem(id: newId(), name: name, plName: t.pl);
    final matches = s.dealsFor(t.pl);
    if (matches.isNotEmpty) {
      // One question: which of this week's deals? The price is filled in from it.
      final d = await pickDeal(context, context.s('matchPickTitle', {'name': name}), matches);
      if (!mounted) return;
      if (d != null) applyDeal(item, d, s.dealPrice(d));
    }
    s.addItem(item);
    _done(name);
  }

  void _addCustom(String q) {
    final name = q.trim();
    if (name.isEmpty) return;
    AppScope.read(context).addItem(ListItem(id: newId(), name: name[0].toUpperCase() + name.substring(1)));
    _done(name);
  }

  void _done(String name) {
    final messenger = ScaffoldMessenger.of(context);
    final text = context.s('addAdded', {'name': name});
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text;
    final results = searchTerms(q);
    final popular = popularIds.map(termByLt).whereType<Term>().toList();
    final lt = context.lang == Lang.lt;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.c.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close_rounded, size: 28), tooltip: context.s('close'), onPressed: () => Navigator.pop(context)),
        title: Text(context.s('addTitle'), style: context.tt.titleLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextField(
              controller: _q,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: context.tt.titleLarge,
              decoration: InputDecoration(
                hintText: context.s('addHint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 26),
                suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(_q.clear)),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => results.isNotEmpty ? _addTerm(results.first) : _addCustom(v),
            ),
            const SizedBox(height: 18),
            if (q.isEmpty) ...[
              Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text(context.s('addPopular'), style: context.tt.titleMedium)),
              for (final t in popular) _TermRow(term: t, lt: lt, onTap: () => _addTerm(t)),
            ] else ...[
              for (final t in results) _TermRow(term: t, lt: lt, onTap: () => _addTerm(t)),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Panel(
                  onTap: () => _addCustom(q),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const IconTile(Icons.add_rounded, bg: Brand.yellow, color: Brand.ink, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.s('addCustom', {'q': q.trim()}), style: context.tt.titleMedium),
                        Text(context.s('addNoPl'), style: context.tt.bodySmall),
                      ]),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.term, required this.lt, required this.onTap});
  final Term term;
  final bool lt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lt ? term.lt : term.en, style: context.tt.titleMedium),
                const SizedBox(height: 4),
                PlName(term.pl),
                if (AppScope.of(context).dealsFor(term.pl) case final m when m.isNotEmpty) ...[const SizedBox(height: 8), DealCountPill(m)],
              ]),
            ),
            Icon(Icons.add_circle_rounded, color: Brand.yellow, size: 32),
          ]),
        ),
      );
}
