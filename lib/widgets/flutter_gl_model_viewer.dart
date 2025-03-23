import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FlutterGLModelViewer extends StatefulWidget {
  final String modelUrl;
  final double width;
  final double height;
  final Color backgroundColor;
  final bool autoRotate;
  final bool showControls;

  const FlutterGLModelViewer({
    Key? key,
    required this.modelUrl,
    this.width = double.infinity,
    this.height = 400,
    this.backgroundColor = Colors.black,
    this.autoRotate = true,
    this.showControls = true,
  }) : super(key: key);

  @override
  _FlutterGLModelViewerState createState() => _FlutterGLModelViewerState();
}

class _FlutterGLModelViewerState extends State<FlutterGLModelViewer> {
  late FlutterGlPlugin flutterGlPlugin;
  three.WebGLRenderer? renderer;
  three.Scene? scene;
  three.Camera? camera;
  three_jsm.OrbitControls? controls;
  int? fboId;
  late double width;
  late double height;
  Size? screenSize;
  late three.WebGLRenderTarget renderTarget;
  dynamic sourceTexture;
  bool isInitialized = false;
  bool isLoading = true;
  String? errorMessage;
  three.Object3D? model;
  three.AnimationMixer? mixer;
  List<three.AnimationAction> animationActions = [];
  int? animationId;
  Stopwatch? stopwatch;
  double dpr = 1.0;
  bool disposed = false;

