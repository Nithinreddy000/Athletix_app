import 'package:flutter/material.dart';
import '../../../../widgets/model_viewer_plus_widget.dart';

class EnhancedModelViewer extends StatefulWidget {
  final String modelUrl;
  final List<Map<String, dynamic>> injuries;
  final Function(Map<String, dynamic>)? onInjurySelected;

  const EnhancedModelViewer({
    Key? key,
    required this.modelUrl,
    required this.injuries,
    this.onInjurySelected,
  }) : super(key: key);

  @override
  _EnhancedModelViewerState createState() => _EnhancedModelViewerState();
}

class _EnhancedModelViewerState extends State<EnhancedModelViewer> {
  bool _isModelLoaded = false;
  Map<String, dynamic>? _selectedInjury;
  final GlobalKey<ModelViewerPlusState> _modelViewerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The 3D model viewer
        ModelViewerPlus(
          key: _modelViewerKey,
          modelUrl: widget.modelUrl,
          onModelLoaded: (success) {
            setState(() => _isModelLoaded = success);
            if (!success) {
              print('Enhanced viewer: Failed to load model: ${widget.modelUrl}');
            } else {
              print('Enhanced viewer: Model loaded successfully: ${widget.modelUrl}');
              
              // If there's a selected injury, focus on it after model loads
              if (_selectedInjury != null) {
                _focusOnInjury(_selectedInjury!);
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
                    'Loading Enhanced Visualization...\n${widget.modelUrl.split('/').last}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
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
    
    // If the model URL changed, reset the selected injury
    if (oldWidget.modelUrl != widget.modelUrl) {
      setState(() {
        _isModelLoaded = false;
        _selectedInjury = null;
      });
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