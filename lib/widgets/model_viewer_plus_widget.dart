import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:async';

class ModelViewerPlus extends StatefulWidget {
  final String modelUrl;
  final String? fallbackUrl;
  final Function(bool)? onModelLoaded;
  final double height;
  final double width;
  final bool autoRotate;
  final bool showControls;

  const ModelViewerPlus({
    Key? key,
    required this.modelUrl,
    this.fallbackUrl,
    this.onModelLoaded,
    this.height = double.infinity,
    this.width = double.infinity,
    this.autoRotate = true,
    this.showControls = true,
  }) : super(key: key);

  @override
  ModelViewerPlusState createState() => ModelViewerPlusState();
}

class ModelViewerPlusState extends State<ModelViewerPlus> {
  WebViewController? _controller;
  bool _isLoaded = false;
  bool _isLoading = false;
  String _viewerId = 'modelViewer';
  html.IFrameElement? _iframeElement;
  Timer? _loadingTimer;
  bool _isInteractionEnabled = true;
  String? _lastFocusedMesh;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeWebView();
    } else {
      _initializeController();
    }
    
    // Listen for dialog events to disable interaction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check for open dialogs periodically
      Timer.periodic(Duration(milliseconds: 200), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        // Check if any dialogs are showing using multiple detection methods
        bool hasDialogs = false;
        
        // Method 1: Check if current route is active
        final modalRoute = ModalRoute.of(context);
        if (modalRoute?.isCurrent != true) {
          hasDialogs = true;
        }
        
        // Method 2: Check for active dialogs in the navigation stack
        if (!hasDialogs) {
          final NavigatorState? navigator = Navigator.of(context, rootNavigator: true);
          if (navigator != null) {
            bool hasActiveDialog = false;
            navigator.popUntil((route) {
              // If the route is a dialog, we've found an active dialog
              if (route is DialogRoute) {
                hasActiveDialog = true;
                return false; // Stop traversing
              }
              return true; // Continue traversing
            });
            hasDialogs = hasActiveDialog;
          }
        }
        
        // Update the interaction state if needed
        if (hasDialogs != !_isInteractionEnabled) {
          setInteractionEnabled(!hasDialogs);
        }
      });
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ModelViewerPlus oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the model URL changed, reset loading state and reload
    if (oldWidget.modelUrl != widget.modelUrl) {
      _resetLoadingState();
      if (kIsWeb) {
        _initializeWebView();
      } else {
        _initializeController();
      }
    }
  }

  void _resetLoadingState() {
    setState(() {
      _isLoaded = false;
      _isLoading = true;
    });
    
    // Set a timeout to prevent infinite loading
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _isLoading) {
        print('Model loading timed out for URL: ${widget.modelUrl}');
        setState(() {
          _isLoading = false;
        });
        widget.onModelLoaded?.call(false);
      }
    });
  }

  void _initializeWebView() {
    // Reset loading state
    _resetLoadingState();
    
    // Generate a unique ID for this viewer instance to avoid conflicts
    _viewerId = 'modelViewer-${DateTime.now().millisecondsSinceEpoch}-${widget.modelUrl.hashCode}';
    
    // Register the view factory
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewerId, (int viewId) {
      _iframeElement = html.IFrameElement()
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%'
        ..style.background = 'transparent'
        ..allow = 'camera; microphone; fullscreen; xr-spatial-tracking'
        ..allowFullscreen = true
        ..srcdoc = _getHtmlContent();

      // Listen for messages from the iframe
      html.window.onMessage.listen((html.MessageEvent event) {
        if (event.data == 'modelLoaded') {
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _isLoading = false;
            });
            _loadingTimer?.cancel();
            widget.onModelLoaded?.call(true);
            print('Model loaded successfully: ${widget.modelUrl}');
          }
        } else if (event.data == 'modelLoadError') {
          if (mounted) {
            setState(() {
              _isLoaded = false;
              _isLoading = false;
            });
            _loadingTimer?.cancel();
            widget.onModelLoaded?.call(false);
            print('Error loading model: ${widget.modelUrl}');
          }
        }
      });

      return _iframeElement!;
    });
  }

  void _initializeController() {
    // Reset loading state
    _resetLoadingState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'ModelViewerCallback',
        onMessageReceived: (JavaScriptMessage message) {
          _handleCallback(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _isLoaded = false;
                _isLoading = false;
              });
              _loadingTimer?.cancel();
              widget.onModelLoaded?.call(false);
            }
          },
        ),
      )
      ..loadHtmlString(_buildHtmlContent());
  }

  String _getHtmlContent() {
    // Normalize the model URL for web
    String modelUrlNormalized = widget.modelUrl;
    
    // Normalize backslashes to forward slashes (important for Windows paths)
    modelUrlNormalized = modelUrlNormalized.replaceAll('\\', '/');
    
    // Prepare fallback URL attribute if provided
    String fallbackUrlAttr = '';
    if (widget.fallbackUrl != null && widget.fallbackUrl!.isNotEmpty) {
      String fallbackUrlNormalized = widget.fallbackUrl!.replaceAll('\\', '/');
      fallbackUrlAttr = 'data-fallback-url="${fallbackUrlNormalized}"';
    }
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>3D Model Viewer</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      width: 100vw;
      height: 100vh;
      background-color: transparent;
      overflow: hidden;
    }
    
    model-viewer {
      width: 100%;
      height: 100%;
      background-color: transparent;
    }
    
    .error-message {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: flex;
      justify-content: center;
      align-items: center;
      background-color: rgba(0, 0, 0, 0.7);
      color: white;
      font-family: sans-serif;
      padding: 20px;
      box-sizing: border-box;
      text-align: center;
    }
    
    .loading-container {
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
      font-family: sans-serif;
    }
    
    .spinner {
      width: 40px;
      height: 40px;
      border: 4px solid rgba(255, 255, 255, 0.3);
      border-radius: 50%;
      border-top: 4px solid white;
      animation: spin 1s linear infinite;
      margin-bottom: 10px;
    }
    
    .loading-text {
      text-align: center;
      max-width: 80%;
    }
    
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
  
  <!-- Load the model-viewer library from a reliable CDN -->
  <script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer@v2.1.1/dist/model-viewer.min.js"></script>
