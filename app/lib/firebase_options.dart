import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError('This platform is not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAt6eDJFJSYhjG96kEhW-Br__AbuGWvmJ4',
    appId: '1:48981468859:web:9d6fd101b5ad0644faab9e',
    messagingSenderId: '48981468859',
    projectId: 'gradproject-69973',
    storageBucket: 'gradproject-69973.firebasestorage.app',
    authDomain: 'gradproject-69973.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAt6eDJFJSYhjG96kEhW-Br__AbuGWvmJ4',
    appId: '1:48981468859:android:37cf8bfacea68bc4faab9e',
    messagingSenderId: '48981468859',
    projectId: 'gradproject-69973',
    storageBucket: 'gradproject-69973.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyABak5_gpaYqflIPKIoF0jqa_jtnJ2_Uh8',
    appId: '1:48981468859:ios:d43fdb02f3e0352ffaab9e',
    messagingSenderId: '48981468859',
    projectId: 'gradproject-69973',
    storageBucket: 'gradproject-69973.firebasestorage.app',
    iosBundleId: 'gradproject',
  );
}
