import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

class UnityService {
  static final UnityService _instance = UnityService._internal();
  factory UnityService() => _instance;
  UnityService._internal();

  UnityWidgetController? _unityWidgetController;
  final StreamController<Map<String, dynamic>> _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onUnityMessage => _messageStreamController.stream;
  bool get isControllerInitialized => _unityWidgetController != null;

  void setController(UnityWidgetController controller) {
    _unityWidgetController = controller;
    _setupMessageHandler();
  }

  void _setupMessageHandler() {
    _unityWidgetController?.onUnityMessage?.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data is Map<String, dynamic>) {
          _messageStreamController.add(data);
        }
      } catch (e) {
        debugPrint('Error parsing Unity message: $e');
      }
    });
  }

  Future<void> loadModel(String modelPath) async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    await _unityWidgetController?.postMessage(
      'ModelLoader',
      'LoadModel',
      modelPath,
    );
  }

  Future<void> rotateModel(double x, double y, double z) async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    final rotation = jsonEncode({
      'x': x,
      'y': y,
      'z': z,
    });
    
    await _unityWidgetController?.postMessage(
      'ModelController',
      'RotateModel',
      rotation,
    );
  }

  Future<void> setMaterial(String materialName, Map<String, dynamic> properties) async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    final materialData = jsonEncode({
      'name': materialName,
      'properties': properties,
    });
    
    await _unityWidgetController?.postMessage(
      'MaterialController',
      'SetMaterial',
      materialData,
    );
  }

  Future<void> setLighting(String lightType, Map<String, dynamic> properties) async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    final lightingData = jsonEncode({
      'type': lightType,
      'properties': properties,
    });
    
    await _unityWidgetController?.postMessage(
      'LightingController',
      'SetLighting',
      lightingData,
    );
  }

  Future<void> highlightBodyPart(String bodyPartName, Color color) async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    final highlightData = jsonEncode({
      'bodyPart': bodyPartName,
      'color': {
        'r': color.red / 255,
        'g': color.green / 255,
        'b': color.blue / 255,
        'a': color.alpha / 255,
      },
    });
    
    await _unityWidgetController?.postMessage(
      'BodyPartController',
      'HighlightBodyPart',
      highlightData,
    );
  }

  Future<void> resetHighlights() async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    await _unityWidgetController?.postMessage(
      'BodyPartController',
      'ResetHighlights',
      '',
    );
  }

  Future<void> takeScreenshot() async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    await _unityWidgetController?.postMessage(
      'ScreenshotController',
      'TakeScreenshot',
      '',
    );
  }

  void dispose() {
    _unityWidgetController = null;
    _messageStreamController.close();
  }
} 