import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../convert/convert_screen.dart';
import '../report/report_screen.dart' show OpenPricesAccount;
import '../plan/checklist_screen.dart';
import '../../widgets/ui.dart';
import '../history/history_screen.dart';
import '../watch/watch_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;

    Widget block(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text(title, style: context.tt.titleMedium)),
            child,
          ]),
        );

    Widget link(IconData icon, String title, VoidCallback onTap, {String? sub, Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            onTap: onTap,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconTile(icon, size: 44, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: context.tt.titleMedium!.copyWith(color: color)),
                  if (sub != null) Text(sub, style: context.tt.bodyMedium),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.text3),
            ]),
          ),
        );

    void info(String title, List<String> lines) => showSheet(
          context,
          (ctx) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ctx.tt.headlineSmall),
              const SizedBox(height: 14),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.circle, size: 7, color: Brand.yellow)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l, style: ctx.tt.bodyLarge)),
                  ]),
                ),
            ]),
          ),
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(context.s('moreTitle'), style: context.tt.headlineMedium),
          const SizedBox(height: 22),
          block(context.s('setLang'),
              Segmented<Lang>(value: s.lang, options: const [(Lang.lt, 'Lietuvių'), (Lang.en, 'English')], onChanged: (v) => s.update((x) => x.lang = v))),
          block(
            context.s('setText'),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Segmented<double>(
                value: s.textScale,
                options: [(1.0, context.s('textNormal')), (1.15, context.s('textLarge')), (1.3, context.s('textXL'))],
                onChanged: (v) => s.update((x) => x.textScale = v),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 0), child: Text(context.s('setPreview'), style: context.tt.bodyLarge)),
            ]),
          ),
          block(
            context.s('setTheme'),
            Segmented<ThemeMode>(
              value: s.themeMode,
              options: [(ThemeMode.dark, context.s('themeDark')), (ThemeMode.light, context.s('themeLight')), (ThemeMode.system, context.s('themeSystem'))],
              onChanged: (v) => s.update((x) => x.themeMode = v),
            ),
          ),
          block(
            context.s('setFee'),
            Segmented<double>(
              value: s.cardFeePct,
              options: [for (final f in [0.0, 1.0, 2.0, 3.0]) (f, '${fmtNum(f, lang, digits: 0)} %')],
              onChanged: (v) => s.update((x) => x.cardFeePct = v),
            ),
          ),
          block(context.s('moreOpenPrices'), const OpenPricesAccount()),
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text(context.s('moreTools'), style: context.tt.titleMedium)),
          link(Icons.savings_rounded, context.s('histTitle'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
              sub: s.trips.isEmpty ? null : context.s('histHome', {'v': eurSigned(s.yearTotals(DateTime.now().year).saved, lang)})),
          link(Icons.notifications_active_rounded, context.s('watchTitle'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WatchScreen())),
              sub: context.s('watchHomeSub')),
          link(Icons.currency_exchange_rounded, context.s('actionConvert'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConvertScreen())),
              sub: s.rate == null ? null : context.s('convRate', {'r': fmtNum(s.rate!.mid, lang, digits: 4), 'd': s.rate!.date})),
          link(Icons.fact_check_rounded, context.s('planChecklist'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChecklistScreen()))),
          const SizedBox(height: 12),
          link(Icons.dataset_rounded, context.s('aboutData'),
              () => info(context.s('aboutData'), [context.s('dataNbp'), context.s('dataOff'), context.s('dataCalendar'), context.s('dataDistance'), context.s('dataPrices')])),
          link(Icons.lock_rounded, context.s('privacy'), () => info(context.s('privacy'), [context.s('privacyText')])),
          link(Icons.info_rounded, context.s('aboutApp'), () => info(context.s('aboutApp'), [context.s('aboutAppText'), context.s('version', {'v': '0.1.0'})])),
          const SizedBox(height: 12),
          link(Icons.delete_forever_rounded, context.s('resetAll'), color: c.bad, () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: c.surface,
                title: Text(ctx.s('resetQ'), style: ctx.tt.headlineSmall),
                content: Text(ctx.s('resetSub'), style: ctx.tt.bodyLarge),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.s('cancel'), style: ctx.tt.titleMedium)),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.s('delete'), style: ctx.tt.titleMedium!.copyWith(color: c.bad))),
                ],
              ),
            );
            if (ok == true) await s.resetAll();
          }),
          const SizedBox(height: 18),
          const Center(child: FlagRibbon(width: 56, height: 4)),
          const SizedBox(height: 10),
          Center(child: Text(context.s('tagline'), style: context.tt.bodyMedium)),
        ],
      ),
    );
  }
}
