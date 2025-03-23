import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/enhanced_three_viewer_widget.dart';

class EnhancedInjuryVisualizationScreen extends StatefulWidget {
  final String modelUrl;
  final String title;
  final List<Map<String, dynamic>> injuries;

  const EnhancedInjuryVisualizationScreen({
    Key? key,
    required this.modelUrl,
    required this.injuries,
    this.title = "Injury Visualization",
  }) : super(key: key);

  @override
  _EnhancedInjuryVisualizationScreenState createState() => _EnhancedInjuryVisualizationScreenState();
}

class _EnhancedInjuryVisualizationScreenState extends State<EnhancedInjuryVisualizationScreen> {
  bool autoRotate = true;
  Color backgroundColor = Colors.black;
  bool isLoading = false;
  String? errorMessage;
  int selectedInjuryIndex = -1; // -1 means show all injuries
  
  // Reference to the viewer widget for controlling it
  final GlobalKey<EnhancedThreeViewerWidgetState> _viewerKey = GlobalKey<EnhancedThreeViewerWidgetState>();

  @override
  Widget build(BuildContext context) {
    // Process injuries to remove duplicates
    List<Map<String, dynamic>> uniqueInjuries = [];
    if (widget.injuries.isNotEmpty) {
      // Create a map to track unique bodyPart values
      Map<String, Map<String, dynamic>> uniqueInjuriesMap = {};
      
      // Process each injury
      for (var injury in widget.injuries) {
        final bodyPart = injury['bodyPart'] ?? 'Unknown';
        // Only add if this bodyPart hasn't been seen before
        if (!uniqueInjuriesMap.containsKey(bodyPart)) {
          // Rename 'side' to 'injury' if it exists
          if (injury.containsKey('side')) {
            final sideValue = injury['side'];
            Map<String, dynamic> updatedInjury = Map.from(injury);
            updatedInjury['injury'] = sideValue;
            uniqueInjuriesMap[bodyPart] = updatedInjury;
          } else {
            uniqueInjuriesMap[bodyPart] = injury;
          }
        }
      }
      
      // Convert map back to list
      uniqueInjuries = uniqueInjuriesMap.values.toList();
    }

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
              if (_viewerKey.currentState != null) {
                _viewerKey.currentState!.setAutoRotate(autoRotate);
              }
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
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_viewerKey.currentState != null) {
                _viewerKey.currentState!.resetView();
              }
            },
            tooltip: 'Reset view',
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
          // Injury selection chips
          if (uniqueInjuries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: const Text('All Injuries'),
                        selected: selectedInjuryIndex == -1,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              selectedInjuryIndex = -1;
                            });
                            _focusOnAllInjuries();
                          }
                        },
                      ),
                    ),
                    ...List.generate(uniqueInjuries.length, (index) {
                      final injury = uniqueInjuries[index];
                      final bodyPart = injury['bodyPart'] ?? 'Unknown';
                      final status = injury['status'] ?? 'active';
                      
                      // Determine chip color based on injury status
                      Color chipColor;
                      if (status == 'active') {
                        chipColor = Colors.red;
                      } else if (status == 'past') {
                        chipColor = Colors.orange;
                      } else {
                        chipColor = Colors.green;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(bodyPart),
                          selected: selectedInjuryIndex == index,
                          selectedColor: chipColor.withOpacity(0.7),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedInjuryIndex = index;
                              });
                              _focusOnInjury(index, uniqueInjuries);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          Expanded(
            child: EnhancedThreeViewerWidget(
              key: _viewerKey,
              modelUrl: widget.modelUrl,
              autoRotate: autoRotate,
              showControls: true,
              onModelLoaded: (success) {
                setState(() {
                  isLoading = false;
                  errorMessage = success ? null : 'Failed to load model';
                });
              },
            ),
          ),
          // Injury details panel
          if (selectedInjuryIndex >= 0 && selectedInjuryIndex < uniqueInjuries.length)
            _buildInjuryDetailsPanel(uniqueInjuries[selectedInjuryIndex]),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Powered by Enhanced Three.js Renderer',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (kIsWeb)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Web Mode: Using Three.js with custom shaders',
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
  
  Widget _buildInjuryDetailsPanel(Map<String, dynamic> injury) {
    final bodyPart = injury['bodyPart'] ?? 'Unknown';
    final status = injury['status'] ?? 'active';
    final severity = injury['severity'] ?? 'moderate';
    final diagnosis = injury['diagnosis'] ?? 'No diagnosis available';
    
    // Determine status color
    Color statusColor;
    if (status == 'active') {
      statusColor = Colors.red;
    } else if (status == 'past') {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey.shade900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bodyPart,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Severity: ${severity.toUpperCase()}',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            diagnosis,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _focusOnInjury(int index, List<Map<String, dynamic>> uniqueInjuries) {
    if (index < 0 || index >= uniqueInjuries.length) return;
    
    final injury = uniqueInjuries[index];
    final bodyPart = injury['bodyPart'];
    final status = injury['status'] ?? 'active';
    final severity = injury['severity'] ?? 'moderate';
    final injuryType = injury['injury'] ?? injury['side'];
    
    if (bodyPart != null && _viewerKey.currentState != null) {
      _viewerKey.currentState!.visualizeInjury(
        bodyPart,
        status: status,
        severity: severity,
        injury: injuryType,
      );
    }
  }
  
  void _focusOnAllInjuries() {
    // Reset the view to show all injuries
    if (_viewerKey.currentState != null) {
      _viewerKey.currentState!.resetView();
    }
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
                _colorOption(const Color(0xFF1A1A2E), 'Deep Navy'),
                _colorOption(const Color(0xFF0D0D0D), 'Near Black'),
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
        if (_viewerKey.currentState != null) {
          _viewerKey.currentState!.setBackgroundColor(color);
        }
        Navigator.of(context).pop();
      },
    );
  }
} 