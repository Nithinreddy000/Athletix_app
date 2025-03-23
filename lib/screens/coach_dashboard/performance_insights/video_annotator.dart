import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:js' as js;

/// A widget that allows drawing annotations on videos using the Vannot library
class VideoAnnotator extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;
  final double fps;
  final Function(Map<String, dynamic>)? onAnnotationSaved;
  final Function(bool)? onAnnotatorReady;

  const VideoAnnotator({
    Key? key,
    required this.videoUrl,
    this.width = 1920,
    this.height = 1080,
    this.fps = 30,
    this.onAnnotationSaved,
    this.onAnnotatorReady,
  }) : super(key: key);

  @override
  _VideoAnnotatorState createState() => _VideoAnnotatorState();
}

class _VideoAnnotatorState extends State<VideoAnnotator> {
  final String viewType = 'vannot-player-${DateTime.now().millisecondsSinceEpoch}';
  final String containerId = 'vannot-container-${DateTime.now().millisecondsSinceEpoch}';
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isDrawingEnabled = false;
  bool _isDebugMode = true; // Set to true to enable debug messages

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
    _debugLog('VideoAnnotator initialized');
  }

  @override
  void didUpdateWidget(VideoAnnotator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the video URL changed, reinitialize the annotator
    if (oldWidget.videoUrl != widget.videoUrl) {
      _debugLog('Video URL changed, reinitializing annotator');
      _destroyAnnotator();
      _initializeAnnotator();
    }
  }

  void _debugLog(String message) {
    if (_isDebugMode) {
      print('VideoAnnotator: $message');
    }
  }

  void _registerViewFactory() {
    try {
      // Register the view factory
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          _debugLog('Creating container with ID: $containerId');
          // Create a container for the Vannot player
          final container = html.DivElement()
            ..id = containerId
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.border = 'none'
            ..style.overflow = 'hidden';
          
          // Set up message handler for communication from JavaScript
          _setupMessageHandler();
          
          // Initialize the annotator after the container is created
          Future.delayed(Duration(milliseconds: 500), () {
            _initializeAnnotator();
          });
          
          return container;
        },
      );
    } catch (e) {
      _debugLog('Error registering view factory: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error registering view factory: $e';
      });
    }
  }

  void _setupMessageHandler() {
    try {
      _debugLog('Setting up message handler');
      // Create a JavaScript message handler
      js.context['flutterVannotBridge'] = js.JsObject.jsify({
        'postMessage': (String message) {
          try {
            final data = jsonDecode(message);
            _debugLog('Received message from Vannot: ${data['type']}');
            
            if (data['type'] == 'ready') {
              setState(() {
                _isInitialized = data['success'] == true;
                if (!_isInitialized && data['error'] != null) {
                  _hasError = true;
                  _errorMessage = data['error'];
                  _debugLog('Initialization error: ${data['error']}');
                } else {
                  _hasError = false;
                  _debugLog('Vannot initialized successfully');
                }
              });
              
              if (widget.onAnnotatorReady != null) {
                widget.onAnnotatorReady!(_isInitialized);
              }
              
              // Automatically pause the video when ready
              pauseVideo();
            } else if (data['type'] == 'save' && widget.onAnnotationSaved != null) {
              _debugLog('Annotations saved');
              widget.onAnnotationSaved!(data['data']);
            } else if (data['type'] == 'paused') {
              _debugLog('Video paused by annotator');
            } else if (data['type'] == 'playing') {
              _debugLog('Video playing by annotator');
            }
          } catch (e) {
            _debugLog('Error processing message from Vannot: $e');
          }
        }
      });
    } catch (e) {
      _debugLog('Error setting up message handler: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error setting up message handler: $e';
      });
    }
  }

  void _initializeAnnotator() {
    try {
      _debugLog('Initializing Vannot with URL: ${widget.videoUrl}');
      
      // Check if the vannot bridge is available
      if (js.context['vannotBridge'] == null) {
        throw Exception('Vannot bridge not found. Make sure vannot.js is loaded.');
      }
      
      // Call the JavaScript function to initialize Vannot
      final result = js.context.callMethod('eval', [
        'window.vannotBridge.init("${widget.videoUrl}", "$containerId", ${widget.width}, ${widget.height}, ${widget.fps})'
      ]);
      
      _debugLog('Vannot initialization result: $result');
    } catch (e) {
      _debugLog('Error initializing Vannot: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _destroyAnnotator() {
    try {
      _debugLog('Destroying Vannot');
      // Call the JavaScript function to destroy Vannot
      js.context.callMethod('eval', ['window.vannotBridge.destroy()']);
    } catch (e) {
      _debugLog('Error destroying Vannot: $e');
    }
  }

  // Toggle drawing mode
  void toggleDrawMode(bool enable) {
    try {
      _debugLog('Toggling draw mode: $enable');
      setState(() {
        _isDrawingEnabled = enable;
      });
      
      js.context.callMethod('eval', ['window.vannotBridge.toggleDrawMode($enable)']);
    } catch (e) {
      _debugLog('Error toggling draw mode: $e');
    }
  }

  // Get current annotations
  String? getAnnotations() {
    try {
      _debugLog('Getting annotations');
      return js.context.callMethod('eval', ['window.vannotBridge.getAnnotations()']);
    } catch (e) {
      _debugLog('Error getting annotations: $e');
      return null;
    }
  }
  
  // Pause the video
  void pauseVideo() {
    try {
      _debugLog('Pausing video');
      js.context.callMethod('eval', ['window.vannotBridge.pauseVideo()']);
    } catch (e) {
      _debugLog('Error pausing video: $e');
    }
  }
  
  // Play the video
  void playVideo() {
    try {
      _debugLog('Playing video');
      js.context.callMethod('eval', ['window.vannotBridge.playVideo()']);
    } catch (e) {
      _debugLog('Error playing video: $e');
    }
  }

  @override
  void dispose() {
    _debugLog('Disposing VideoAnnotator');
    _destroyAnnotator();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The Vannot player
        HtmlElementView(viewType: viewType),
        
        // Loading indicator
        if (!_isInitialized && !_hasError)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading video annotator...',
                  style: TextStyle(color: Colors.white70),
                ),
                if (_isDebugMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Container ID: $containerId',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        
        // Error message
        if (_hasError)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  'Failed to load video annotator',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _initializeAnnotator,
                  icon: Icon(Icons.refresh),
                  label: Text('Try Again'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A controller for the VideoAnnotator widget
class VideoAnnotatorController {
  _VideoAnnotatorState? _state;

  VideoAnnotatorController._(this._state);

  factory VideoAnnotatorController() {
    return VideoAnnotatorController._(null);
  }

  void attach(_VideoAnnotatorState state) {
    _state = state;
  }

  void toggleDrawMode(bool enable) {
    _state?.toggleDrawMode(enable);
  }

  String? getAnnotations() {
    return _state?.getAnnotations();
  }
  
  void pauseVideo() {
    _state?.pauseVideo();
  }
  
  void playVideo() {
    _state?.playVideo();
  }
} 