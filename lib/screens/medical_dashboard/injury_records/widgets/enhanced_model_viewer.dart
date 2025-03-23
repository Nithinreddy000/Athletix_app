import 'package:flutter/material.dart';
import '../../../../widgets/model_viewer_plus_widget.dart';
import '../../../../config.dart';

class EnhancedModelViewer extends StatefulWidget {
  final String modelUrl;
  final String? fallbackModelUrl;
  final List<Map<String, dynamic>> injuries;
  final Function(Map<String, dynamic>)? onInjurySelected;

  const EnhancedModelViewer({
    Key? key,
    required this.modelUrl,
    this.fallbackModelUrl,
    required this.injuries,
    this.onInjurySelected,
  }) : super(key: key);

  @override
  _EnhancedModelViewerState createState() => _EnhancedModelViewerState();
}

class _EnhancedModelViewerState extends State<EnhancedModelViewer> {
  bool _isModelLoaded = false;
  bool _isUsingFallback = false;
  Map<String, dynamic>? _selectedInjury;
  final GlobalKey<ModelViewerPlusState> _modelViewerKey = GlobalKey();
  String _currentModelUrl = '';
  String? _effectiveFallbackUrl;
  int _loadAttempts = 0;
  final int _maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _setupModelUrls();
  }

  void _setupModelUrls() {
    // Clean and prepare the primary model URL
    _currentModelUrl = _prepareModelUrl(widget.modelUrl);
    print('Enhanced viewer: Primary model URL: $_currentModelUrl');

    // Set up a reliable fallback - first try the provided fallback
    if (widget.fallbackModelUrl != null) {
      _effectiveFallbackUrl = _prepareModelUrl(widget.fallbackModelUrl!);
    } 
    
    // Use default anatomical model as final fallback
    if (_effectiveFallbackUrl == null || _effectiveFallbackUrl!.isEmpty) {
      _effectiveFallbackUrl = '${Config.apiBaseUrl}/model/models/z-anatomy/Muscular.glb';
    }
    
    print('Enhanced viewer: Fallback model URL: $_effectiveFallbackUrl');
  }

  String _prepareModelUrl(String url) {
    // Clean the URL and ensure it's properly formatted
    String cleanUrl = url.replaceAll('\\', '/');
    
    // If it's a relative path (not starting with http), add the API base URL
    if (!cleanUrl.startsWith('http')) {
      // If it doesn't start with a slash, add one
      if (!cleanUrl.startsWith('/')) {
        cleanUrl = '/$cleanUrl';
      }
      
      // Add the base API URL
      cleanUrl = '${Config.apiBaseUrl}$cleanUrl';
    }
    
    return cleanUrl;
  }

  void _tryFallbackModel() {
    if (_effectiveFallbackUrl != null && !_currentModelUrl.contains(_effectiveFallbackUrl!)) {
      setState(() {
        _isUsingFallback = true;
        _currentModelUrl = _effectiveFallbackUrl!;
        _loadAttempts = 0;  // Reset load attempts for the fallback
      });
      print('Enhanced viewer: Trying fallback model: $_currentModelUrl');
    } else {
      setState(() {
        _isModelLoaded = false;
      });
      print('Enhanced viewer: No more fallbacks to try.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The 3D model viewer
        ModelViewerPlus(
          key: _modelViewerKey,
          modelUrl: _currentModelUrl,
          fallbackUrl: _effectiveFallbackUrl,
          onModelLoaded: (success) {
            _loadAttempts++;
            if (success) {
              setState(() {
                _isModelLoaded = true;
              });
              print('Enhanced viewer: Model loaded successfully: $_currentModelUrl');
              
              // If there's a selected injury, focus on it after model loads
              if (_selectedInjury != null) {
                _focusOnInjury(_selectedInjury!);
              }
            } else {
              print('Enhanced viewer: Failed to load model: $_currentModelUrl (Attempt $_loadAttempts of $_maxLoadAttempts)');
              
              // Try a different approach based on the number of attempts
              if (_loadAttempts < _maxLoadAttempts) {
                // Let the ModelViewerPlus widget try again with its internal fallback mechanism
                print('Enhanced viewer: Letting ModelViewerPlus try its internal fallback');
              } else {
                // After max attempts, try the explicit fallback URL
                _tryFallbackModel();
              }
            }
          },
          autoRotate: false,
          showControls: true,
        ),
        
        // Loading indicator
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
                    'Loading Enhanced Visualization...\n${_currentModelUrl.split('/').last}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  if (_loadAttempts > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '(Attempt $_loadAttempts of $_maxLoadAttempts)',
                        style: TextStyle(color: Colors.yellow, fontSize: 12),
                      ),
                    ),
                  if (_isUsingFallback)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        '(Using fallback model)',
                        style: TextStyle(color: Colors.yellow, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
        // Injury selection panel
        if (_isModelLoaded)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Injuries',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.injuries.map((injury) => _buildInjuryItem(injury)),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  @override
  void didUpdateWidget(EnhancedModelViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the model URL changed, reset and try the new URL
    if (oldWidget.modelUrl != widget.modelUrl) {
      setState(() {
        _isModelLoaded = false;
        _isUsingFallback = false;
        _selectedInjury = null;
        _loadAttempts = 0;
      });
      _setupModelUrls();
    }
  }

  Widget _buildInjuryItem(Map<String, dynamic> injury) {
    final bodyPart = injury['bodyPart'];
    final status = injury['status'];
    final severity = injury['severity'];
    
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = Colors.red;
        break;
      case 'past':
        statusColor = Colors.orange;
        break;
      case 'recovered':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }
    
    final isSelected = _selectedInjury == injury;
    
    return InkWell(
      onTap: () {
        setState(() => _selectedInjury = injury);
        
        // Focus on the injury in the 3D model
        _focusOnInjury(injury);
        
        // Notify parent if callback is provided
        if (widget.onInjurySelected != null) {
          widget.onInjurySelected!(injury);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$bodyPart injury',
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _focusOnInjury(Map<String, dynamic> injury) {
    if (!_isModelLoaded) return;
    
    final bodyPart = injury['bodyPart'];
    final status = injury['status'];
    final severity = injury['severity'];
    
    try {
      print('Focusing on injury: $bodyPart (status: $status, severity: $severity)');
      
      // Use the ModelViewerPlus instance to focus on the injury
      _modelViewerKey.currentState?.focusOnInjury(
        bodyPart,
        status: status,
        severity: severity,
      );
    } catch (e) {
      print('Error focusing on injury: $e');
    }
  }
} 