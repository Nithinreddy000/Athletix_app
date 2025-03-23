import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:js/js_util.dart' as js_util;

class CustomModelViewer extends StatefulWidget {
  final String modelUrl;
  final double width;
  final double height;
  final Color backgroundColor;
  final bool autoRotate;
  final bool showControls;

  const CustomModelViewer({
    Key? key,
    required this.modelUrl,
    this.width = double.infinity,
    this.height = 400,
    this.backgroundColor = Colors.black,
    this.autoRotate = true,
    this.showControls = true,
  }) : super(key: key);

  @override
  _CustomModelViewerState createState() => _CustomModelViewerState();
}

class _CustomModelViewerState extends State<CustomModelViewer> {
  // Flutter GL properties
  FlutterGlPlugin? flutterGlPlugin;
  int? fboId;
  dynamic gl;
  dynamic sourceTexture;
  bool isInitialized = false;
  bool isLoading = true;
  String? errorMessage;
  double dpr = 1.0;
  bool disposed = false;
  
  // Web-specific properties
  html.CanvasElement? canvas;
  html.Element? container;
  dynamic threeJs;
  dynamic scene;
  dynamic camera;
  dynamic renderer;
  dynamic controls;
  dynamic model;
  int? animationId;

  @override
  void initState() {
    super.initState();
    _initializeViewer();
  }