  @override
  void initState() {
    super.initState();
    width = widget.width;
    height = widget.height;
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      flutterGlPlugin = FlutterGlPlugin();
      Map<String, dynamic> options = {
        "antialias": true,
        "alpha": true,
        "width": width.toInt(),
        "height": height.toInt(),
        "dpr": dpr
      };

      // Add special handling for web platform
      if (kIsWeb) {
        options["renderToFramebuffer"] = true;
        options["clearColor"] = [0.0, 0.0, 0.0, 1.0];
      }

      await flutterGlPlugin.initialize(options: options);
      await Future.delayed(const Duration(milliseconds: 100));
      await setupRenderer();
      await loadModel();
      startRendering();
    } catch (e) {
      print("Error initializing FlutterGL: $e");
      setState(() {
        errorMessage = "Failed to initialize 3D viewer: $e";
        isLoading = false;
      });
    }
  }

  Future<void> setupRenderer() async {
    try {
      screenSize = Size(width, height);
      dpr = MediaQuery.of(context).devicePixelRatio;

      // Initialize renderer
      renderer = three.WebGLRenderer(
        {
          "width": width,
          "height": height,
          "gl": flutterGlPlugin.gl,
          "antialias": true,
          "alpha": true,
        },
      );
      renderer!.setPixelRatio(dpr);
      renderer!.setSize(width, height, false);
      renderer!.shadowMap.enabled = true;
      renderer!.shadowMap.type = three.PCFSoftShadowMap;
      renderer!.setClearColor(
        three.Color().setHex(widget.backgroundColor.value),
        1,
      );

      // Initialize scene
      scene = three.Scene();
      scene!.background = three.Color().setHex(widget.backgroundColor.value);

      // Initialize camera
      camera = three.PerspectiveCamera(75, width / height, 0.1, 1000.0);
      camera!.position.z = 5;
      scene!.add(camera!);

      // Add lights
      var ambientLight = three.AmbientLight(0xffffff, 0.5);
      scene!.add(ambientLight);

      var directionalLight = three.DirectionalLight(0xffffff, 0.8);
      directionalLight.position.set(0, 5, 5);
      directionalLight.castShadow = true;
      scene!.add(directionalLight);

      var pointLight = three.PointLight(0xffffff, 0.5);
      pointLight.position.set(0, -5, 0);
      scene!.add(pointLight);

      // Initialize controls
      if (widget.showControls) {
        controls = three_jsm.OrbitControls(camera, null);
        controls!.enableDamping = true;
        controls!.dampingFactor = 0.25;
        controls!.enableZoom = true;
        controls!.autoRotate = widget.autoRotate;
      }

      // Initialize render target
      renderTarget = three.WebGLRenderTarget(
        (width * dpr).toInt(),
        (height * dpr).toInt(),
        {
          "format": three.RGBAFormat,
        },
      );

      // Get the texture source
      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);

      // Set up FBO
      fboId = await flutterGlPlugin.createTexture(sourceTexture);
      await flutterGlPlugin.prepareContext();

      setState(() {
        isInitialized = true;
      });
    } catch (e) {
      print("Error setting up renderer: $e");
      setState(() {
        errorMessage = "Failed to setup 3D renderer: $e";
        isLoading = false;
      });
    }
  }

  Future<void> loadModel() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Download the model if it's a URL
      String modelPath = widget.modelUrl;
      
      if (widget.modelUrl.startsWith('http')) {
        if (kIsWeb) {
          // For web, we can use the URL directly
          modelPath = widget.modelUrl;
        } else {
          // For mobile/desktop, download the file
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/temp_model.glb');
          
          final response = await http.get(Uri.parse(widget.modelUrl));
          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes);
            modelPath = file.path;
          } else {
            throw Exception('Failed to download model: ${response.statusCode}');
          }
        }
      }

      // Load the model
      var loader = three_jsm.GLTFLoader();
      var result = await loader.loadAsync(modelPath);
      
      model = result["scene"];
      
      // Center the model
      var box = three.Box3().setFromObject(model!);
      var center = box.getCenter(three.Vector3());
      var size = box.getSize(three.Vector3());
      
      // Adjust camera position based on model size
      var maxDim = three.Math.max(size.x, three.Math.max(size.y, size.z));
      var fov = camera!.fov * (three.Math.PI / 180);
      var cameraZ = three.Math.abs(maxDim / 2 * three.Math.tan(fov / 2)) * 2.5;
      camera!.position.z = cameraZ;
      
      // Center the model
      model!.position.x = -center.x;
      model!.position.y = -center.y;
      model!.position.z = -center.z;
      
      scene!.add(model!);
      
      // Set up animations if available
      if (result["animations"] != null && result["animations"].length > 0) {
        mixer = three.AnimationMixer(model);
        for (var animation in result["animations"]) {
          var action = mixer!.clipAction(animation);
          animationActions.add(action);
          action.play();
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error loading model: $e");
      setState(() {
        errorMessage = "Failed to load 3D model: $e";
        isLoading = false;
      });
    }
  }

  void startRendering() {
    if (disposed) return;
    
    stopwatch = Stopwatch()..start();
    animate();
  }

  void animate() {
    if (disposed) return;
    
    if (animationId != null) {
      cancelAnimationFrame(animationId!);
    }
    
    animationId = requestAnimationFrame((double time) {
      if (disposed) return;
      render();
      animate();
    });
  }

  int requestAnimationFrame(Function(double time) callback) {
    return Future.delayed(const Duration(milliseconds: 16), () {
      if (disposed) return -1;
      double time = stopwatch!.elapsedMilliseconds.toDouble();
      callback(time);
      return 0;
    }).hashCode;
  }

  void cancelAnimationFrame(int id) {
    // No direct equivalent in Flutter, but we can use this method signature for consistency
  }

  void render() {
    if (disposed) return;
    
    final delta = stopwatch!.elapsedMilliseconds / 1000;
    stopwatch!.reset();
    
    if (widget.showControls && controls != null) {
      controls!.update();
    }
    
    if (mixer != null) {
      mixer!.update(delta);
    }
    
    // Render to target for non-web platforms
    if (!kIsWeb) {
      renderer!.setRenderTarget(renderTarget);
      renderer!.render(scene!, camera!);
      renderer!.setRenderTarget(null);
    } else {
      // Direct rendering for web
      renderer!.render(scene!, camera!);
    }
    
    flutterGlPlugin.updateTexture(sourceTexture);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: widget.backgroundColor,
      child: Stack(
        children: [
          if (isInitialized)
            Texture(
              textureId: fboId!,
              width: width,
              height: height,
            ),
          if (isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Loading 3D Model...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
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

  @override
  void dispose() {
    disposed = true;
    if (animationId != null) {
      cancelAnimationFrame(animationId!);
    }
    flutterGlPlugin.dispose();
    super.dispose();
  }
} 