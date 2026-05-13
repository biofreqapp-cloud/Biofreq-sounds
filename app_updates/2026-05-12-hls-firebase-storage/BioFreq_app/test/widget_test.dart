import 'package:flutter_test/flutter_test.dart';

import 'package:biofreq_app/main.dart';

void main() {
  group('AppUpdateConfig', () {
    test('usa apk_url de version.json antes que Firestore', () {
      const firestoreFallback =
          'https://raw.githubusercontent.com/biofreqapp-cloud/Biofreq-sounds/main/app-release.apk';
      const versionJsonApk =
          'https://firebasestorage.googleapis.com/v0/b/biofreq-app.firebasestorage.app/o/app_updates%2Fandroid%2FBioFreq_4.0.52_2137_updater_banner_fix_release_20260513.apk?alt=media&token=test';

      AppUpdateConfig.setCachedUrl(firestoreFallback);

      expect(AppUpdateConfig.resolve(versionJsonApk), versionJsonApk);
    });

    test('mantiene Firestore solo como fallback si version.json no trae URL',
        () {
      const firestoreFallback =
          'https://raw.githubusercontent.com/biofreqapp-cloud/Biofreq-sounds/main/app-release.apk';

      AppUpdateConfig.setCachedUrl(firestoreFallback);

      expect(AppUpdateConfig.resolve(), firestoreFallback);
    });

    test('rechaza destinos de Play Store para el APK', () {
      expect(
        AppUpdateConfig.normalizeUpdaterUrl(
          'https://play.google.com/store/apps/details?id=com.biofreq.oficial',
        ),
        isNull,
      );
      expect(
        AppUpdateConfig.normalizeUpdaterUrl(
          'market://details?id=com.biofreq.oficial',
        ),
        isNull,
      );
    });
  });
}
