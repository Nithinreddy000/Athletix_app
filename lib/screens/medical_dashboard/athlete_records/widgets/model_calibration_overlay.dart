import 'package:flutter/material.dart';
import '../../../../services/model_coordinates_service.dart';

class ModelCalibrationOverlay extends StatefulWidget {
  final Function(String bodyPart, double x, double y) onCalibrationPoint;
  final VoidCallback onFinishCalibration;

  const ModelCalibrationOverlay({
    Key? key,
    required this.onCalibrationPoint,
    required this.onFinishCalibration,
  }) : super(key: key);

  @override
  _ModelCalibrationOverlayState createState() => _ModelCalibrationOverlayState();
}

class _ModelCalibrationOverlayState extends State<ModelCalibrationOverlay> {
  final ModelCoordinatesService _modelService = ModelCoordinatesService();
  List<Offset> calibrationPoints = [];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Show all calibration points
        ...calibrationPoints.map((point) => Positioned(
          left: point.dx - 5,
          top: point.dy - 5,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        )).toList(),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calibration Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Select body part',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '2. Click on the model',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 16),
                    DropdownButton<String>(
                      value: _modelService.selectedBodyPart,
                      hint: Text(
                        'Select Body Part',
                        style: TextStyle(color: Colors.white70),
                      ),
                      dropdownColor: Colors.black87,
                      items: [
                        // Group 1 - Head and Spine
                        DropdownMenuItem(
                          enabled: false,
                          child: Text(
                            '-- Head & Spine --',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ..._modelService.availableBodyParts.take(6).map((part) => 
                          DropdownMenuItem(
                            value: part,
                            child: Text(
                              _formatBodyPartName(part),
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        ),
                        
                        // Group 2 - Arms
                        DropdownMenuItem(
                          enabled: false,
                          child: Text(
                            '-- Arms --',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ..._modelService.availableBodyParts.skip(6).take(7).map((part) => 
                          DropdownMenuItem(
                            value: part,
                            child: Text(
                              _formatBodyPartName(part),
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        ),
                        
                        // Group 3 - Legs
                        DropdownMenuItem(
                          enabled: false,
                          child: Text(
                            '-- Legs --',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ..._modelService.availableBodyParts.skip(13).map((part) => 
                          DropdownMenuItem(
                            value: part,
                            child: Text(
                              _formatBodyPartName(part),
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _modelService.setSelectedBodyPart(value);
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await _modelService.clearCalibration();
                            setState(() {
                              calibrationPoints.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Calibration cleared'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: Text('Clear All'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (calibrationPoints.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please add at least one calibration point'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            widget.onFinishCalibration();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text('Finish'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatBodyPartName(String part) {
    return part
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
  }
} 