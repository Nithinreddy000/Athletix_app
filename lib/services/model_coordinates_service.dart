import 'dart:convert';
import 'dart:math' show cos, sin, sqrt, pi;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelCoordinatesService {
  static final ModelCoordinatesService _instance = ModelCoordinatesService._internal();
  Map<String, List<Map<String, double>>> _calibratedZones = {};
  bool _isCalibrationMode = false;
  bool _isInitialized = false;
  String? _selectedBodyPart;
  
  // Define hit zones for each body part
  final Map<String, Map<String, double>> _hitZones = {
    'head': {'y_min': 0.85, 'y_max': 1.0, 'x_min': 0.35, 'x_max': 0.65},
    'neck': {'y_min': 0.80, 'y_max': 0.85, 'x_min': 0.40, 'x_max': 0.60},
    'right_shoulder': {'y_min': 0.70, 'y_max': 0.80, 'x_min': 0.65, 'x_max': 0.85},
    'left_shoulder': {'y_min': 0.70, 'y_max': 0.80, 'x_min': 0.15, 'x_max': 0.35},
    'right_arm': {'y_min': 0.55, 'y_max': 0.70, 'x_min': 0.65, 'x_max': 0.85},
    'left_arm': {'y_min': 0.55, 'y_max': 0.70, 'x_min': 0.15, 'x_max': 0.35},
    'right_elbow': {'y_min': 0.45, 'y_max': 0.55, 'x_min': 0.60, 'x_max': 0.75},
    'left_elbow': {'y_min': 0.45, 'y_max': 0.55, 'x_min': 0.25, 'x_max': 0.40},
    'spine': {'y_min': 0.60, 'y_max': 0.75, 'x_min': 0.40, 'x_max': 0.60},
    'torso': {'y_min': 0.45, 'y_max': 0.60, 'x_min': 0.35, 'x_max': 0.65},
    'right_hip': {'y_min': 0.35, 'y_max': 0.45, 'x_min': 0.55, 'x_max': 0.70},
    'left_hip': {'y_min': 0.35, 'y_max': 0.45, 'x_min': 0.30, 'x_max': 0.45},
    'right_knee': {'y_min': 0.20, 'y_max': 0.35, 'x_min': 0.50, 'x_max': 0.65},
    'left_knee': {'y_min': 0.20, 'y_max': 0.35, 'x_min': 0.35, 'x_max': 0.50},
    'right_leg': {'y_min': 0.05, 'y_max': 0.20, 'x_min': 0.50, 'x_max': 0.65},
    'left_leg': {'y_min': 0.05, 'y_max': 0.20, 'x_min': 0.35, 'x_max': 0.50},
  };

  // Available body parts for calibration
  final List<String> availableBodyParts = [
    // Group 1 - Head and Spine
    'head',
    'neck',
    'spine_top',
    'spine_down',
    'waist',
    'right_shoulder',
    
    // Group 2 - Arms
    'left_shoulder',
    'right_upper_arm',
    'left_upper_arm',
    'right_forearm',
    'left_forearm',
    'right_hand',
    'left_hand',
    
    // Group 3 - Legs
    'right_thigh',
    'left_thigh',
    'right_calf',
    'left_calf',
    'right_foot',
    'left_foot',
  ];

  factory ModelCoordinatesService() {
    return _instance;
  }

  ModelCoordinatesService._internal();

  bool get isCalibrationMode => _isCalibrationMode;
  String? get selectedBodyPart => _selectedBodyPart;
  
  void toggleCalibrationMode() {
    _isCalibrationMode = !_isCalibrationMode;
    if (!_isCalibrationMode) {
      _selectedBodyPart = null;
    }
  }

  void setSelectedBodyPart(String? bodyPart) {
    _selectedBodyPart = bodyPart;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadCalibration();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing ModelCoordinatesService: $e');
      rethrow;
    }
  }

  Future<void> _loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final String? calibrationData = prefs.getString('body_part_calibration');
    if (calibrationData != null) {
      final Map<String, dynamic> data = json.decode(calibrationData);
      _calibratedZones = Map.fromEntries(
        data.entries.map((e) => MapEntry(
          e.key,
          (e.value as List).map((point) => Map<String, double>.from(point)).toList(),
        )),
      );
    }
  }

  Future<void> saveCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final String calibrationData = json.encode(_calibratedZones);
    await prefs.setString('body_part_calibration', calibrationData);
  }

  Future<void> addCalibrationPoint(String bodyPart, double x, double y) async {
    if (!_calibratedZones.containsKey(bodyPart)) {
      _calibratedZones[bodyPart] = [];
    }
    
    // Updated radius values for better hit detection
    double radius = bodyPart == 'head' ? 0.15 : 
                   bodyPart.contains('shoulder') ? 0.12 :
                   bodyPart.contains('hand') || bodyPart.contains('foot') ? 0.08 :
                   bodyPart.contains('spine') ? 0.13 :
                   bodyPart.contains('thigh') || bodyPart.contains('calf') ? 0.11 :
                   0.10;  // Default radius for other body parts
    
    _calibratedZones[bodyPart]!.add({
      'x': x,
      'y': y,
      'radius': radius
    });
    
    print('Added calibration point for $bodyPart at ($x, $y) with radius $radius');
    await saveCalibration();
  }

  Future<void> clearCalibration() async {
    _calibratedZones.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('body_part_calibration');
  }

  String getBodyPartFromScreenPosition(double screenX, double screenY, double modelWidth, double modelHeight, double rotation) {
    if (!_isInitialized) throw Exception('ModelCoordinatesService not initialized');

    double x = screenX / modelWidth;
    double y = screenY / modelHeight;

    print('Screen coordinates: ($screenX, $screenY)');
    print('Normalized coordinates: ($x, $y)');

    if (!_calibratedZones.isEmpty) {
    String closestPart = '';
    double minDistance = double.infinity;
      Map<String, double> verticalWeights = {
        'head': 2.5,
        'neck': 2.0,
        'spine_top': 1.8,
        'spine_down': 1.8,
        'waist': 1.8,
        'right_shoulder': 1.5,
        'left_shoulder': 1.5,
        'right_upper_arm': 1.3,
        'left_upper_arm': 1.3,
        'right_forearm': 1.3,
        'left_forearm': 1.3,
        'right_hand': 1.2,
        'left_hand': 1.2,
        'right_thigh': 1.8,
        'left_thigh': 1.8,
        'right_calf': 1.5,
        'left_calf': 1.5,
        'right_foot': 1.2,
        'left_foot': 1.2,
      };

      // Vertical zones with margins
      Map<String, Map<String, double>> verticalZones = {
        'head': {'min': 0.23, 'max': 0.29},
        'neck': {'min': 0.29, 'max': 0.35},
        'shoulder': {'min': 0.320, 'max': 0.324},  // Tightened shoulder range
        'spine_top': {'min': 0.33, 'max': 0.41},
        'spine_down': {'min': 0.40, 'max': 0.46},
        'waist': {'min': 0.45, 'max': 0.51},
        'upper_arm': {'min': 0.33, 'max': 0.34},
        'forearm': {'min': 0.331, 'max': 0.339},
        'hand': {'min': 0.333, 'max': 0.337},
        'thigh': {'min': 0.51, 'max': 0.635},
        'calf': {'min': 0.66, 'max': 0.76},
        'foot': {'min': 0.79, 'max': 0.81},
      };

      // Horizontal zones for right side with adjusted ranges
      Map<String, Map<String, double>> rightSideZones = {
        'right_shoulder': {'min': 0.290, 'max': 0.305},  // Expanded shoulder range
        'right_upper_arm': {'min': 0.270, 'max': 0.283},
        'right_forearm': {'min': 0.220, 'max': 0.260},
        'right_hand': {'min': 0.205, 'max': 0.215},
        'right_thigh': {'min': 0.309, 'max': 0.325},
        'right_calf': {'min': 0.309, 'max': 0.315},
        'right_foot': {'min': 0.310, 'max': 0.315},
      };

    _calibratedZones.forEach((bodyPart, points) {
        String zoneKey = bodyPart.replaceAll(RegExp(r'(left_|right_)'), '');
        var zone = verticalZones[zoneKey];
        
        if (zone != null && y >= zone['min']! && y <= zone['max']!) {
          for (var point in points) {
            double dx = x - point['x']!;
            double dy = (y - point['y']!) * (verticalWeights[bodyPart] ?? 1.0);
            
            // Enhanced right-side detection with priority zones
            if (bodyPart.startsWith('right_')) {
              var rightZone = rightSideZones[bodyPart];
              if (rightZone != null) {
                // Priority detection for shoulder and hand
                if (bodyPart == 'right_shoulder' && 
                    x >= 0.290 && x <= 0.305 && 
                    y >= 0.320 && y <= 0.324) {
                  dx *= 0.4;  // Higher priority for shoulder
                } else if (bodyPart == 'right_hand' && 
                         x >= 0.205 && x <= 0.215 && 
                         y >= 0.333 && y <= 0.337) {
                  dx *= 0.4;  // Higher priority for hand
                } else {
                  dx *= 0.6;  // Normal right side priority
                }
              }
            }
            
            double distance = sqrt(dx * dx + dy * dy);
            var radius = point['radius']! * 1.2;
            
            // Additional validation for right-side parts
            bool isValidPosition = true;
            if (bodyPart.startsWith('right_')) {
              if (bodyPart == 'right_shoulder') {
                isValidPosition = y >= 0.320 && y <= 0.324;
                if (x >= 0.290 && x <= 0.305) {
                  radius *= 1.4;  // Increased radius for shoulder
                }
              } else if (bodyPart == 'right_hand') {
                isValidPosition = y >= 0.333 && y <= 0.337;
                if (x >= 0.205 && x <= 0.215) {
                  radius *= 1.4;  // Increased radius for hand
                }
              } else {
                // Keep existing validation for other parts
                isValidPosition = isValidPosition && 
                  !(bodyPart == 'spine_top' || bodyPart.startsWith('left_'));
              }
            }

            if (distance < minDistance && distance < radius && isValidPosition) {
              // Prioritize right shoulder and hand in their zones
              if ((bodyPart == 'right_shoulder' && 
                   x >= 0.290 && x <= 0.305 && 
                   y >= 0.320 && y <= 0.324) ||
                  (bodyPart == 'right_hand' && 
                   x >= 0.205 && x <= 0.215 && 
                   y >= 0.333 && y <= 0.337)) {
                minDistance = distance * 0.8;  // Give priority by reducing distance
              }
          closestPart = bodyPart;
            }
        }
      }
    });

      if (closestPart.isNotEmpty) {
        print('Found calibrated part: $closestPart at distance $minDistance');
        return closestPart;
      }
    }

    // Updated fallback zones with adjusted ranges
    Map<String, Map<String, double>> fallbackZones = {
      'head': {'y_min': 0.23, 'y_max': 0.29, 'x_min': 0.32, 'x_max': 0.35},
      'neck': {'y_min': 0.29, 'y_max': 0.35, 'x_min': 0.32, 'x_max': 0.35},
      'right_shoulder': {'y_min': 0.320, 'y_max': 0.324, 'x_min': 0.290, 'x_max': 0.305},
      'right_hand': {'y_min': 0.333, 'y_max': 0.337, 'x_min': 0.205, 'x_max': 0.215},
      'right_upper_arm': {'y_min': 0.332, 'y_max': 0.338, 'x_min': 0.270, 'x_max': 0.283},
      'right_forearm': {'y_min': 0.331, 'y_max': 0.339, 'x_min': 0.220, 'x_max': 0.260},
      'right_thigh': {'y_min': 0.512, 'y_max': 0.634, 'x_min': 0.309, 'x_max': 0.325},
      'right_calf': {'y_min': 0.660, 'y_max': 0.760, 'x_min': 0.309, 'x_max': 0.315},
      'right_foot': {'y_min': 0.790, 'y_max': 0.810, 'x_min': 0.310, 'x_max': 0.315},
      'left_shoulder': {'y_min': 0.30, 'y_max': 0.36, 'x_min': 0.35, 'x_max': 0.39},
      'left_upper_arm': {'y_min': 0.31, 'y_max': 0.36, 'x_min': 0.23, 'x_max': 0.27},
      'left_forearm': {'y_min': 0.31, 'y_max': 0.35, 'x_min': 0.45, 'x_max': 0.48},
      'left_hand': {'y_min': 0.31, 'y_max': 0.35, 'x_min': 0.45, 'x_max': 0.48},
      'left_thigh': {'y_min': 0.54, 'y_max': 0.60, 'x_min': 0.34, 'x_max': 0.37},
      'left_calf': {'y_min': 0.68, 'y_max': 0.75, 'x_min': 0.34, 'x_max': 0.37},
    };

    for (var entry in fallbackZones.entries) {
      var zone = entry.value;
      if (y >= zone['y_min']! && y <= zone['y_max']! &&
          x >= zone['x_min']! && x <= zone['x_max']!) {
        return entry.key;
      }
    }

    return 'unknown';
  }
} 