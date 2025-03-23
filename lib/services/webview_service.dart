import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static void initializeWebView() {
    if (_initialized) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        WebViewPlatform.instance = AndroidWebViewPlatform();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        WebViewPlatform.instance = WebKitWebViewPlatform();
      }
      _initialized = true;
    } catch (e) {
      print('Error initializing WebView platform: $e');
      _initialized = false;
    }
  }

  static PlatformWebViewControllerCreationParams getControllerParams() {
    if (!_initialized) {
      initializeWebView();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }
    return const PlatformWebViewControllerCreationParams();
  }
} 