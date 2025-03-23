import 'dart:async';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/motion_data.dart';
import '../models/performance_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PoseDetectionService {
  static const platform = MethodChannel('pose_detection_channel');
  
  // ML Kit pose detector
  late final PoseDetector _mlKitDetector;
  
  // MediaPipe pose detector
  bool _isMediaPipeInitialized = false;
  
  // Performance tracking
  final Map<String, List<double>> _metricHistory = {};
  final int _historySize = 100;
  
  PoseDetectionService() {
    _initializePoseDetection();
  }

  Future<void> _initializePoseDetection() async {
    // Initialize ML Kit pose detector
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    );
    _mlKitDetector = PoseDetector(options: options);
    
    try {
      // Initialize MediaPipe
      await platform.invokeMethod('initializeMediaPipe');
      _isMediaPipeInitialized = true;
    } catch (e) {
      print('Error initializing MediaPipe: $e');
    }
  }

  Future<Map<String, dynamic>> processFrame(CameraImage image, String sessionId) async {
    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImageToInputImage(image);
      
      // Process with ML Kit
      final poses = await _mlKitDetector.processImage(inputImage);
      
      if (poses.isEmpty) {
        return {};
      }
      
      // Convert pose to MotionData
      final motionData = _convertPoseToMotionData(poses.first);
      
      // Calculate performance metrics
      final metrics = await _calculatePerformanceMetrics(motionData);
      
      // Update metric history
      _updateMetricHistory(metrics);
      
      // If MediaPipe is available, use it for additional analysis
      Map<String, dynamic> mediaPipeResults = {};
      if (_isMediaPipeInitialized) {
        mediaPipeResults = await _processWithMediaPipe(image);
      }
      
      return {
        'motion_data': motionData,
        'metrics': {...metrics, ...mediaPipeResults},
        'trends': _calculateTrends(),
      };
    } catch (e) {
      print('Error processing frame: $e');
      return {};
    }
  }

  InputImage _convertCameraImageToInputImage(CameraImage image) {
    // Convert CameraImage to InputImage format
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  MotionData _convertPoseToMotionData(Pose pose) {
    final joints = <String, JointPosition>{};
    final positions = <Point3D>[];
    final angles = <double>[];

    pose.landmarks.forEach((type, landmark) {
      if (landmark.likelihood > 0.5) {
        final point = Point3D(
          x: landmark.x,
          y: landmark.y,
          z: landmark.z,
        );

        final jointPosition = JointPosition(
          x: landmark.x,
          y: landmark.y,
          z: landmark.z,
          confidence: landmark.likelihood,
        );

        joints[type.name] = jointPosition;
        positions.add(point);
      }
    });

    // Calculate joint angles
    angles.addAll(_calculateJointAngles(pose));

    return MotionData(
      joints: joints,
      jointPositions: positions,
      jointAngles: angles,
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
  }

  Future<Map<String, dynamic>> _calculatePerformanceMetrics(MotionData motionData) async {
    final metrics = <String, double>{};
    
    // Calculate basic metrics
    metrics['symmetry'] = _calculateSymmetryScore(motionData);
    metrics['stability'] = _calculateStabilityScore(motionData);
    metrics['speed'] = _calculateSpeed(motionData);
    metrics['range_of_motion'] = _calculateRangeOfMotion(motionData);
    
    // Calculate advanced metrics using MediaPipe if available
    if (_isMediaPipeInitialized) {
      try {
        final advancedMetrics = await platform.invokeMethod(
          'calculateAdvancedMetrics',
          motionData.toJson(),
        );
        metrics.addAll(Map<String, double>.from(advancedMetrics));
      } catch (e) {
        print('Error calculating advanced metrics: $e');
      }
    }
    
    return metrics;
  }

  double _calculateSymmetryScore(MotionData motionData) {
    // Calculate symmetry between left and right body parts
    double totalDiff = 0;
    int pairs = 0;

    final symmetryPairs = {
      'shoulder': ['leftShoulder', 'rightShoulder'],
      'elbow': ['leftElbow', 'rightElbow'],
      'hip': ['leftHip', 'rightHip'],
      'knee': ['leftKnee', 'rightKnee'],
      'ankle': ['leftAnkle', 'rightAnkle'],
    };

    symmetryPairs.forEach((_, pair) {
      final left = motionData.joints[pair[0]];
      final right = motionData.joints[pair[1]];
      
      if (left != null && right != null) {
        totalDiff += (left.y - right.y).abs();
        totalDiff += ((left.x - right.x).abs() - 1.0).abs();
        pairs++;
      }
    });

    return pairs > 0 ? 1.0 - (totalDiff / (pairs * 2)) : 0.0;
  }

  double _calculateStabilityScore(MotionData motionData) {
    // Calculate stability based on key joint positions
    final keyJoints = ['spine', 'neck', 'nose'];
    double totalStability = 0;
    int count = 0;

    for (final joint in keyJoints) {
      final position = motionData.joints[joint];
      if (position != null) {
        // Higher confidence and less movement indicates more stability
        totalStability += position.confidence * (1.0 - position.y.abs() / 2.0);
        count++;
      }
    }

    return count > 0 ? totalStability / count : 0.0;
  }

  double _calculateSpeed(MotionData motionData) {
    // Calculate average speed of movement
    if (motionData.jointPositions.length < 2) return 0.0;

    double totalSpeed = 0;
    int count = 0;

    for (int i = 1; i < motionData.jointPositions.length; i++) {
      final prev = motionData.jointPositions[i - 1];
      final curr = motionData.jointPositions[i];
      
      final distance = _calculateDistance(prev, curr);
      totalSpeed += distance / 0.033; // Assuming 30fps
      count++;
    }

    return count > 0 ? totalSpeed / count : 0.0;
  }

  double _calculateDistance(Point3D p1, Point3D p2) {
    return sqrt(
      pow(p2.x - p1.x, 2) +
      pow(p2.y - p1.y, 2) +
      pow(p2.z - p1.z, 2)
    );
  }

  double _calculateRangeOfMotion(MotionData motionData) {
    // Calculate range of motion based on joint angles
    if (motionData.jointAngles.isEmpty) return 0.0;

    double totalROM = 0;
    for (final angle in motionData.jointAngles) {
      totalROM += angle / 180.0; // Normalize to 0-1 range
    }

    return totalROM / motionData.jointAngles.length;
  }

  List<double> _calculateJointAngles(Pose pose) {
    final angles = <double>[];
    
    // Define joint triplets for angle calculation
    final jointTriplets = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    for (final triplet in jointTriplets) {
      final angle = _calculateAngle(
        pose.landmarks[triplet[0]]!,
        pose.landmarks[triplet[1]]!,
        pose.landmarks[triplet[2]]!,
      );
      angles.add(angle);
    }

    return angles;
  }

  double _calculateAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    if (first.likelihood < 0.5 || mid.likelihood < 0.5 || last.likelihood < 0.5) {
      return 0.0;
    }

    final a = [first.x - mid.x, first.y - mid.y];
    final b = [last.x - mid.x, last.y - mid.y];

    final dot = a[0] * b[0] + a[1] * b[1];
    final magA = sqrt(a[0] * a[0] + a[1] * a[1]);
    final magB = sqrt(b[0] * b[0] + b[1] * b[1]);

    if (magA == 0 || magB == 0) return 0.0;
    
    final cosTheta = dot / (magA * magB);
    if (cosTheta > 1 || cosTheta < -1) return 0.0;

    return acos(cosTheta) * 180 / pi;
  }

  void _updateMetricHistory(Map<String, dynamic> metrics) {
    metrics.forEach((key, value) {
      if (value is double) {
        _metricHistory.putIfAbsent(key, () => []);
        _metricHistory[key]!.add(value);
        
        // Keep history size limited
        if (_metricHistory[key]!.length > _historySize) {
          _metricHistory[key]!.removeAt(0);
        }
      }
    });
  }

  Map<String, dynamic> _calculateTrends() {
    final trends = <String, dynamic>{};
    
    _metricHistory.forEach((metric, values) {
      if (values.length < 2) return;
      
      // Calculate short-term trend (last 10 values)
      final shortTermValues = values.length > 10 
          ? values.sublist(values.length - 10)
          : values;
      trends['${metric}_trend_short'] = _calculateTrendSlope(shortTermValues);
      
      // Calculate overall trend
      trends['${metric}_trend_overall'] = _calculateTrendSlope(values);
    });
    
    return trends;
  }

  double _calculateTrendSlope(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final n = values.length;
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    
    for (int i = 0; i < n; i++) {
      sumX += i.toDouble();
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }
    
    // Calculate slope using least squares method
    return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  }

  Future<Map<String, dynamic>> _processWithMediaPipe(CameraImage image) async {
    try {
      final result = await platform.invokeMethod('processWithMediaPipe', {
        'imageData': image.planes[0].bytes,
        'width': image.width,
        'height': image.height,
        'rotation': 0,
      });
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error processing with MediaPipe: $e');
      return {};
    }
  }

  void dispose() {
    _mlKitDetector.close();
  }
}

// Helper functions
double sqrt(double x) => pow(x, 0.5);
double pow(double x, double exponent) => math.pow(x, exponent).toDouble();
double pi = 3.141592653589793;
double acos(double x) => math.acos(x);

// Import math library at the top of the file
import 'dart:math' as math; 