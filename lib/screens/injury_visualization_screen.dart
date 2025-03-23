import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../services/model_upload_service.dart';
import '../widgets/model_viewer_plus_widget.dart';
import 'package:path_provider/path_provider.dart';

class InjuryVisualizationScreen extends StatefulWidget {
  final String? initialModelUrl;
  final String title;
  final List<Map<String, dynamic>> injuries;

  const InjuryVisualizationScreen({
    Key? key,
    this.initialModelUrl,
    this.title = "Injury Visualization",
    this.injuries = const [],
  }) : super(key: key);

  @override
  _InjuryVisualizationScreenState createState() => _InjuryVisualizationScreenState();
}

class _InjuryVisualizationScreenState extends State<InjuryVisualizationScreen> {
  String? modelUrl;
  bool isLoading = false;
  String? errorMessage;
  bool autoRotate = true;
  Color backgroundColor = Colors.black;
  late ModelUploadService modelUploadService;

  @override
  void initState() {
    super.initState();
    modelUrl = widget.initialModelUrl;
    
    // Initialize the model upload service with your Cloudinary credentials
    modelUploadService = ModelUploadService(
      cloudName: 'your-cloud-name',  // Replace with your Cloudinary cloud name
      uploadPreset: 'your-upload-preset',  // Replace with your Cloudinary upload preset
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(autoRotate ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                autoRotate = !autoRotate;
              });
            },
            tooltip: autoRotate ? 'Pause rotation' : 'Start rotation',
          ),
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () {
              _showBackgroundColorPicker();
            },
            tooltip: 'Change background color',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              _uploadModelFile();
            },
            tooltip: 'Upload model file',
          ),
        ],
      ),
      body: Column(
        children: [
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ModelViewerPlusWidget(
              modelUrl: modelUrl,
              backgroundColor: backgroundColor,
              autoRotate: autoRotate,
              height: MediaQuery.of(context).size.height - 100,
              width: MediaQuery.of(context).size.width,
              onModelLoaded: (success) {
                setState(() {
                  isLoading = false;
                  errorMessage = success ? null : 'Failed to load model';
                });
              },
            ),
          ),
          if (widget.injuries.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Injury Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.injuries.map((injury) {
                    final bodyPart = injury['bodyPart'] ?? 'Unknown';
                    final side = injury['side'] ?? 'N/A';
                    final status = injury['status'] ?? 'Active';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: status.toLowerCase() == 'active' 
                                ? Colors.red 
                                : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$bodyPart ($side) - $status',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Powered by Model Viewer Plus',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (kIsWeb)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Web Mode: Using model-viewer web component',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBackgroundColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Background Color'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
                _colorOption(Colors.black, 'Black'),
                _colorOption(Colors.white, 'White'),
                _colorOption(Colors.grey.shade800, 'Dark Grey'),
                _colorOption(Colors.blue.shade900, 'Dark Blue'),
                _colorOption(Colors.transparent, 'Transparent'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _colorOption(Color color, String name) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(name),
      onTap: () {
        setState(() {
          backgroundColor = color;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _uploadModelFile() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Pick a file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['glb', 'gltf', 'fbx', 'obj'],
      );

      if (result != null) {
        if (kIsWeb) {
          // For web, we need to handle the bytes
          if (result.files.single.bytes != null) {
            // Upload the bytes to Cloudinary
            String uploadedUrl = await modelUploadService.uploadModelBytes(
              result.files.single.bytes!,
              result.files.single.name,
            );
            
            setState(() {
              modelUrl = uploadedUrl;
              isLoading = false;
            });
          }
        } else if (result.files.single.path != null) {
          // For mobile/desktop, we can use the file path
          File file = File(result.files.single.path!);
          
          // Upload the file to Cloudinary
          String uploadedUrl = await modelUploadService.uploadModelFile(file);
          
          setState(() {
            modelUrl = uploadedUrl;
            isLoading = false;
          });
        }
      } else {
        // User canceled the picker
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error uploading model: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _processInjuries() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // This would typically call your backend API to process injuries
      // For now, we'll just simulate a delay
      await Future.delayed(const Duration(seconds: 2));
      
      // In a real implementation, you would:
      // 1. Send the model to your backend
      // 2. Process the injuries using your Python script
      // 3. Get back the processed model URL
      
      // For demonstration, we'll just use the same URL
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Injuries processed successfully')),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error processing injuries: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _saveModel() async {
    if (kIsWeb) {
      setState(() {
        errorMessage = 'Saving models is not supported in web mode';
      });
      return;
    }
    
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      if (modelUrl == null) {
        throw Exception('No model to save');
      }

      // Download the model
      File modelFile = await modelUploadService.downloadModelToFile(modelUrl!);
      
      // Get the downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      
      if (downloadsDir == null) {
        throw Exception('Could not find downloads directory');
      }
      
      // Create a new file in the downloads directory
      String fileName = 'model_${DateTime.now().millisecondsSinceEpoch}.glb';
      File savedFile = File('${downloadsDir.path}/$fileName');
      
      // Copy the model file to the downloads directory
      await modelFile.copy(savedFile.path);
      
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model saved to ${savedFile.path}')),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error saving model: $e';
        isLoading = false;
      });
    }
  }
} 