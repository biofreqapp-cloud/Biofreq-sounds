import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Reconstructed from values recovered directly out of the saved APK.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions were only reconstructed for Android.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions were only reconstructed for Android.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCej7H7QOFpMJurcFVLUGjrbk3CB-o_RO4',
    appId: '1:30683416180:android:5e81d1a58bf36c6ee2f321',
    messagingSenderId: '30683416180',
    projectId: 'biofreq-app',
    storageBucket: 'biofreq-app.firebasestorage.app',
  );
}
