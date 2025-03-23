import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class ModelViewerService {
  static bool _isInitialized = false;

  static const String _interfaceScript = r'''
    if (!window.ModelViewerInterface) {
      window.ModelViewerInterface = class {
        constructor(modelViewer) {
          this.modelViewer = modelViewer;
          this.setupMaterials();
        }

        setupMaterials() {
          if (!this.modelViewer.model) {
            console.log('Model not loaded yet');
            return;
          }
          console.log('Setting up materials');
        }

        setInjuries(injuries) {
          if (!this.modelViewer.model) {
            console.log('Model not loaded for injury coloring');
            return;
          }

          console.log('Setting injuries:', injuries);
          
          // First reset all materials
          const materials = this.modelViewer.model.materials;
          materials.forEach(material => {
            material.setAlphaMode('OPAQUE');
            material.pbrMetallicRoughness.setBaseColorFactor([0.8, 0.8, 0.8, 1.0]);
          });

          // Apply injury colors
          injuries.forEach(injury => {
            const bodyPart = injury.bodyPart.toLowerCase();
            const color = this.hexToRgb(injury.colorCode);
            
            if (color) {
              console.log('Applying color to:', bodyPart, color);
              
              // Find all meshes that match the body part
              const meshes = this.modelViewer.model.meshes;
              meshes.forEach(mesh => {
                const meshName = mesh.name.toLowerCase();
                if (meshName.includes(bodyPart)) {
                  console.log('Found matching mesh:', meshName);
                  mesh.primitives.forEach(primitive => {
                    const material = primitive.material;
                    material.setAlphaMode('BLEND');
                    material.pbrMetallicRoughness.setBaseColorFactor([
                      color.r / 255,
                      color.g / 255,
                      color.b / 255,
                      0.8  // Alpha for semi-transparency
                    ]);
                  });
                }
              });
            } else {
              console.error('Invalid color code:', injury.colorCode);
            }
          });
        }

        hexToRgb(hex) {
          // Remove the hash if present
          hex = hex.replace(/^#/, '');
          
          // Parse the hex values
          const bigint = parseInt(hex, 16);
          return {
            r: (bigint >> 16) & 255,
            g: (bigint >> 8) & 255,
            b: bigint & 255
          };
        }
      };
    }
  ''';

  static void initializeInterface() {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  static String generateInjuryColorScript(List<Map<String, dynamic>> injuries) {
    final injuryData = injuries.map((injury) => {
      'bodyPart': injury['bodyPart'],
      'colorCode': injury['colorCode'] ?? '#FF0000',
    }).toList();

    print('Applying colors to injuries: ${json.encode(injuryData)}');

    return '''
      const modelViewer = document.querySelector('model-viewer');
      if (!modelViewer) {
        console.error('Model viewer not found');
        return;
      }

      if (!modelViewer.model) {
        modelViewer.addEventListener('load', () => {
          console.log('Model loaded, applying colors');
          const interface = new ModelViewerInterface(modelViewer);
          interface.setInjuries(${json.encode(injuryData)});
        });
      } else {
        console.log('Model already loaded, applying colors');
        const interface = new ModelViewerInterface(modelViewer);
        interface.setInjuries(${json.encode(injuryData)});
      }
    ''';
  }

  static void updateInjuryColors(WebViewController controller, List<Map<String, dynamic>> injuries) {
    if (injuries.isEmpty) {
      print('No injuries to color');
      return;
    }

    print('Updating injury colors: ${json.encode(injuries)}');

    final script = '''
      $_interfaceScript
      ${generateInjuryColorScript(injuries)}
    ''';
    
    controller.runJavaScript(script).then((_) {
      print('Color update script executed successfully');
    }).catchError((error) {
      print('Error updating colors: $error');
    });
  }

  static void resetColors(WebViewController controller) {
    final script = '''
      const modelViewer = document.querySelector('model-viewer');
      if (modelViewer && modelViewer.model) {
        modelViewer.model.materials.forEach(material => {
          material.setAlphaMode('OPAQUE');
          material.pbrMetallicRoughness.setBaseColorFactor([0.8, 0.8, 0.8, 1.0]);
        });
      }
    ''';
    controller.runJavaScript(script);
  }
} 