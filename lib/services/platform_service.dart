import 'package:flutter/foundation.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

class PlatformService {
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      try {
        WebViewPlatform.instance = WebWebViewPlatform();
        print('WebView platform initialized for web');
      } catch (e) {
        print('Error initializing WebView platform: $e');
      }
    }
  }
} 