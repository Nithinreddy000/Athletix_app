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
      case TargetPlatform.macOS:
        return web;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBfc9mOhp1Jsb5pxGkwoB5VCNRB2zvS9PA',
    appId: '1:136392355108:web:bec5ddc3c2b680e03497b1',
    messagingSenderId: '136392355108',
    projectId: 'athletemanagementsystem-8fa62',
    authDomain: 'athletemanagementsystem-8fa62.firebaseapp.com',
    storageBucket: 'athletemanagementsystem-8fa62.firebasestorage.app',
    measurementId: 'G-5LV4HVX9CC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBhAkh6jGlfgjZoynWydwrSuNjzlZMlzb0',
    appId: '1:136392355108:android:99f0452394217e2d3497b1',
    messagingSenderId: '136392355108',
    projectId: 'athletemanagementsystem-8fa62',
    storageBucket: 'athletemanagementsystem-8fa62.firebasestorage.app',
    androidClientId: '136392355108-jj1ri7qrddcte2affofiedr637vas8q2.apps.googleusercontent.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCqDI_0P9N96aQ7VFBSCVxOr90BSZ6i5pg',
    appId: '1:136392355108:ios:b75040acff785d963497b1',
    messagingSenderId: '136392355108',
    projectId: 'athletemanagementsystem-8fa62',
    storageBucket: 'athletemanagementsystem-8fa62.firebasestorage.app',
    iosClientId: '136392355108-lpb0v4mf8mej22bebvbvmp511d3fcoua.apps.googleusercontent.com',
    androidClientId: '136392355108-jj1ri7qrddcte2affofiedr637vas8q2.apps.googleusercontent.com',
    iosBundleId: 'atheletemanagementsystem',
  );
} 