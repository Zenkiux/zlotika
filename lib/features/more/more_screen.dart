import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../convert/convert_screen.dart';
import '../report/report_screen.dart' show OpenPricesAccount;
import '../plan/checklist_screen.dart';
import '../../widgets/ui.dart';
import '../../services/updates.dart';
import '../history/history_screen.dart';
import '../watch/watch_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final lang = context.lang;

    void info(String title, List<String> lines) => showSheet(
          context,
          (ctx) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ctx.tt.headlineSmall),
              const SizedBox(height: 14),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 7), child: Dot(ctx.c.accent, size: 6)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l, style: ctx.tt.bodyLarge)),
                  ]),
                ),
            ]),
          ),
        );

    Widget segRow(String title, Widget seg, {String? sub, double width = 170, bool last = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: context.tt.titleMedium),
                  if (sub != null) Text(sub, style: context.tt.bodySmall!.copyWith(color: c.text2)),
                ]),
              ),
              SizedBox(width: width, child: seg),
            ]),
          ),
        );

    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: Text(context.s('moreTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          SectionTitle(context.s('setLook'), top: 16),
          RowGroup(children: [
            segRow(context.s('setLang'), Segmented<Lang>(value: s.lang, options: const [(Lang.lt, 'LT'), (Lang.en, 'EN')], onChanged: (v) => s.update((x) => x.lang = v)), width: 120),
            segRow(
              context.s('setText'),
              Segmented<double>(value: s.textScale, options: const [(1.0, '1.0×'), (1.15, '1.15×'), (1.3, '1.3×')], onChanged: (v) => s.update((x) => x.textScale = v)),
            ),
            segRow(
              context.s('setTheme'),
              Segmented<ThemeMode>(
                value: s.themeMode,
                options: [(ThemeMode.dark, context.s('themeDark')), (ThemeMode.light, context.s('themeLight')), (ThemeMode.system, context.s('themeAuto'))],
                onChanged: (v) => s.update((x) => x.themeMode = v),
              ),
              width: 190,
            ),
            segRow(
              context.s('setFee'),
              Stepper2(
                value: s.cardFeePct,
                min: 0,
                max: 3,
                step: .5,
                format: (v) => '${fmtNum(v, lang)} %',
                onChanged: (v) => s.update((x) => x.cardFeePct = v),
              ),
              sub: context.s('setFeeSub'),
              width: 150,
              last: true,
            ),
          ]),
          SectionTitle(context.s('moreTools')),
          RowGroup(children: [
            RowTile(
              icon: Icons.savings_outlined,
              tone: Tone.good,
              title: context.s('histTitle'),
              subtitle: s.trips.isEmpty ? context.s('histNone') : context.s('histHome', {'v': eurSigned(s.yearTotals(DateTime.now().year).saved, lang)}),
              onTap: () => push(const HistoryScreen()),
            ),
            RowTile(icon: Icons.notifications_none_rounded, tone: Tone.accent, title: context.s('watchTitle'), subtitle: context.s('watchHomeSub'), onTap: () => push(const WatchScreen())),
            RowTile(
              icon: Icons.currency_exchange_rounded,
              tone: Tone.blue,
              title: context.s('actionConvert'),
              subtitle: s.rate == null ? null : context.s('convRate', {'r': fmtNum(s.rate!.mid, lang, digits: 4), 'd': s.rate!.date}),
              onTap: () => push(const ConvertScreen()),
            ),
            RowTile(icon: Icons.fact_check_outlined, title: context.s('planChecklist'), subtitle: context.s('checklistSub'), onTap: () => push(const ChecklistScreen()), last: true),
          ]),
          if (Theme.of(context).platform == TargetPlatform.android) ...[
            SectionTitle(context.s('updTitle')),
            if (s.appUpdate != null) const UpdateBanner() else
            RowGroup(children: [
              RowTile(
                icon: Icons.system_update_outlined,
                title: context.s('updVersion', {'v': s.appVersion}),
                subtitle: s.updateChecking ? context.s('updChecking') : context.s('updLatest'),
                trailing: TextButton(onPressed: s.updateChecking ? null : s.checkUpdate, child: Text(context.s('updCheck'))),
                last: true,
              ),
            ]),
          ],
          SectionTitle(context.s('moreOpenPrices')),
          const OpenPricesAccount(),
          SectionTitle(context.s('setHonesty')),
          RowGroup(children: [
            RowTile(
              icon: Icons.dataset_outlined,
              title: context.s('aboutData'),
              subtitle: context.s('aboutDataSub'),
              onTap: () => info(context.s('aboutData'), [context.s('dataNbp'), context.s('dataOff'), context.s('dataCalendar'), context.s('dataDistance'), context.s('dataPrices')]),
            ),
            RowTile(icon: Icons.lock_outline_rounded, title: context.s('privacy'), onTap: () => info(context.s('privacy'), [context.s('privacyText')])),
            RowTile(
              icon: Icons.info_outline_rounded,
              title: context.s('aboutApp'),
              subtitle: context.s('freeForever'),
              onTap: () => info(context.s('aboutApp'), [context.s('aboutAppText'), context.s('version', {'v': '0.2.0'})]),
              last: true,
            ),
          ]),
          const SizedBox(height: 16),
          BigButton(
            label: context.s('resetAll'),
            kind: BtnKind.danger,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(ctx.s('resetQ'), style: ctx.tt.headlineSmall),
                  content: Text(ctx.s('resetSub'), style: ctx.tt.bodyLarge),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.s('cancel'))),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.s('delete'), style: TextStyle(color: c.bad))),
                  ],
                ),
              );
              if (ok == true) {
                await s.resetAll();
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
          const SizedBox(height: 22),
          const Center(child: FlagRibbon(width: 56, height: 4)),
          const SizedBox(height: 10),
          Center(child: Text(context.s('tagline'), style: context.tt.bodySmall)),
        ],
      ),
    );
  }
}

