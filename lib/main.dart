import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_state.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'features/deals/deals_screen.dart';
import 'features/list/list_screen.dart';
import 'features/cards/cards_screen.dart';
import 'features/map/map_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/trip/trip_screen.dart';
import 'services/alerts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs);
  runApp(AppScope(state: state, child: const ZlotikaApp()));
  state.refreshRate();
  state.loadStores();
  state.loadPrices();
  await Alerts.init(state);
  state.refreshFeed().then((_) => Alerts.check(state));
}

/// Bottom tabs, in order. Settings live behind the gear in every tab's header.
abstract final class Tabs {
  static const trip = 0, map = 1, list = 2, deals = 3, cards = 4;
}

/// Lets any screen switch the bottom tab (see [Tabs]).
final shellTab = ValueNotifier<int>(Tabs.trip);

class ZlotikaApp extends StatelessWidget {
  const ZlotikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return MaterialApp(
      title: 'Zlotika',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // The user's chosen size multiplies the phone's own accessibility size.
        final scale = (mq.textScaler.scale(1) * s.textScale).clamp(1.0, 1.8);
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child!);
      },
      home: s.onboarded ? const Shell() : const OnboardingScreen(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh the exchange rate when the app comes back after a few hours.
    if (state == AppLifecycleState.resumed) {
      final s = AppScope.read(context);
      final r = s.rate;
      if (r == null || DateTime.now().difference(r.fetchedAt).inHours >= 3) s.refreshRate();
      final f = s.feed;
      if (f == null || DateTime.now().difference(f.generatedAt).inHours >= 6) s.refreshFeed().then((_) => Alerts.check(s));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final open = s.items.where((e) => !e.checked).length;
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, tab, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: IndexedStack(index: tab, children: const [TripScreen(), MapScreen(), ListScreen(), DealsScreen(), CardsScreen()]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => shellTab.value = i,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.directions_car_outlined), selectedIcon: const Icon(Icons.directions_car_rounded), label: context.s('tabTrip')),
              NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map_rounded), label: context.s('tabMap')),
              NavigationDestination(
                icon: Badge(isLabelVisible: open > 0, label: Text('$open'), child: const Icon(Icons.checklist_rounded)),
                selectedIcon: Badge(isLabelVisible: open > 0, label: Text('$open'), child: const Icon(Icons.checklist_rounded)),
                label: context.s('tabList'),
              ),
              NavigationDestination(icon: const Icon(Icons.local_offer_outlined), selectedIcon: const Icon(Icons.local_offer_rounded), label: context.s('tabDeals')),
              NavigationDestination(icon: const Icon(Icons.credit_card_outlined), selectedIcon: const Icon(Icons.credit_card_rounded), label: context.s('tabCards')),
            ],
          ),
        ),
      ),
    );
  }
}
