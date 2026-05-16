// Firebase options for ORTHOQ (orthoq-8d843).
// Web uses the Browser key; Android uses the Android-restricted key (package + SHA-1).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// ORTHOQ Web — exact copy of Firebase Console → ORTHOQ Web → firebaseConfig.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCDDE_-AY4I7jfvAIR6vJsrNUKC9XiGeEw',
    authDomain: 'orthoq-8d843.firebaseapp.com',
    projectId: 'orthoq-8d843',
    storageBucket: 'orthoq-8d843.firebasestorage.app',
    messagingSenderId: '610549283518',
    appId: '1:610549283518:web:5353664b5cc17563b6fcef',
  );

  /// ORTHOQ Android — Android API key (not the Browser key).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB4NnjjvOOiz_uyfKlKrA1FgOIkDSo7B1g',
    appId: '1:610549283518:android:5cde67b9e8ab9744b6fcef',
    messagingSenderId: '610549283518',
    projectId: 'orthoq-8d843',
    storageBucket: 'orthoq-8d843.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'orthoq-8d843',
    storageBucket: 'orthoq-8d843.appspot.com',
    iosBundleId: 'com.example.orthoqApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'orthoq-8d843',
    storageBucket: 'orthoq-8d843.appspot.com',
    iosBundleId: 'com.example.orthoqApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY',
    appId: 'YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'orthoq-8d843',
    storageBucket: 'orthoq-8d843.appspot.com',
  );
}

