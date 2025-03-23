import 'package:flutter/material.dart';
import 'package:performance_analysis/screens/unity_model_viewer_screen.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<dynamic> navigateToUnityModelViewer(BuildContext context, String modelPath, {String title = 'Unity Model Viewer'}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnityModelViewerScreen(
          modelPath: modelPath,
          title: title,
        ),
      ),
    );
  }

  Future<dynamic> navigateToRoute(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamed(routeName, arguments: arguments);
  }

  void goBack(BuildContext context) {
    Navigator.of(context).pop();
  }
} 