import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:js/js.dart';
import '../services/model_loader_service.dart';
import '../config.dart';

@JS('window.ModelViewerCallback')
class ModelViewerCallback {
  external static void postMessage(String message);
}

class EnhancedThreeViewerWidget extends StatefulWidget {
  final String modelUrl;
  final String? fallbackModelUrl;
  final bool autoRotate;
  final bool showControls;
  final ValueChanged<bool>? onModelLoaded;

  const EnhancedThreeViewerWidget({
    Key? key,
    required this.modelUrl,
    this.fallbackModelUrl,
    this.autoRotate = false,
    this.showControls = true,
    this.onModelLoaded,
  }) : super(key: key);

  @override
  EnhancedThreeViewerWidgetState createState() => EnhancedThreeViewerWidgetState();
}

class EnhancedThreeViewerWidgetState extends State<EnhancedThreeViewerWidget> {
  late html.IFrameElement _iframe;
  final String _viewerId = 'enhanced_three_viewer_${DateTime.now().millisecondsSinceEpoch}';
  bool _isLoaded = false;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _loadingTimer;
  final ModelLoaderService _modelLoaderService = ModelLoaderService();
  StreamSubscription? _messageSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupViewer();
    _startLoadingTimer();
    _setupMessageListener();
  }
  
  @override
  void didUpdateWidget(EnhancedThreeViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelUrl != widget.modelUrl) {
      _tearDown();
      _setupViewer();
      _startLoadingTimer();
    }
  }
  
  void _setupMessageListener() {
    // Set up message listener for iframe communication
    _messageSubscription = html.window.onMessage.listen((html.MessageEvent event) {
      // Check if message is for us by checking the source
      if (event.source == _iframe.contentWindow) {
        if (event.data == 'modelLoaded') {
          setState(() {
            _isLoaded = true;
            _isLoading = false;
            _errorMessage = null;
          });
          widget.onModelLoaded?.call(true);
          _modelLoaderService.notifyModelLoaded(widget.modelUrl, true);
          _loadingTimer?.cancel();
        } else if (event.data == 'modelLoadError') {
          setState(() {
            _isLoaded = false;
            _isLoading = false;
            _errorMessage = 'Failed to load model';
          });
          widget.onModelLoaded?.call(false);
          _modelLoaderService.notifyModelLoaded(widget.modelUrl, false);
          _loadingTimer?.cancel();
        }
      }
    });
  }
  
  void _startLoadingTimer() {
    // Set a timeout for model loading
    _loadingTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Model loading timed out';
        });
        widget.onModelLoaded?.call(false);
        _modelLoaderService.notifyModelLoaded(widget.modelUrl, false);
      }
    });
  }
  
  void _setupViewer() {
    // Create the iframe element
    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'transparent'
      ..srcdoc = _generateHtml();
    
    // Register the view factory for this instance
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewerId, (int viewId) => _iframe);
  }
  
  void _tearDown() {
    _loadingTimer?.cancel();
    _messageSubscription?.cancel();
  }
  
  // Helper method to generate JavaScript code with proper escaping of template literals
  String _generateJsCode() {
    // Prepare the model URLs
    String processedModelUrl = _prepareModelUrl(widget.modelUrl);
    String fallbackUrl = widget.fallbackModelUrl != null ? 
        _prepareModelUrl(widget.fallbackModelUrl!) : '';
    
    // Define the JavaScript code with escaped template literals for Dart
    return '''
    // Define callback object to communicate with Flutter
    window.ModelViewerCallback = {
      postMessage: function(message) {
        // Post message to parent frame (Flutter)
        window.parent.postMessage(message, '*');
      }
    };
    
    // Initialize viewer and load model
    document.addEventListener('DOMContentLoaded', function() {
      console.log('Initializing EnhancedThreeViewer');
      
      // Create viewer
      const viewer = new EnhancedThreeViewer('container');
      console.log('Viewer created, loading model: $processedModelUrl');
      
      // Custom callback for model loading
      viewer.modelLoadedCallback = function(success) {
        console.log('Model load result:', success);
        window.parent.postMessage(success ? 'modelLoaded' : 'modelLoadError', '*');
      };
      
      // Function to try loading alternative model paths if the main one fails
      function loadModelWithFallbacks() {
        // Try the primary URL first
        console.log('Attempting to load primary URL: $processedModelUrl');
        
        // Track failed attempts to avoid infinite loops
        let attemptsMade = 0;
        const maxAttempts = 3;
        
        // Add fetch options to handle CORS issues
        const corsOptions = {
          method: 'GET',
          mode: 'cors',
          credentials: 'same-origin',
          headers: {
            'Accept': 'model/gltf-binary,*/*'
          }
        };
        
        const noCorsOptions = {
          method: 'GET',
          mode: 'no-cors'
        };
        
        // Function to attempt loading with different options
        function attemptLoad(url, options, isFallback) {
          attemptsMade++;
          
          // Update loading status
          const loadingElement = document.getElementById('loading-indicator');
          if (loadingElement) {
            const msgElement = loadingElement.querySelector('div:not(.loading-spinner)');
            if (msgElement) {
              if (isFallback) {
                msgElement.textContent = 'Loading fallback model...';
              } else {
                msgElement.textContent = options ? 
                  'Loading model with ' + options.mode + ' mode...' : 
                  'Loading model...';
              }
            }
          }
          
          // If options are provided, first check access with fetch
          if (options) {
            return fetch(url, options)
              .then(response => {
                if (!response.ok && options.mode === 'cors') {
                  console.warn('Fetch failed with ' + options.mode + ' mode: ' + response.status);
                  throw new Error('HTTP error: ' + response.status);
                }
                // If no-cors mode or fetch succeeded, proceed to load model
                return loadWithViewer(url);
              })
              .catch(error => {
                console.error('Error fetching ' + url + ' with ' + options.mode + ' mode:', error);
                // Try next approach if available
                return tryNextApproach(url, isFallback);
              });
          } else {
            // Direct loading without fetch check
            return loadWithViewer(url);
          }
        }
        
        // Function to load model with viewer
        function loadWithViewer(url) {
          return viewer.loadModel(url)
            .then(function(success) {
              if (success) {
                console.log('Model loaded successfully:', url);
                return true;
              } else {
                throw new Error('Model loading failed in viewer');
              }
            });
        }
        
        // Function to try next approach or fallback
        function tryNextApproach(url, isFallback) {
          if (attemptsMade >= maxAttempts) {
            if (!isFallback && '${fallbackUrl.isNotEmpty}' === 'true') {
              // Reset attempts for fallback
              attemptsMade = 0;
              console.log('Maximum attempts reached, trying fallback URL');
              return attemptLoad('$fallbackUrl', corsOptions, true);
            } else {
              console.error('All loading attempts exhausted');
              window.parent.postMessage('modelLoadError', '*');
              return Promise.reject(new Error('All loading attempts failed'));
            }
          }
          
          if (attemptsMade === 1) {
            // Try with no-cors
            return attemptLoad(url, noCorsOptions, isFallback);
          } else if (attemptsMade === 2) {
            // Try direct loader without fetch
            return attemptLoad(url, null, isFallback);
          } else if (!isFallback && '${fallbackUrl.isNotEmpty}' === 'true') {
            // Reset attempts for fallback
            attemptsMade = 0;
            return attemptLoad('$fallbackUrl', corsOptions, true);
          } else {
            console.error('All loading approaches failed');
            window.parent.postMessage('modelLoadError', '*');
            return Promise.reject(new Error('All loading approaches failed'));
          }
        }
        
        // Start the loading process
        return attemptLoad('$processedModelUrl', corsOptions, false)
          .catch(error => {
            console.error('Final loading error:', error);
            window.parent.postMessage('modelLoadError', '*');
          });
      }
      
      // Start loading process with fallbacks
      loadModelWithFallbacks();
        
      // Set auto-rotate if needed
      if (${widget.autoRotate}) {
        viewer.enableAutoRotate(true);
      }
      
      // Set controls enabled/disabled
      viewer.enableControls(${widget.showControls});
    });
    ''';
  }
  
  // Helper method to prepare model URLs
  String _prepareModelUrl(String url) {
    // Normalize backslashes to forward slashes (for Windows paths)
    String processedUrl = url.replaceAll('\\', '/');
    
    // Log the original path for debugging
    print('EnhancedThreeViewer: Original model URL: $processedUrl');
    
    if (!processedUrl.startsWith('http')) {
      // Make sure the URL starts with a slash if it doesn't have one
      if (!processedUrl.startsWith('/')) {
        processedUrl = '/$processedUrl';
      }
      
      // Add the server prefix if it's a relative path
      processedUrl = '${Config.apiBaseUrl}$processedUrl';
      
      // Log the actual URL being used for debugging
      print('EnhancedThreeViewer: Processing model URL: $processedUrl');
    }
    
    return processedUrl;
  }
  
  String _generateHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Cross-Origin-Opener-Policy" content="same-origin">
  <meta http-equiv="Cross-Origin-Embedder-Policy" content="require-corp">
  <title>Enhanced 3D Viewer</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      overflow: hidden;
      width: 100vw;
      height: 100vh;
      background-color: transparent;
    }
    
    #container {
      width: 100%;
      height: 100%;
      background-color: transparent;
    }
    
    #loading-indicator {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      background-color: rgba(0, 0, 0, 0.5);
      color: white;
      z-index: 100;
    }
    
    .loading-spinner {
      border: 4px solid rgba(255, 255, 255, 0.3);
      border-radius: 50%;
      border-top: 4px solid white;
      width: 40px;
      height: 40px;
      animation: spin 1s linear infinite;
      margin-bottom: 10px;
    }
    
    .loading-text {
      text-align: center;
      max-width: 80%;
      font-family: sans-serif;
    }
    
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
  
  <!-- Load Three.js and related libraries from CDN -->
  <script src="https://cdn.jsdelivr.net/npm/three@0.149.0/build/three.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.149.0/examples/js/loaders/GLTFLoader.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.149.0/examples/js/loaders/DRACOLoader.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.149.0/examples/js/controls/OrbitControls.js"></script>
  <script src="/assets/js/enhanced_three_viewer.js"></script>
