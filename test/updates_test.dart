import 'package:flutter_test/flutter_test.dart';
import 'package:zlotika/services/updates.dart';

void main() {
  test('reads the latest GitHub release', () {
    final u = AppUpdate.parse('{"tag_name":"v1.2.0+7","body":"Naujas dizainas","assets":[{"browser_download_url":"https://github.com/x/y/releases/download/v1.2.0+7/zlotika-1.2.0.apk"}]}')!;
    expect(u.version, '1.2.0');
    expect(u.build, 7);
    expect(u.apk, endsWith('.apk'));
    expect(u.notes, 'Naujas dizainas');
  });

  test('ignores releases without an APK or with an odd tag', () {
    expect(AppUpdate.parse('{"tag_name":"v1.2.0+7","assets":[]}'), isNull);
    expect(AppUpdate.parse('{"tag_name":"latest","assets":[{"browser_download_url":"a.apk"}]}'), isNull);
  });
}
