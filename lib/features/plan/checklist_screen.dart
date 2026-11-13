import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

/// Things a Lithuanian driver should have and know before crossing into Poland.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

const _sections = [
  ('ckDocs', ['ckId', 'ckLicence']),
  ('ckRoad', ['ckLights', 'ckAlcohol', 'ckSpeed']),
  ('ckShop', ['ckBags', 'ckCard', 'ckDeposit', 'ckLimits']),
  ('ckSafety', ['ck112']),
];

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _done = <String>{};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = _sections.fold<int>(0, (a, s) => a + s.$2.length);
    return Scaffold(
      appBar: AppBar(title: Text(context.s('ckTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(context.s('ckProgress', {'n': _done.length, 'm': total}), style: context.tt.bodyLarge!.copyWith(color: c.text2)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _done.length / total, minHeight: 8, color: Brand.yellow, backgroundColor: c.raised),
          ),
          for (final (title, keys) in _sections) ...[
            SectionTitle(context.s(title)),
            for (final k in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _done.contains(k) ? _done.remove(k) : _done.add(k));
                  },
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(
                      checked: _done.contains(k),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(_done.contains(k) ? Icons.check_circle_rounded : Icons.circle_outlined, size: 30, color: _done.contains(k) ? c.good : c.text3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 6),
                        Text(context.s(k), style: context.tt.titleMedium),
                        const SizedBox(height: 4),
                        Text(context.s('${k}Sub'), style: context.tt.bodyMedium),
                        if (k == 'ckLimits')
                          TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            onPressed: () => launchUrl(Uri.parse('https://lrmuitine.lt'), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: Text(context.s('ckLimitsLink')),
                          ),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 10),
          BigButton(
            label: context.s('sosOpen'),
            icon: Icons.sos_rounded,
            kind: BtnKind.danger,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SosScreen(), fullscreenDialog: true)),
          ),
          const SizedBox(height: 14),
          Text(context.s('ckNote'), style: context.tt.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Large Polish text to show a stranger in an emergency. Black on white, like the staff card.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF555555);
    return Scaffold(
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
            const Text('Potrzebuję pomocy.',
                style: TextStyle(fontFamily: 'Manrope', fontSize: 44, height: 1.05, fontWeight: FontWeight.w800, color: Brand.ink, letterSpacing: -1)),
            const SizedBox(height: 16),
            const Text('Proszę zadzwonić pod numer 112.',
                style: TextStyle(fontFamily: 'Manrope', fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, color: Brand.ink)),
            const SizedBox(height: 16),
            const Text('Jestem z Litwy. Nie mówię po polsku.', style: TextStyle(fontFamily: 'Inter', fontSize: 22, color: grey)),
            const Spacer(),
            Text(context.s('sosTranslation'), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF666666))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Brand.plRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                onPressed: () => launchUrl(Uri.parse('tel:112')),
                icon: const Icon(Icons.call_rounded, size: 28),
                label: Text(context.s('sosCall'), style: const TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