</head>
<body>
  <div id="container"></div>
  <div id="loading-indicator">
    <div class="loading-spinner"></div>
    <div class="loading-text">Loading 3D Model... This may take up to 2 minutes depending on the model size and your connection speed.</div>
  </div>
  
  <script>
    ${_generateJsCode()}
  </script>
</body>
</html>
''';
  }
  
  @override
  void dispose() {
    _loadingTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The 3D viewer
        HtmlElementView(
          viewType: _viewerId,
        ),
        
        // Loading indicator (shown by the HTML itself)
        
        // Error message if needed
        if (_errorMessage != null && !_isLoading && !_isLoaded)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.modelUrl.split('/').last,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Public methods that can be called from outside
  void resetView() {
    _callJavaScriptMethod('resetView');
  }
  
  void setAutoRotate(bool enabled) {
    _callJavaScriptMethod('enableAutoRotate', [enabled]);
  }
  
  void setBackgroundColor(Color color) {
    final colorHex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    _callJavaScriptMethod('setBackgroundColor', [colorHex]);
  }
  
  void visualizeInjury(String bodyPart, {String status = 'active', String severity = 'moderate', String? injury}) {
    _callJavaScriptMethod('visualizeInjury', [
      bodyPart,
      status,
      severity,
      injury
    ]);
  }
  
  // Helper method to call JavaScript methods in the iframe
  void _callJavaScriptMethod(String methodName, [List<dynamic>? args]) {
    try {
      if (_iframe.contentWindow == null) {
        print('Cannot call JavaScript method: iframe contentWindow is null');
        return;
      }
      
      final argsString = args != null 
          ? args.map((arg) => arg == null ? 'null' : '"${arg.toString()}"').join(',') 
          : '';
      
      final script = '''
        if (window.viewer && typeof window.viewer.$methodName === 'function') {
          window.viewer.$methodName($argsString);
        } else {
          console.error('Method $methodName not found on viewer');
        }
      ''';
      
      _iframe.contentWindow?.postMessage({
        'type': 'executeScript',
        'script': script
      }, '*');
      
    } catch (e) {
      print('Error calling JavaScript method $methodName: $e');
    }
  }
} 