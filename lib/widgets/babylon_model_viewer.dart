import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class BabylonModelViewer extends StatefulWidget {
  final String modelUrl;
  final Function(bool)? onModelLoaded;
  final double height;
  final double width;

  const BabylonModelViewer({
    Key? key,
    required this.modelUrl,
    this.onModelLoaded,
    this.height = double.infinity,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  BabylonModelViewerState createState() => BabylonModelViewerState();
}

class BabylonModelViewerState extends State<BabylonModelViewer> {
  late final WebViewController _controller;
  bool _isLoaded = false;
  String _viewerId = 'modelViewer';
  html.IFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeWebView();
    } else {
      _initializeController();
    }
  }

  void _initializeWebView() {
    // Register the view factory
    _viewerId = 'modelViewer-${DateTime.now().millisecondsSinceEpoch}';
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewerId, (int viewId) {
      _iframeElement = html.IFrameElement()
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%'
        ..style.background = 'transparent'
        ..srcdoc = _getHtmlContent();

      // Listen for messages from the iframe
      html.window.addEventListener('message', (html.Event event) {
        final html.MessageEvent messageEvent = event as html.MessageEvent;
        if (messageEvent.data == 'modelLoaded') {
          setState(() => _isLoaded = true);
          widget.onModelLoaded?.call(true);
        } else if (messageEvent.data == 'modelLoadError') {
          setState(() => _isLoaded = false);
          widget.onModelLoaded?.call(false);
        }
      });

      return _iframeElement!;
    });
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'ModelViewerCallback',
        onMessageReceived: (JavaScriptMessage message) {
          final success = message.message == 'true';
          setState(() => _isLoaded = success);
          widget.onModelLoaded?.call(success);
        },
      )
      ..loadHtmlString(_getHtmlContent());
  }

  String _getHtmlContent() {
    final cleanModelUrl = widget.modelUrl.replaceAll(r'\', '/');
    
    return '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { margin: 0; overflow: hidden; background: transparent; }
            #renderCanvas { width: 100%; height: 100vh; touch-action: none; }
            
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
              font-family: sans-serif;
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
            }
            
            @keyframes spin {
              0% { transform: rotate(0deg); }
              100% { transform: rotate(360deg); }
            }
          </style>
          <script src="https://cdn.babylonjs.com/babylon.js"></script>
          <script src="https://cdn.babylonjs.com/loaders/babylonjs.loaders.min.js"></script>
        </head>
        <body>
          <canvas id="renderCanvas"></canvas>
          <div id="loading-indicator">
            <div class="loading-spinner"></div>
            <div class="loading-text">Loading 3D Model... This may take up to 2 minutes depending on the model size and your connection speed.</div>
          </div>
          <script>
            const canvas = document.getElementById("renderCanvas");
            const engine = new BABYLON.Engine(canvas, true);
            let scene;
            let camera;
            let meshes = new Map();
            let originalMaterials = new Map();

            const createScene = async function() {
                scene = new BABYLON.Scene(engine);
                scene.clearColor = new BABYLON.Color4(0, 0, 0, 0);
                
                camera = new BABYLON.ArcRotateCamera(
                    "camera",
                    0,
                    Math.PI / 3,
                    10,
                    BABYLON.Vector3.Zero(),
                    scene
                );
                camera.attachControl(canvas, true);
                camera.wheelPrecision = 50;
                camera.pinchPrecision = 50;
                
                const light = new BABYLON.HemisphericLight(
                    "light1",
                    new BABYLON.Vector3(0, 1, 0),
                    scene
                );
                
                try {
                    console.log("Loading model from: $cleanModelUrl");
                    const result = await BABYLON.SceneLoader.ImportMeshAsync(
                        "",
                        "",
                        "$cleanModelUrl",
                        scene
                    );
                    
                    console.log("Model loaded successfully", result);
                    
                    // Store meshes and their materials
                    result.meshes.forEach((mesh) => {
                        if (mesh.name !== "__root__") {
                            // Create a clone for instanced meshes
                            if (mesh.instances && mesh.instances.length > 0) {
                                const clonedMesh = mesh.clone("cloned_" + mesh.name);
                                clonedMesh.isVisible = true;
                                meshes.set(mesh.name, clonedMesh);
                                originalMaterials.set(mesh.name, clonedMesh.material.clone());
                                mesh.isVisible = false;
                            } else {
                                meshes.set(mesh.name, mesh);
                                originalMaterials.set(mesh.name, mesh.material.clone());
                            }
                        }
                    });
                    
                    // Center and scale the model
                    const boundingInfo = result.meshes[0].getHierarchyBoundingVectors();
                    const center = BABYLON.Vector3.Center(boundingInfo.min, boundingInfo.max);
                    const scaling = 5.0 / BABYLON.Vector3.Distance(boundingInfo.min, boundingInfo.max);
                    
                    result.meshes[0].position = center.scale(-1);
                    result.meshes[0].scaling = new BABYLON.Vector3(scaling, scaling, scaling);
                    
                    camera.setTarget(BABYLON.Vector3.Zero());
                    camera.alpha = Math.PI / 4;
                    camera.beta = Math.PI / 3;
                    camera.radius = 10;
                    
                    // Hide loading indicator
                    document.getElementById('loading-indicator').style.display = 'none';
                    
                    window.parent.postMessage('modelLoaded', '*');
                } catch (error) {
                    console.error("Error loading model:", error);
                    document.getElementById('loading-indicator').innerHTML = '<div class="loading-spinner"></div><div class="loading-text">Error loading model. Please try again later.</div>';
                    window.parent.postMessage('modelLoadError', '*');
                }
                
                return scene;
            };

            // Function to find mesh by name
            function findMesh(meshName) {
                const searchName = meshName.toLowerCase();
                return Array.from(meshes.values()).find(mesh => 
                    mesh.name.toLowerCase().includes(searchName)
                );
            }

            // Function to focus on a specific mesh
            function focusOnMesh(meshName, status = 'active', severity = 'moderate') {
                console.log('Focusing on mesh:', meshName, status, severity);
                const targetMesh = findMesh(meshName);
                if (!targetMesh) {
                    console.error('Mesh not found:', meshName);
                    return;
                }

                // Reset all meshes to semi-transparent
                meshes.forEach((mesh, name) => {
                    if (mesh && mesh.material) {
                        const originalMaterial = originalMaterials.get(name);
                        if (originalMaterial) {
                            const newMaterial = originalMaterial.clone();
                            newMaterial.alpha = 0.3;
                            mesh.material = newMaterial;
                        }
                    }
                });

                // Create highlight material
                const highlightMaterial = new BABYLON.StandardMaterial("highlightMaterial", scene);
                
                // Set color based on status
                switch (status) {
                    case 'active':
                        highlightMaterial.diffuseColor = new BABYLON.Color3(1, 0, 0); // Red
                        break;
                    case 'recovered':
                        highlightMaterial.diffuseColor = new BABYLON.Color3(0, 1, 0); // Green
                        break;
                    default:
                        highlightMaterial.diffuseColor = new BABYLON.Color3(1, 0.65, 0); // Orange
                }

                // Adjust material properties
                highlightMaterial.specularColor = new BABYLON.Color3(0.5, 0.6, 0.87);
                highlightMaterial.emissiveColor = highlightMaterial.diffuseColor.scale(0.3);
                highlightMaterial.alpha = 1.0;

                // Apply material
                targetMesh.material = highlightMaterial;

                // Focus camera on mesh
                const boundingInfo = targetMesh.getBoundingInfo();
                const center = boundingInfo.boundingBox.centerWorld;
                const radius = boundingInfo.boundingBox.extendSizeWorld.length();

                // Animate camera
                const currentTarget = camera.target.clone();
                const currentRadius = camera.radius;

                BABYLON.Animation.CreateAndStartAnimation(
                    "cameraMove",
                    camera,
                    "target",
                    60,
                    30,
                    currentTarget,
                    center,
                    BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
                );

                BABYLON.Animation.CreateAndStartAnimation(
                    "cameraRadius",
                    camera,
                    "radius",
                    60,
                    30,
                    currentRadius,
                    radius * 2.5,
                    BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
                );
            }

            // Listen for messages from parent
            window.addEventListener('message', function(event) {
                if (event.data && event.data.type === 'focusOnMesh') {
                    focusOnMesh(event.data.meshName, event.data.status, event.data.severity);
                }
            });

            createScene().then(() => {
                engine.runRenderLoop(() => {
                    scene.render();
                });
            });

            window.addEventListener("resize", () => {
                engine.resize();
            });
          </script>
        </body>
      </html>
    ''';
  }

  void focusOnMesh(String meshName, {String status = 'active', String severity = 'moderate'}) {
    if (!_isLoaded) return;
    
    if (kIsWeb && _iframeElement != null) {
      final message = {
        'type': 'focusOnMesh',
        'meshName': meshName,
        'status': status,
        'severity': severity
      };
      _iframeElement!.contentWindow?.postMessage(message, '*');
    } else {
      final js = '''
        if (window.viewer) {
          window.viewer.focusOnMesh('$meshName', '$status', '$severity');
        }
      ''';
      _controller.runJavaScript(js);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: HtmlElementView(viewType: _viewerId),
      );
    }
    
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: WebViewWidget(controller: _controller),
    );
  }
} 