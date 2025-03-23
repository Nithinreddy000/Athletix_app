import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'package:performance_analysis/services/unity_service.dart';

class UnityModelViewer extends StatefulWidget {
  final String modelPath;
  final bool autoLoad;
  final double initialScale;
  final Map<String, dynamic>? initialLighting;
  final Function(Map<String, dynamic>)? onUnityMessage;
  final Function(UnityWidgetController)? onUnityCreated;
  final Function()? onModelLoaded;

  const UnityModelViewer({
    Key? key,
    required this.modelPath,
    this.autoLoad = true,
    this.initialScale = 1.0,
    this.initialLighting,
    this.onUnityMessage,
    this.onUnityCreated,
    this.onModelLoaded,
  }) : super(key: key);

  @override
  State<UnityModelViewer> createState() => _UnityModelViewerState();
}

class _UnityModelViewerState extends State<UnityModelViewer> {
  final UnityService _unityService = UnityService();
  bool _isLoading = true;
  bool _isModelLoaded = false;
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _scale = widget.initialScale;
    
    // Listen to Unity messages
    _unityService.onUnityMessage.listen((message) {
      if (widget.onUnityMessage != null) {
        widget.onUnityMessage!(message);
      }
      
      if (message['type'] == 'modelLoaded' && message['success'] == true) {
        setState(() {
          _isModelLoaded = true;
          _isLoading = false;
        });
        
        if (widget.onModelLoaded != null) {
          widget.onModelLoaded!();
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onUnityCreated(UnityWidgetController controller) {
    _unityService.setController(controller);
    
    if (widget.onUnityCreated != null) {
      widget.onUnityCreated!(controller);
    }
    
    setState(() {
      _isLoading = false;
    });
    
    if (widget.autoLoad) {
      _loadModel();
    }
    
    // Apply initial lighting if provided
    if (widget.initialLighting != null) {
      _unityService.setLighting('directional', widget.initialLighting!);
    }
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _unityService.loadModel(widget.modelPath);
    } catch (e) {
      debugPrint('Error loading model: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotationY += details.delta.dx * 0.01;
      _rotationX -= details.delta.dy * 0.01;
    });
    
    _unityService.rotateModel(_rotationX, _rotationY, 0);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_scale * details.scale).clamp(0.5, 5.0);
    });
    
    // Send scale to Unity
    _unityService.postMessage(
      'ModelController',
      'ScaleModel',
      _scale.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onPanUpdate: _onPanUpdate,
          onScaleUpdate: _onScaleUpdate,
          child: UnityWidget(
            onUnityCreated: _onUnityCreated,
            onUnityMessage: (message) {
              // This is handled by the UnityService
            },
            fullscreen: false,
          ),
        ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

// Extension method for the UnityService to make it easier to post messages
extension UnityServiceExtension on UnityService {
  Future<void> postMessage(String gameObject, String methodName, String message) async {
    if (_unityWidgetController == null) {
      throw Exception('Unity controller not initialized');
    }
    
    await _unityWidgetController?.postMessage(
      gameObject,
      methodName,
      message,
    );
  }
} 