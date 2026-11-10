import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/calendar.dart';
import '../../main.dart';
import '../../widgets/ui.dart';
import '../convert/convert_screen.dart';
import '../scan/scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  String _hello(BuildContext context) {
    final h = _now.hour;
    return context.s(h < 11 ? 'helloMorning' : h < 18 ? 'helloDay' : 'helloEvening');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Brand.ink,
        backgroundColor: Brand.yellow,
        onRefresh: s.refreshRate,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(children: [
              const LogoMark(size: 44),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Zlotika', style: context.tt.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const FlagRibbon(width: 46, height: 3),
              ]),
            ]),
            const SizedBox(height: 26),
            Text('${_hello(context)}!', style: context.tt.displayMedium),
            const SizedBox(height: 6),
            Text('${_cap(weekday(_now, lang))}, ${dayMonth(_now, lang)}', style: context.tt.bodyLarge!.copyWith(color: c.text2)),
            const SizedBox(height: 22),
            _TodayPanel(now: _now),
            const SizedBox(height: 14),
            _TripCard(onTap: () => shellTab.value = 3),
            const SizedBox(height: 12),
            _ActionRow(
              icon: Icons.local_offer_rounded,
              iconColor: Colors.white,
              iconBg: Brand.plRed,
              title: context.s('homeDeals'),
              subtitle: s.deals.isEmpty ? context.s('dealsTabLeaflets') : context.s('homeDealsSub', {'n': s.deals.length}),
              onTap: () => shellTab.value = 1,
            ),
            _ActionRow(
              icon: Icons.shopping_bag_rounded,
              iconColor: Brand.ink,
              iconBg: Brand.yellow,
              title: context.s('actionList'),
              subtitle: s.items.isEmpty ? context.s('listEmpty') : context.items(s.items.length),
              onTap: () => shellTab.value = 2,
            ),
            _ActionRow(
              icon: Icons.qr_code_scanner_rounded,
              iconColor: Colors.white,
              iconBg: Brand.green,
              title: context.s('actionScan'),
              subtitle: context.s('actionScanSub'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
            ),
            _ActionRow(
              icon: Icons.currency_exchange_rounded,
              iconColor: Brand.ink,
              iconBg: Brand.white,
              title: context.s('actionConvert'),
              subtitle: context.s('actionConvertSub'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConvertScreen())),
            ),
            const SizedBox(height: 10),
            _TipCard(dayOfYear: _now.difference(DateTime(_now.year)).inDays),
          ],
        ),
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = context.lang;
    final c = context.c;
    final day = shopDay(now);
    final sat = nextSaturday(now);
    final open = shopsOpen(now);
    final r = s.rate;

    final shopsText = switch (day) {
      ShopDay.open => context.s('shopsOpen'),
      ShopDay.sundayClosed => context.s('shopsSunday'),
      ShopDay.holiday => context.s('shopsHoliday'),
      ShopDay.tradingSunday => context.s('shopsTradingSunday'),
    };
    final satText = shopsOpen(sat) ? context.s('shopsNext', {'date': dayMonth(sat, lang)}) : context.s('shopsNextClosed', {'date': dayMonth(sat, lang)});

    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.s('today').toUpperCase(), style: context.tt.labelMedium!.copyWith(letterSpacing: 1.2, color: c.text3)),
        const SizedBox(height: 6),
        _FactRow(
          icon: Icons.euro_rounded,
          title: r != null ? '1 € = ${fmtNum(r.mid, lang, digits: 4)} zł' : (s.rateLoading ? context.s('rateLoading') : context.s('rateNone')),
          subtitle: r != null
              ? '${context.s('rateTitle')} · ${context.s('rateSource', {'date': r.date})}${s.rateFailed ? ' · ${context.s('rateStale')}' : ''}'
              : context.s('rateTitle'),
          trailing: s.rateLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : IconButton(onPressed: s.refreshRate, icon: Icon(Icons.refresh_rounded, color: c.text3), tooltip: context.s('retry')),
        ),
        Divider(color: c.line),
        _FactRow(
          icon: open ? Icons.storefront_rounded : Icons.store_mall_directory_outlined,
          iconColor: open ? c.good : c.bad,
          title: shopsText,
          subtitle: satText,
        ),
        Divider(color: c.line),
        _FactRow(
          icon: Icons.schedule_rounded,
          title: context.s('timeThere', {'time': hhmm(polishTime(now))}),
          subtitle: context.s('timeThereSub'),
        ),
      ]),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.title, required this.subtitle, this.trailing, this.iconColor});
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon, size: 28, color: iconColor ?? context.c.text2),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.tt.titleLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: context.tt.bodyMedium),
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// The one question that matters most, as the primary call to action.
class _TripCard extends StatelessWidget {
  const _TripCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        color: Brand.yellow,
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s('actionTrip'), style: context.tt.headlineSmall!.copyWith(color: Brand.ink)),
              const SizedBox(height: 4),
              Text(context.s('actionTripSub'), style: context.tt.bodyLarge!.copyWith(color: Brand.ink.withValues(alpha: .75))),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Brand.ink, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_rounded, color: Brand.yellow, size: 28),
          ),
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.iconColor, required this.iconBg, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            IconTile(icon, color: iconColor, bg: iconBg, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleLarge),
                Text(subtitle, style: context.tt.bodyMedium),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: context.c.text3, size: 28),
          ]),
        ),
      );
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.dayOfYear});
  final int dayOfYear;

  @override
  Widget build(BuildContext context) {
    const keys = ['tipPay', 'tipDeposit', 'tipTime'];
    final c = context.c;
    return Panel(
      color: c.warnSoft,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_rounded, color: c.warn, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s('tipTitle'), style: context.tt.titleMedium!.copyWith(color: c.warn)),
            const SizedBox(height: 4),
            Text(context.s(keys[dayOfYear % keys.length]), style: context.tt.bodyLarge),
          ]),
        ),
      ]),
    );
  }
}
