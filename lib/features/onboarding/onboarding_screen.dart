import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/geo.dart';
import '../../widgets/ui.dart';
import '../more/more_screen.dart' show Segmented;

/// Three short steps, no account: language → text size → home town.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              for (var i = 0; i < 3; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: i == _step ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: i == _step ? Brand.yellow : c.raised, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: ListView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: switch (_step) {
                  0 => [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(44),
                          child: Image.asset('assets/brand/logo_full.png', width: 220, height: 220, filterQuality: FilterQuality.medium),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(context.s('obWelcome'), style: context.tt.displayMedium),
                      const SizedBox(height: 10),
                      Text(context.s('obWelcomeSub'), style: context.tt.bodyLarge!.copyWith(color: c.text2, fontSize: 19)),
                      const SizedBox(height: 28),
                      Segmented<Lang>(value: s.lang, options: const [(Lang.lt, 'Lietuvių'), (Lang.en, 'English')], onChanged: (v) => s.update((x) => x.lang = v)),
                    ],
                  1 => [
                      Text(context.s('setText'), style: context.tt.displayMedium),
                      const SizedBox(height: 10),
                      Text(context.s('obTextSub'), style: context.tt.bodyLarge!.copyWith(color: c.text2)),
                      const SizedBox(height: 24),
                      for (final (v, key) in [(1.0, 'textNormal'), (1.15, 'textLarge'), (1.3, 'textXL')])
                        ChoiceRow(
                          title: context.s(key),
                          subtitle: context.s('setPreview'),
                          selected: s.textScale == v,
                          leading: Text('Aa', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18 * v, color: c.text)),
                          onTap: () => s.update((x) => x.textScale = v),
                        ),
                    ],
                  _ => [
                      Text(context.s('obHome'), style: context.tt.headlineMedium),
                      const SizedBox(height: 10),
                      Text(context.s('obHomeSub'), style: context.tt.bodyLarge!.copyWith(color: c.text2)),
                      const SizedBox(height: 22),
                      for (final o in origins)
                        ChoiceRow(title: o.name, selected: s.originId == o.id, onTap: () => s.update((x) => x.originId = o.id)),
                    ],
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              if (_step > 0) ...[
                Expanded(child: BigButton(label: context.s('back'), kind: BtnKind.secondary, onPressed: () => setState(() => _step--))),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: BigButton(
                  label: _step < 2 ? context.s('next') : context.s('obStart'),
                  icon: _step < 2 ? Icons.arrow_forward_rounded : Icons.check_rounded,
                  onPressed: () => _step < 2 ? setState(() => _step++) : s.update((x) => x.onboarded = true),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