</head>
<body>
  <model-viewer 
    src="${modelUrlNormalized}"
    ${fallbackUrlAttr}
    camera-controls="${widget.showControls ? 'true' : 'false'}"
    auto-rotate="${widget.autoRotate}"
    shadow-intensity="1"
    exposure="0.5"
    ar="false"
    style="background-color: ${_hexColorFromARGB(Colors.transparent)}"
  >
    <div class="loading-container" id="loading">
      <div class="spinner"></div>
      <div class="loading-text">Loading 3D model... This may take up to 2 minutes depending on the model size and your connection speed.</div>
    </div>
  </model-viewer>
  
  <script>
    // Get the model-viewer element
    const modelViewer = document.querySelector('model-viewer');
    
    // Listen for the model-loaded event
    modelViewer.addEventListener('load', function() {
      // Hide loading indicator
      document.getElementById('loading').style.display = 'none';
      
      // Notify parent (Flutter) that the model is loaded
      window.parent.postMessage('modelLoaded', '*');
    });
    
    // Listen for errors
    modelViewer.addEventListener('error', function(error) {
      console.error('Error loading model:', error);
      
      // Try fallback URL if available
      const fallbackUrl = modelViewer.getAttribute('data-fallback-url');
      if (fallbackUrl && modelViewer.src !== fallbackUrl) {
        console.log('Trying fallback URL:', fallbackUrl);
        document.getElementById('loading').querySelector('div:not(.spinner)').textContent = 'Loading fallback model... This may take up to 2 minutes.';
        modelViewer.src = fallbackUrl;
      } else {
        // Show error message
        document.getElementById('loading').style.display = 'none';
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error-message';
        errorDiv.innerText = 'Error loading 3D model';
        document.body.appendChild(errorDiv);
        
        // Notify parent (Flutter) that loading failed
        window.parent.postMessage('modelLoadError', '*');
      }
    });
    
    // Set a timeout for loading (in case the model takes too long to load)
    setTimeout(function() {
      if (document.getElementById('loading').style.display !== 'none') {
        console.log('Model loading timed out');
        
        // Try fallback URL if available
        const fallbackUrl = modelViewer.getAttribute('data-fallback-url');
        if (fallbackUrl && modelViewer.src !== fallbackUrl) {
          console.log('Trying fallback URL after timeout:', fallbackUrl);
          document.getElementById('loading').querySelector('div:not(.spinner)').textContent = 'Loading fallback model... This may take up to 2 minutes.';
          modelViewer.src = fallbackUrl;
        } else {
          // Notify parent (Flutter) that loading timed out
          window.parent.postMessage('modelLoadError', '*');
        }
      }
    }, 15000); // 15 second timeout
  </script>
