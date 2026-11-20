import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where Android builds are published: GitHub Releases of the open-source app repo.
/// `scripts/release.sh` creates a release tagged `v<version>+<build>` with the APK attached.
const kReleasesApi = String.fromEnvironment('ZLOTIKA_RELEASES', defaultValue: 'https://api.github.com/repos/Zenkiux/zlotika/releases/latest');

/// A newer Android build than the one installed.
class AppUpdate {
  const AppUpdate({required this.version, required this.build, required this.apk, this.notes});
  final String version;
  final int build;
  final String apk; // direct download link of the APK
  final String? notes;

  String get label => version;

  /// Downloads the APK inside the app (progress 0–100) and hands it to Android's installer,
  /// which updates the app in place — data stays. Ends with `done` or `error`.
  Stream<({int? percent, bool done, bool error})> install() async* {
    try {
      await for (final e in OtaUpdate().execute(apk, destinationFilename: 'zlotika-update.apk')) {
        switch (e.status) {
          case OtaStatus.DOWNLOADING:
            yield (percent: int.tryParse(e.value ?? ''), done: false, error: false);
          case OtaStatus.INSTALLING:
          case OtaStatus.INSTALLATION_DONE:
            yield (percent: 100, done: true, error: false);
          case OtaStatus.ALREADY_RUNNING_ERROR:
            break;
          default:
            yield (percent: null, done: false, error: true);
        }
      }
    } catch (_) {
      yield (percent: null, done: false, error: true);
    }
  }

  /// Fallback: open the download in the browser.
  Future<bool> openInBrowser() => launchUrl(Uri.parse(apk), mode: LaunchMode.externalApplication);

  /// Reads a GitHub "latest release" response. Tag format: v1.2.0+7.
  static AppUpdate? parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final m = RegExp(r'^v?(\d+\.\d+\.\d+)\+(\d+)$').firstMatch((j['tag_name'] as String? ?? '').trim());
    if (m == null) return null;
    String? apk;
    for (final a in (j['assets'] as List? ?? const [])) {
      final url = (a as Map<String, dynamic>)['browser_download_url'] as String?;
      if (url != null && url.endsWith('.apk')) apk = url;
    }
    if (apk == null) return null;
    final notes = (j['body'] as String?)?.trim();
    return AppUpdate(version: m[1]!, build: int.parse(m[2]!), apk: apk, notes: notes == null || notes.isEmpty ? null : notes);
  }

  /// This installed build, e.g. ('1.2.0', 7).
  static Future<({String version, int build})> current() async {
    final p = await PackageInfo.fromPlatform();
    return (version: p.version, build: int.tryParse(p.buildNumber) ?? 0);
  }

  /// The latest published build, if it is newer than this one. Android only:
  /// iPhones get new builds by cable from the Mac.
  static Future<AppUpdate?> check({http.Client? client}) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final c = client ?? http.Client();
    try {
      final r = await c.get(Uri.parse(kReleasesApi), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final u = parse(utf8.decode(r.bodyBytes));
      if (u == null) return null;
      final me = await current();
      return u.build > me.build ? u : null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}