/// The same gear in the same corner of every tab: settings and tools.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => RoundIcon(
        Icons.settings_outlined,
        tooltip: context.s('moreTitle'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MoreScreen())),
      );
}

/// "A new version is ready": one tap downloads it inside the app and opens Android's installer.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  int? _percent; // null = not started
  bool _failed = false;
  bool _handedOver = false; // Android's installer was opened; if they come back, they can tap again

  Future<void> _go(AppUpdate u) async {
    setState(() {
      _percent = 0;
      _failed = false;
    });
    await for (final e in u.install()) {
      if (!mounted) return;
      if (e.error) {
        setState(() {
          _failed = true;
          _percent = null;
        });
        return;
      }
      if (e.done) {
        setState(() {
          _percent = null;
          _handedOver = true;
        });
        return;
      }
      setState(() => _percent = e.percent ?? _percent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.appUpdate;
    if (u == null) return const SizedBox.shrink();
    final c = context.c;
    final busy = _percent != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.accentLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.system_update_rounded, color: c.accentText, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('updAvailable', {'v': u.label}), style: context.tt.titleMedium),
              Text(
                _failed
                    ? context.s('updFailed')
                    : busy
                        ? context.s('updDownloading', {'p': _percent!})
                        : _handedOver
                            ? context.s('updConfirm')
                            : (u.notes ?? context.s('updSub')),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall!.copyWith(color: _failed ? c.bad : c.text2),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (!busy)
            Press(
              onTap: () => _failed ? u.openInBrowser() : _go(u),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                child: Text(context.s(_failed ? 'updBrowser' : 'updButton'), style: context.tt.labelMedium!.copyWith(color: c.onAccent, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
        if (busy) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_percent ?? 0) / 100, minHeight: 5, color: c.accent, backgroundColor: c.raised2),
          ),
        ],
      ]),
    );
  }
}