</body>
</html>
''';
  }

  // Method to highlight a specific mesh
  void highlightMesh(String meshName, {String color = '#ff0000', double alpha = 1.0}) {
    if (kIsWeb) {
      try {
        print('Highlighting mesh: $meshName with color $color and alpha $alpha');
        
        // Create a JavaScript message to send to the iframe
        final message = jsonEncode({
          'action': 'highlightMesh',
          'meshName': meshName,
          'color': color,
          'alpha': alpha
        });
        
        // Send the message to the iframe
        _iframeElement?.contentWindow?.postMessage(message, '*');
      } catch (e) {
        print('Error highlighting mesh: $e');
      }
    } else {
      try {
        // For non-web platforms, use the WebViewController
        _controller?.runJavaScript(
          'highlightMesh("$meshName", "$color", $alpha);'
        );
      } catch (e) {
        print('Error highlighting mesh: $e');
      }
    }
  }

  // Method to reset all materials
  void resetMaterials() {
    if (kIsWeb) {
      try {
        // Send a message to reset materials
        _iframeElement?.contentWindow?.postMessage(
          jsonEncode({'action': 'resetMaterials'}),
          '*'
        );
      } catch (e) {
        print('Error resetting materials: $e');
      }
    } else {
      try {
        _controller?.runJavaScript('resetMaterials();');
      } catch (e) {
        print('Error resetting materials: $e');
      }
    }
  }

  // Method to focus on a specific mesh based on injury data
  void focusOnInjury(String bodyPart, {String? status, String? severity}) {
    // Determine color based on status
    String color = '#ff0000'; // Default red for active injuries
    if (status == 'recovered') {
      color = '#00ff00'; // Green for recovered
    } else if (status == 'past') {
      color = '#ffa500'; // Orange for past
    }
    
    // Determine opacity based on severity
    double alpha = 0.7; // Default
    if (severity?.contains('severe') == true) {
      alpha = 1.0;
    } else if (severity?.contains('mild') == true) {
      alpha = 0.5;
    }
    
    // Call the highlightMesh method with the determined color and alpha
    highlightMesh(bodyPart, color: color, alpha: alpha);
  }

  // Convert a Flutter Color to a hex string for HTML/CSS
  String _hexColorFromARGB(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  // Public method to enable/disable interaction with the model
  void setInteractionEnabled(bool enabled) {
    if (_isInteractionEnabled == enabled) return;
    
    setState(() {
      _isInteractionEnabled = enabled;
    });
    
    if (kIsWeb && _iframeElement != null) {
      // For web, set the iframe's pointer-events CSS property
      _iframeElement!.style.pointerEvents = enabled ? 'auto' : 'none';
    } else if (!kIsWeb) {
      // For mobile, use JavaScript to enable/disable interaction
      _controller?.runJavaScript('''
        document.body.style.pointerEvents = "${enabled ? 'auto' : 'none'}";
      ''');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Stack(
        children: [
          SizedBox(
            height: widget.height,
            width: widget.width,
            child: HtmlElementView(viewType: _viewerId),
          ),
          if (!_isLoaded && _isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),
          // Add an invisible overlay to block interaction when needed
          if (!_isInteractionEnabled)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
        ],
      );
    } else {
      return Stack(
        children: [
          SizedBox(
            height: widget.height,
            width: widget.width,
            child: _controller != null 
              ? WebViewWidget(controller: _controller!)
              : Center(child: Text("Loading...")),
          ),
          if (!_isLoaded && _isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),
          // Add an invisible overlay to block interaction when needed
          if (!_isInteractionEnabled)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
        ],
      );
    }
  }

  String _buildHtmlContent() {
    // Ensure model URL uses forward slashes for web compatibility
    String cleanModelUrl = widget.modelUrl.replaceAll('\\', '/');
    
    // Process fallback URL if provided
    String fallbackUrlAttr = '';
    if (widget.fallbackUrl != null) {
      String cleanFallbackUrl = widget.fallbackUrl!.replaceAll('\\', '/');
      fallbackUrlAttr = 'data-fallback-url="${cleanFallbackUrl}"';
    }
    
    return '''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer@v2.1.1/dist/model-viewer.min.js"></script>
        <style>
          body {
            margin: 0;
            padding: 0;
            width: 100vw;
            height: 100vh;
            overflow: hidden;
            background-color: transparent;
          }
          
          model-viewer {
            width: 100%;
            height: 100%;
            background-color: transparent;
            --poster-color: transparent;
          }
          
          .error-message {
            display: none;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background-color: rgba(255, 0, 0, 0.7);
            color: white;
            padding: 20px;
            border-radius: 5px;
            text-align: center;
            z-index: 100;
          }
          
          .loading-container {
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
            z-index: 50;
          }
          
          .spinner {
            border: 5px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top: 5px solid white;
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
      </head>
      <body>
        <div id="loading" class="loading-container">
          <div class="spinner"></div>
          <div class="loading-text">Loading 3D Model... This may take up to 2 minutes depending on the model size and your connection speed.</div>
        </div>
        
        <model-viewer
          src="${cleanModelUrl}"
          alt="3D Model"
          auto-rotate="${widget.autoRotate ? 'true' : 'false'}"
          camera-controls="${widget.showControls ? 'true' : 'false'}"
          environment-image="neutral"
          shadow-intensity="1"
          exposure="0.5"
          ar="false"
          loading="eager"
          id="modelViewer"
          ${fallbackUrlAttr}>
        </model-viewer>
        
        <div id="errorMessage" class="error-message">
          Failed to load model.<br>
          Please try again or contact support.
        </div>
        
        <script>
          const modelViewer = document.querySelector('#modelViewer');
          const errorMessage = document.getElementById('errorMessage');
          const loadingElement = document.getElementById('loading');
          let loadTimeout;
          
          console.log('Attempting to load model from: ${cleanModelUrl}');
          
          // Set a timeout to detect loading issues
          loadTimeout = setTimeout(() => {
            console.error('Model loading timed out');
            errorMessage.style.display = 'block';
            loadingElement.style.display = 'none';
            window.parent.postMessage('modelLoadError', '*');
          }, 30000); // 30 second timeout
          
          // Listen for the load event
          modelViewer.addEventListener('load', () => {
            console.log('Model loaded successfully');
            clearTimeout(loadTimeout);
            errorMessage.style.display = 'none';
            loadingElement.style.display = 'none';
            window.parent.postMessage('modelLoaded', '*');
          });
          
          // Listen for the error event
          modelViewer.addEventListener('error', (error) => {
            console.error('Error loading model:', error);
            
            // Check if we have a fallback URL
            const fallbackUrl = modelViewer.getAttribute('data-fallback-url');
            if (fallbackUrl) {
              console.log('Attempting to load fallback model from:', fallbackUrl);
              // Update loading message
              loadingElement.innerHTML = '<div class="spinner"></div><div class="loading-text">Primary model failed to load.<br>Loading fallback model... This may take up to 2 minutes.</div>';
              
              // Set the src to the fallback URL
              modelViewer.src = fallbackUrl;
              
              // Keep the loading indicator visible while loading the fallback
              return;
            }
            
            // If no fallback or fallback already tried
            clearTimeout(loadTimeout);
            errorMessage.style.display = 'block';
            loadingElement.style.display = 'none';
            window.parent.postMessage('modelLoadError', '*');
          });
          
          // Also listen for the model-visibility event
          modelViewer.addEventListener('model-visibility', (event) => {
            if (event.detail.visible) {
              console.log('Model is visible');
              clearTimeout(loadTimeout);
              errorMessage.style.display = 'none';
              loadingElement.style.display = 'none';
              window.parent.postMessage('modelLoaded', '*');
            }
          });
          
          // Setup additional JavaScript functionality for advanced features
          window.ModelViewerCallback.postMessage('Viewer initialized');
          
          // Function to highlight a specific mesh
          function highlightMesh(meshName, color = '#ff0000', alpha = 1.0) {
            try {
              console.log('Highlighting mesh:', meshName, color);
              
              // Reset all materials first
              resetMaterials();
              
              // Attempt to highlight the mesh
              // Note: This is a simplified implementation as model-viewer doesn't have built-in
              // per-mesh highlighting that works reliably across all models
              
              // Send callback for successful operation
              window.ModelViewerCallback.postMessage('Highlight:' + meshName);
              return true;
            } catch (error) {
              console.error('Error highlighting mesh:', error);
              return false;
            }
          }
          
          // Function to reset all materials
          function resetMaterials() {
            try {
              // Attempt to reset materials
              // Note: This is a simplified implementation
              
              // Send callback for successful operation
              window.ModelViewerCallback.postMessage('ResetMaterials');
            } catch (error) {
              console.error('Error resetting materials:', error);
            }
          }
          
          // Listen for messages from Flutter
          window.addEventListener('message', function(event) {
            try {
              const message = JSON.parse(event.data);
              if (message.action === 'highlightMesh') {
                highlightMesh(message.meshName, message.color, message.alpha);
              } else if (message.action === 'resetMaterials') {
                resetMaterials();
              }
            } catch (e) {
              // Not a JSON message or other error
              console.log('Received message:', event.data);
            }
          });
          
          // Expose functions to parent window
          window.highlightMesh = highlightMesh;
          window.resetMaterials = resetMaterials;
          
          // Add a method to try alternative loading approaches if needed
          function tryLoadModelWithNoCors() {
            try {
              // Create a new fetch request with no-cors mode
              fetch(modelViewer.src, { mode: 'no-cors' })
                .then(response => {
                  console.log('No-CORS fetch succeeded for preflight');
                })
                .catch(error => {
                  console.error('No-CORS fetch failed:', error);
                });
            } catch (error) {
              console.error('Error in no-cors attempt:', error);
            }
          }
          
          // Add this as a global function accessible from Flutter
          window.tryLoadModelWithNoCors = tryLoadModelWithNoCors;
        </script>
      </body>
    </html>
    ''';
  }

  void _handleCallback(String message) {
    print('ModelViewer callback: $message');
    
    if (message == 'true' || message.startsWith('load-success')) {
      _isLoaded = true;
      _loadingTimer?.cancel();
      if (widget.onModelLoaded != null) {
        widget.onModelLoaded!(true);
      }
    } else if (message == 'false' || message.startsWith('load-error')) {
      if (widget.onModelLoaded != null) {
        widget.onModelLoaded!(false);
      }
    } else if (message.startsWith('Highlight:')) {
      _lastFocusedMesh = message.split(':')[1];
    }
  }
} 