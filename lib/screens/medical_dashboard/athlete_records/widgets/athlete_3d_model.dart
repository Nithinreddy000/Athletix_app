import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../constants.dart';
import '../../../../config.dart';
import '../../../../widgets/model_viewer_plus_widget.dart';

class Athlete3DModel extends StatefulWidget {
  final Map<String, dynamic>? injuries;
  final String? selectedBodyPart;
  final Function(String)? onBodyPartSelected;
  final String? slicerModelUrl;

  const Athlete3DModel({
    Key? key,
    this.injuries,
    this.selectedBodyPart,
    this.onBodyPartSelected,
    this.slicerModelUrl,
  }) : super(key: key);

  @override
  _Athlete3DModelState createState() => _Athlete3DModelState();
}

class _Athlete3DModelState extends State<Athlete3DModel> {
  bool _isModelLoaded = false;
  String? _modelError;
  int _loadAttempts = 0;
  final int _maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void didUpdateWidget(Athlete3DModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slicerModelUrl != widget.slicerModelUrl) {
      _loadModel();
    }
  }

  void _loadModel() {
    setState(() {
      _isModelLoaded = false;
      _modelError = null;
      _loadAttempts = 0;
    });
    
    if (widget.slicerModelUrl != null) {
      print("Loading injury model from: ${widget.slicerModelUrl}");
    }
    
    // Set model as loaded after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isModelLoaded = true;
        });
      }
    });
  }

  String _getModelUrl() {
    if (widget.slicerModelUrl != null && widget.slicerModelUrl!.isNotEmpty) {
      // Fix path separators - ensure forward slashes for web URLs
      String modelUrl = widget.slicerModelUrl!.replaceAll('\\', '/');
      
      // Make sure the URL starts with a slash if it doesn't have one and it's not already an absolute URL
      if (!modelUrl.startsWith('http') && !modelUrl.startsWith('/')) {
        modelUrl = '/$modelUrl';
      }
      
      // Add the API base URL if it's not already an absolute URL
      if (!modelUrl.startsWith('http')) {
        modelUrl = '${Config.apiBaseUrl}$modelUrl';
      }
      
      return modelUrl;
    }
    // Default model if no specific one is provided
    return '${Config.apiBaseUrl}/model/models/z-anatomy/Muscular.glb';
  }

  String _getFallbackModelUrl() {
    // Always use the default anatomical model as fallback
    return '${Config.apiBaseUrl}/model/models/z-anatomy/Muscular.glb';
  }

  Widget _buildModel() {
    final modelUrl = _getModelUrl();
    final fallbackUrl = _getFallbackModelUrl();
    print("Using model URL: $modelUrl");
    print("Using fallback URL: $fallbackUrl");

    return Stack(
      children: [
        ModelViewerPlus(
          modelUrl: modelUrl,
          fallbackUrl: fallbackUrl,
          autoRotate: false,
          showControls: true,
          onModelLoaded: (success) {
            _loadAttempts++;
            if (success) {
              setState(() {
                _isModelLoaded = true;
                _modelError = null;
              });
              print('Model loaded successfully: $modelUrl');
            } else {
              print('Failed to load model: $modelUrl (Attempt $_loadAttempts of $_maxLoadAttempts)');
              
              // Only show error after max attempts
              if (_loadAttempts >= _maxLoadAttempts) {
                setState(() {
                  _modelError = 'Failed to load 3D model after multiple attempts.';
                });
              }
            }
          },
        ),
        if (!_isModelLoaded)
          Container(
            color: Colors.black45,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Anatomical Model...' + 
                    (_loadAttempts > 1 ? '\nAttempt $_loadAttempts of $_maxLoadAttempts' : ''),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  if (_modelError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _modelError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Active Injury', Colors.red),
        const SizedBox(width: defaultPadding),
        _buildLegendItem('Past Injury', Colors.orange),
        const SizedBox(width: defaultPadding),
        _buildLegendItem('Recovered', Colors.green),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildModel(),
        ),
        const SizedBox(height: defaultPadding),
        _buildLegend(),
      ],
    );
  }
} 