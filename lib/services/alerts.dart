import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../data/chains.dart';
import 'deals.dart';

/// Watchlist alerts: the phone checks the daily feed in the background (iOS decides
/// exactly when, usually a few times a day) and shows a local notification for deals
/// on watched items that weren't there before. Nothing is sent anywhere.
class Alerts {
  static final _n = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  static Future<void> init(AppState s) async {
    if (!supported) return;
    try {
      await _n.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 180, // minutes; iOS treats this as a lower bound
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: false,
          requiredNetworkType: NetworkType.ANY,
        ),
        (taskId) async {
          try {
            await s.refreshFeed();
            await check(s);
          } finally {
            BackgroundFetch.finish(taskId);
          }
        },
        (taskId) => BackgroundFetch.finish(taskId),
      );
    } catch (_) {
      // Alerts are a convenience; never let them break start-up.
    }
  }

  /// Asks iOS/Android for permission. Returns whether alerts can be shown.
  static Future<bool> requestPermission() async {
    if (!supported || !_ready) return false;
    final ios = _n.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    final android = _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    return false;
  }

  /// Looks for new watchlist deals and, if alerts are on, shows one notification.
  static Future<void> check(AppState s) async {
    final hits = s.takeNewWatchHits();
    if (hits.isEmpty || !s.alertsOn || !_ready) return;
    final lang = s.lang;
    String line((WatchItem, Deal) h) {
      final (w, d) = h;
      final pct = d.discountPct == null ? '' : ' (−${(d.discountPct! * 100).round()} %)';
      final until = d.validTo == null ? '' : ', ${tr(lang, 'dealsUntil', {'date': dayMonth(DateTime.parse(d.validTo!), lang)})}';
      return '${w.name}: ${chainById(d.chain)?.name ?? d.chain} ${zl(s.dealPrice(d), lang)}$pct$until';
    }

    final title = hits.length == 1 ? tr(lang, 'alertOne') : tr(lang, 'alertMany', {'n': hits.length});
    final body = hits.take(3).map(line).join('\n') + (hits.length > 3 ? '\n…' : '');
    await _n.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        android: AndroidNotificationDetails('watch', 'Watchlist deals', importance: Importance.high, priority: Priority.high),
      ),
    );
  }
}