  Future<void> _initializeViewer() async {
    try {
      if (kIsWeb) {
        await _initializeWebViewer();
      } else {
        await _initializeNativeViewer();
      }
    } catch (e) {
      print("Error initializing model viewer: $e");
      setState(() {
        errorMessage = "Failed to initialize 3D viewer: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _initializeWebViewer() async {
    try {
      // Create a container for the canvas
      container = html.DivElement()
        ..id = 'model-container-${DateTime.now().millisecondsSinceEpoch}'
        ..style.width = '100%'
        ..style.height = '100%';
      
      // Create a canvas element
      canvas = html.CanvasElement()
        ..width = (widget.width * window.devicePixelRatio).toInt()
        ..height = (widget.height * window.devicePixelRatio).toInt()
        ..style.width = '100%'
        ..style.height = '100%';
      
      container!.append(canvas!);
      
      // Add the container to the DOM
      html.document.body!.append(container!);
      
      // Load Three.js from CDN
      await _loadThreeJs();
      
      // Initialize Three.js scene
      await _initThreeJsScene();
      
      // Load the model
      await _loadModelWeb();
      
      // Start rendering
      _animateWeb();
      
      setState(() {
        isLoading = false;
        isInitialized = true;
      });
    } catch (e) {
      print("Error initializing web viewer: $e");
      setState(() {
        errorMessage = "Failed to initialize web 3D viewer: $e";
        isLoading = false;
      });
    }
  }
  
  Future<void> _loadThreeJs() async {
    // Check if Three.js is already loaded
    if (js_util.getProperty(html.window, 'THREE') != null) {
      threeJs = js_util.getProperty(html.window, 'THREE');
      return;
    }
    
    // Load Three.js script
    final threeScript = html.ScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/three@0.132.2/build/three.min.js'
      ..type = 'text/javascript';
    
    // Load GLTFLoader script
    final gltfLoaderScript = html.ScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/three@0.132.2/examples/js/loaders/GLTFLoader.js'
      ..type = 'text/javascript';
    
    // Load OrbitControls script
    final orbitControlsScript = html.ScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/three@0.132.2/examples/js/controls/OrbitControls.js'
      ..type = 'text/javascript';
    
    // Add scripts to document
    html.document.head!.append(threeScript);
    
    // Wait for Three.js to load
    Completer<void> threeJsLoaded = Completer<void>();
    threeScript.onLoad.listen((_) {
      threeJsLoaded.complete();
    });
    await threeJsLoaded.future;
    
    // Now load the other scripts
    html.document.head!.append(gltfLoaderScript);
    html.document.head!.append(orbitControlsScript);
    
    // Wait for all scripts to load
    Completer<void> loadersLoaded = Completer<void>();
    orbitControlsScript.onLoad.listen((_) {
      loadersLoaded.complete();
    });
    await loadersLoaded.future;
    
    // Get the THREE object
    threeJs = js_util.getProperty(html.window, 'THREE');
  }
  
  Future<void> _initThreeJsScene() async {
    // Create scene
    scene = js_util.callConstructor(
      js_util.getProperty(threeJs, 'Scene'),
      [],
    );
    
    // Set background color
    js_util.setProperty(
      scene,
      'background',
      js_util.callConstructor(
        js_util.getProperty(threeJs, 'Color'),
        [widget.backgroundColor.value],
      ),
    );
    
    // Create camera
    camera = js_util.callConstructor(
      js_util.getProperty(threeJs, 'PerspectiveCamera'),
      [75, widget.width / widget.height, 0.1, 1000],
    );
    js_util.setProperty(camera, 'position', js_util.newObject());
    js_util.setProperty(js_util.getProperty(camera, 'position'), 'z', 5);
    
    // Create renderer
    renderer = js_util.callConstructor(
      js_util.getProperty(threeJs, 'WebGLRenderer'),
      [
        js_util.jsify({
          'canvas': canvas,
          'antialias': true,
          'alpha': true,
        }),
      ],
    );
    
    js_util.callMethod(
      renderer,
      'setSize',
      [widget.width, widget.height],
    );
    
    js_util.callMethod(
      renderer,
      'setPixelRatio',
      [window.devicePixelRatio],
    );
    
    // Set clear color
    js_util.callMethod(
      renderer,
      'setClearColor',
      [
        widget.backgroundColor.value,
        1,
      ],
    );
    
    // Add lights
    var ambientLight = js_util.callConstructor(
      js_util.getProperty(threeJs, 'AmbientLight'),
      [0xffffff, 0.5],
    );
    js_util.callMethod(scene, 'add', [ambientLight]);
    
    var directionalLight = js_util.callConstructor(
      js_util.getProperty(threeJs, 'DirectionalLight'),
      [0xffffff, 0.8],
    );
    var directionalLightPos = js_util.getProperty(directionalLight, 'position');
    js_util.callMethod(directionalLightPos, 'set', [0, 5, 5]);
    js_util.callMethod(scene, 'add', [directionalLight]);
    
    var pointLight = js_util.callConstructor(
      js_util.getProperty(threeJs, 'PointLight'),
      [0xffffff, 0.5],
    );
    var pointLightPos = js_util.getProperty(pointLight, 'position');
    js_util.callMethod(pointLightPos, 'set', [0, -5, 0]);
    js_util.callMethod(scene, 'add', [pointLight]);
    
    // Add controls
    if (widget.showControls) {
      controls = js_util.callConstructor(
        js_util.getProperty(html.window, 'THREE').OrbitControls,
        [camera, canvas],
      );
      
      js_util.setProperty(controls, 'enableDamping', true);
      js_util.setProperty(controls, 'dampingFactor', 0.25);
      js_util.setProperty(controls, 'enableZoom', true);
      js_util.setProperty(controls, 'autoRotate', widget.autoRotate);
    }
  }
  
  Future<void> _loadModelWeb() async {
    try {
      // Create GLTFLoader
      var loader = js_util.callConstructor(
        js_util.getProperty(html.window, 'THREE').GLTFLoader,
        [],
      );
      
      // Load the model
      Completer<void> modelLoaded = Completer<void>();
      
      js_util.callMethod(
        loader,
        'load',
        [
          widget.modelUrl,
          js_util.allowInterop((gltf) {
            model = js_util.getProperty(gltf, 'scene');
            
            // Center the model
            var box = js_util.callConstructor(
              js_util.getProperty(threeJs, 'Box3'),
              [],
            );
            
            js_util.callMethod(box, 'setFromObject', [model]);
            
            var center = js_util.callMethod(box, 'getCenter', [
              js_util.callConstructor(
                js_util.getProperty(threeJs, 'Vector3'),
                [],
              ),
            ]);
            
            var size = js_util.callMethod(box, 'getSize', [
              js_util.callConstructor(
                js_util.getProperty(threeJs, 'Vector3'),
                [],
              ),
            ]);
            
            // Adjust camera position based on model size
            var maxDim = js_util.callMethod(
              js_util.getProperty(threeJs, 'Math'),
              'max',
              [
                js_util.getProperty(size, 'x'),
                js_util.callMethod(
                  js_util.getProperty(threeJs, 'Math'),
                  'max',
                  [js_util.getProperty(size, 'y'), js_util.getProperty(size, 'z')],
                ),
              ],
            );
            
            var fov = js_util.getProperty(camera, 'fov') * (Math.pi / 180);
            var cameraZ = (maxDim / 2) / Math.tan(fov / 2) * 2.5;
            
            js_util.setProperty(
              js_util.getProperty(camera, 'position'),
              'z',
              cameraZ,
            );
            
            // Center the model
            js_util.setProperty(
              js_util.getProperty(model, 'position'),
              'x',
              -js_util.getProperty(center, 'x'),
            );
            
            js_util.setProperty(
              js_util.getProperty(model, 'position'),
              'y',
              -js_util.getProperty(center, 'y'),
            );
            
            js_util.setProperty(
              js_util.getProperty(model, 'position'),
              'z',
              -js_util.getProperty(center, 'z'),
            );
            
            js_util.callMethod(scene, 'add', [model]);
            
            modelLoaded.complete();
          }),
          null, // onProgress
          js_util.allowInterop((error) {
            print("Error loading model: $error");
            modelLoaded.completeError(error);
          }),
        ],
      );
      
      await modelLoaded.future;
    } catch (e) {
      print("Error loading model: $e");
      setState(() {
        errorMessage = "Failed to load 3D model: $e";
        isLoading = false;
      });
    }
  }
  
  void _animateWeb() {
    if (disposed) return;
    
    animationId = html.window.requestAnimationFrame((_) {
      _renderWeb();
      _animateWeb();
    });
  }
  
  void _renderWeb() {
    if (disposed) return;
    
    if (widget.showControls && controls != null) {
      js_util.callMethod(controls, 'update', []);
    }
    
    js_util.callMethod(renderer, 'render', [scene, camera]);
  }

  Future<void> _initializeNativeViewer() async {
    try {
      // Initialize Flutter GL for native platforms
      flutterGlPlugin = FlutterGlPlugin();
      
      Map<String, dynamic> options = {
        "antialias": true,
        "alpha": true,
        "width": widget.width.toInt(),
        "height": widget.height.toInt(),
        "dpr": dpr
      };
      
      await flutterGlPlugin!.initialize(options: options);
      
      // Get GL context
      gl = flutterGlPlugin!.gl;
      
      // Set up a simple colored background
      gl.clearColor(
        widget.backgroundColor.red / 255.0,
        widget.backgroundColor.green / 255.0,
        widget.backgroundColor.blue / 255.0,
        1.0,
      );
      gl.clear(gl.COLOR_BUFFER_BIT);
      
      // Get the texture source
      sourceTexture = flutterGlPlugin!.defaultFramebuffer;
      
      // Set up FBO
      fboId = await flutterGlPlugin!.createTexture(sourceTexture);
      await flutterGlPlugin!.prepareContext();
      
      setState(() {
        isInitialized = true;
        isLoading = false;
        errorMessage = "Native 3D model viewing is not fully implemented. Please use web platform for full functionality.";
      });
    } catch (e) {
      print("Error initializing native viewer: $e");
      setState(() {
        errorMessage = "Failed to initialize native 3D viewer: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: widget.backgroundColor,
        child: Stack(
          children: [
            // For web, we use HtmlElementView to display the canvas
            if (isInitialized)
              const SizedBox.expand(),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // For native platforms, use Flutter GL
      return Container(
        width: widget.width,
        height: widget.height,
        color: widget.backgroundColor,
        child: Stack(
          children: [
            if (isInitialized && fboId != null)
              Texture(
                textureId: fboId!,
                width: widget.width,
                height: widget.height,
              ),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    disposed = true;
    
    if (kIsWeb) {
      // Clean up web resources
      if (animationId != null) {
        html.window.cancelAnimationFrame(animationId!);
      }
      
      // Remove the container from the DOM
      container?.remove();
    } else {
      // Clean up native resources
      flutterGlPlugin?.dispose();
    }
    
    super.dispose();
  }
} 