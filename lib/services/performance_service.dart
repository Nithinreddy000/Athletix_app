import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/performance_models.dart';
import '../models/motion_data.dart';
import 'dart:math' as math;
import 'dart:async';

class PerformanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  mlkit.PoseDetector? _poseDetector;
  bool _isProcessing = false;
  
  static const Map<String, List<String>> sportSpecificMetrics = {
    'basketball': ['shooting_accuracy', 'jump_height', 'agility', 'ball_handling'],
    'football': ['sprint_speed', 'kick_power', 'passing_accuracy', 'stamina'],
    'tennis': ['serve_speed', 'forehand_power', 'backhand_accuracy', 'court_coverage'],
    'swimming': ['stroke_efficiency', 'kick_power', 'turn_speed', 'breathing_rhythm'],
    'athletics': ['sprint_speed', 'jump_height', 'throwing_power', 'technique'],
  };

  // Performance thresholds based on Olympic standards
  static const Map<String, Map<String, double>> olympicThresholds = {
    'athletics': {
      'sprint_reaction_time': 0.1,  // seconds
      'stride_length': 2.2,  // meters
      'ground_contact_time': 0.085,  // seconds
      'vertical_oscillation': 6.5,  // cm
    },
    'gymnastics': {
      'balance_deviation': 2.0,  // cm
      'rotation_speed': 720,  // degrees/second
      'landing_impact': 12.0,  // times body weight
      'hold_stability': 0.98,  // percentage
    },
    'swimming': {
      'stroke_rate': 120,  // strokes/minute
      'body_rotation': 45,  // degrees
      'kick_power': 0.95,  // normalized
      'streamline_position': 0.92,  // percentage
    },
  };

  // Biomechanical constraints for different sports
  static const Map<String, Map<String, List<double>>> biomechanicalRanges = {
    'sprint': {
      'knee_angle': [165.0, 180.0],
      'hip_extension': [170.0, 180.0],
      'ankle_flexion': [20.0, 30.0],
    },
    'jump': {
      'knee_flexion': [90.0, 120.0],
      'hip_flexion': [80.0, 110.0],
      'ankle_dorsiflexion': [15.0, 25.0],
    },
    'throw': {
      'elbow_extension': [150.0, 180.0],
      'shoulder_rotation': [150.0, 180.0],
      'trunk_rotation': [45.0, 60.0],
    },
  };

  // Performance analysis buffers
  final List<MotionData> _motionBuffer = [];
  final int _bufferSize = 30; // 1 second at 30fps
  Timer? _analysisTimer;
  
  StreamController<Map<String, dynamic>>? _metricsStreamController;
  Stream<Map<String, dynamic>>? get metricsStream => _metricsStreamController?.stream;

  // Enhanced analysis buffers
  final List<List<mlkit.PoseLandmark>> _poseHistory = [];
  final int _historySize = 30; // Store last 30 frames
  
  // Technique scoring parameters
  final Map<String, double> _techniqueWeights = {
    'posture': 0.3,
    'symmetry': 0.2,
    'smoothness': 0.25,
    'range_of_motion': 0.25,
  };

  // Add new fields for session management
  final Map<String, TrainingSession> _activeSessions = {};
  Map<String, List<String>> _coachAthletes = {};  // coach_id -> list of athlete_ids
  
  // Athlete tracking data
  Map<String, AthleteTrackingData> _athleteTracking = {};
  
  // Add new fields for match/competition analysis
  static const Map<String, Map<String, MetricDefinition>> olympicMetrics = {
    'general': {
      'reaction_time': MetricDefinition(
        name: 'Reaction Time',
        description: 'Time to respond to stimulus',
        unit: 'seconds',
        threshold: 0.15,
        isLowerBetter: true,
      ),
      'power_output': MetricDefinition(
        name: 'Power Output',
        description: 'Force generation capacity',
        unit: 'watts',
        threshold: 1000,
        isLowerBetter: false,
      ),
      'technique_score': MetricDefinition(
        name: 'Technique Score',
        description: 'Overall movement quality',
        unit: 'points',
        threshold: 9.5,
        isLowerBetter: false,
      ),
    },
    'sprint': {
      'start_reaction': MetricDefinition(
        name: 'Start Reaction',
        description: 'Time to react at the start',
        unit: 'seconds',
        threshold: 0.1,
        isLowerBetter: true,
      ),
      'acceleration': MetricDefinition(
        name: 'Acceleration',
        description: 'Rate of change in velocity',
        unit: 'm/s²',
        threshold: 8.0,
        isLowerBetter: false,
      ),
      'top_speed': MetricDefinition(
        name: 'Top Speed',
        description: 'Maximum velocity achieved',
        unit: 'm/s',
        threshold: 11.0,
        isLowerBetter: false,
      ),
    },
    'swimming': {
      'stroke_rate': MetricDefinition(
        name: 'Stroke Rate',
        description: 'Number of strokes per minute',
        unit: 'strokes/min',
        threshold: 120,
        isLowerBetter: false,
      ),
      'turn_time': MetricDefinition(
        name: 'Turn Time',
        description: 'Time taken to complete a turn',
        unit: 'seconds',
        threshold: 0.6,
        isLowerBetter: true,
      ),
    },
    // Add more sports...
  };

  // Add new sport-specific metrics
  static const Map<String, Map<String, MetricDefinition>> sportMetrics = {
    'basketball': {
      'shooting_accuracy': MetricDefinition(
        name: 'Shooting Accuracy',
        description: 'Percentage of successful shots',
        unit: '%',
        threshold: 85.0,
        isLowerBetter: false,
        subMetrics: {
          'three_point': MetricDefinition(
            name: 'Three Point',
            description: 'Three point shooting accuracy',
            unit: '%',
            threshold: 40.0,
            isLowerBetter: false,
          ),
          'free_throw': MetricDefinition(
            name: 'Free Throw',
            description: 'Free throw accuracy',
            unit: '%',
            threshold: 90.0,
            isLowerBetter: false,
          ),
          'field_goal': MetricDefinition(
            name: 'Field Goal',
            description: 'Field goal percentage',
            unit: '%',
            threshold: 55.0,
            isLowerBetter: false,
          ),
        },
      ),
      'vertical_jump': MetricDefinition(
        name: 'Vertical Jump',
        description: 'Maximum vertical jump height',
        unit: 'cm',
        threshold: 71.0,
        isLowerBetter: false,
      ),
      'reaction_speed': MetricDefinition(
        name: 'Reaction Speed',
        description: 'Time taken to react to stimulus',
        unit: 'ms',
        threshold: 200.0,
        isLowerBetter: true,
      ),
      'sprint_speed': MetricDefinition(
        name: 'Sprint Speed',
        description: 'Maximum running velocity',
        unit: 'm/s',
        threshold: 8.5,
        isLowerBetter: false,
      ),
    },
    'volleyball': {
      'spike_velocity': MetricDefinition(
        name: 'Spike Velocity',
        description: 'Speed of volleyball spike',
        unit: 'km/h',
        threshold: 100.0,
        isLowerBetter: false,
      ),
      'block_height': MetricDefinition(
        name: 'Block Height',
        description: 'Maximum height reached during block',
        unit: 'cm',
        threshold: 315.0,
        isLowerBetter: false,
      ),
      'serve_accuracy': MetricDefinition(
        name: 'Serve Accuracy',
        description: 'Percentage of successful serves',
        unit: '%',
        threshold: 95.0,
        isLowerBetter: false,
      ),
    },
    'athletics_sprint': {
      'start_reaction': MetricDefinition(
        name: 'Start Reaction',
        description: 'Reaction time at race start',
        unit: 'seconds',
        threshold: 0.12,
        isLowerBetter: true,
        subMetrics: {
          'block_clearance': MetricDefinition(
            name: 'Block Clearance',
            description: 'Time to clear starting blocks',
            unit: 'seconds',
            threshold: 0.25,
            isLowerBetter: true,
          ),
          'first_step': MetricDefinition(
            name: 'First Step',
            description: 'Time to complete first step',
            unit: 'seconds',
            threshold: 0.15,
            isLowerBetter: true,
          ),
        },
      ),
      'acceleration': MetricDefinition(
        name: 'Acceleration',
        description: 'Rate of change in sprint velocity',
        unit: 'm/s²',
        threshold: 9.8,
        isLowerBetter: false,
      ),
      'stride_length': MetricDefinition(
        name: 'Stride Length',
        description: 'Distance covered in one stride',
        unit: 'm',
        threshold: 2.6,
        isLowerBetter: false,
      ),
      'stride_frequency': MetricDefinition(
        name: 'Stride Frequency',
        description: 'Number of strides per second',
        unit: 'steps/s',
        threshold: 4.5,
        isLowerBetter: false,
      ),
    },
  };

  PerformanceService() {
    _initializePoseDetector();
    _metricsStreamController = StreamController<Map<String, dynamic>>.broadcast();
    _startPeriodicAnalysis();
  }

  void _initializePoseDetector() {
    try {
      _poseDetector = mlkit.PoseDetector(
        options: mlkit.PoseDetectorOptions(
          mode: mlkit.PoseDetectionMode.stream,
        ),
      );
    } catch (e) {
      print('Error initializing pose detector: $e');
    }
  }

  void _startPeriodicAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_motionBuffer.isNotEmpty) {
        final analysis = _analyzeMotionBuffer();
        _metricsStreamController?.add(analysis);
      }
    });
  }

  Map<String, dynamic> _analyzeMotionBuffer() {
    if (_motionBuffer.isEmpty) return {};

    // Calculate velocity and acceleration for each joint
    final velocities = _calculateJointVelocities();
    final accelerations = _calculateJointAccelerations();
    
    // Calculate basic metrics that are actually reliable with ML Kit
    final latestMotion = _motionBuffer.last;
    final symmetryScore = _calculateBasicSymmetry(latestMotion);
    final stabilityScore = _calculateBasicStability(latestMotion);
    
    // Calculate movement consistency
    final consistency = _calculateMovementConsistency();

    return {
      'kinematics': {
        'velocities': velocities,
        'accelerations': accelerations,
      },
      'performance': {
        'symmetryScore': symmetryScore,
        'stabilityScore': stabilityScore,
        'consistency': consistency,
        // Add sport-specific metrics based on the movement type
        'metrics': _calculateSportSpecificMetrics(velocities, accelerations),
      },
    };
  }

  Map<String, double> _calculateSportSpecificMetrics(
    Map<String, List<double>> velocities,
    Map<String, List<double>> accelerations,
  ) {
    Map<String, double> metrics = {};

    // Calculate vertical movement (useful for jumps)
    double maxVerticalVelocity = 0.0;
    velocities.forEach((_, vel) {
      if (vel[1].abs() > maxVerticalVelocity) {
        maxVerticalVelocity = vel[1].abs();
      }
    });
    metrics['verticalVelocity'] = maxVerticalVelocity;

    // Calculate horizontal movement (useful for sprints/runs)
    double maxHorizontalVelocity = 0.0;
    velocities.forEach((_, vel) {
      final horizontalVel = math.sqrt(math.pow(vel[0], 2) + math.pow(vel[2], 2));
      if (horizontalVel > maxHorizontalVelocity) {
        maxHorizontalVelocity = horizontalVel;
      }
    });
    metrics['horizontalVelocity'] = maxHorizontalVelocity;

    // Calculate overall movement intensity
    double totalAcceleration = 0.0;
    int accCount = 0;
    accelerations.forEach((_, acc) {
      totalAcceleration += math.sqrt(math.pow(acc[0], 2) + math.pow(acc[1], 2) + math.pow(acc[2], 2));
      accCount++;
    });
    metrics['movementIntensity'] = accCount > 0 ? totalAcceleration / accCount : 0.0;

    return metrics;
  }

  double _calculateStabilityScore(MotionData motionData) {
    return _calculateBasicStability(motionData);
  }

  double _calculateSymmetryScore(MotionData motionData) {
    return _calculateBasicSymmetry(motionData);
  }

  Map<String, List<double>> _calculateJointVelocities() {
    Map<String, List<double>> velocities = {};
    if (_motionBuffer.length < 2) return velocities;

    final dt = 1.0 / 30.0; // Assuming 30fps
    final currentFrame = _motionBuffer.last;
    final previousFrame = _motionBuffer[_motionBuffer.length - 2];

    currentFrame.joints.forEach((jointName, currentJoint) {
      final previousJoint = previousFrame.joints[jointName];
      if (previousJoint != null) {
        velocities[jointName] = [
          (currentJoint.x - previousJoint.x) / dt,
          (currentJoint.y - previousJoint.y) / dt,
          (currentJoint.z - previousJoint.z) / dt,
        ];
      }
    });

    return velocities;
  }

  Map<String, List<double>> _calculateJointAccelerations() {
    Map<String, List<double>> accelerations = {};
    if (_motionBuffer.length < 3) return accelerations;

    final dt = 1.0 / 30.0;
    final currentVelocities = _calculateJointVelocities();
    
    // Calculate previous velocities
    final previousBuffer = List<MotionData>.from(_motionBuffer)..removeLast();
    final previousVelocities = _calculateJointVelocities();

    currentVelocities.forEach((jointName, currentVel) {
      final previousVel = previousVelocities[jointName];
      if (previousVel != null) {
        accelerations[jointName] = [
          (currentVel[0] - previousVel[0]) / dt,
          (currentVel[1] - previousVel[1]) / dt,
          (currentVel[2] - previousVel[2]) / dt,
        ];
      }
    });

    return accelerations;
  }

  Map<String, dynamic> _analyzeMovementPatterns() {
    if (_motionBuffer.length < _bufferSize) return {};

    // Detect movement phases
    final phases = _detectMovementPhases();
    
    // Analyze rhythm and timing
    final timing = _analyzeMovementTiming(phases);
    
    // Detect technique flaws
    final flaws = _detectTechniqueFlaws(phases);

    return {
      'phases': phases,
      'timing': timing,
      'flaws': flaws,
      'consistency': _calculateMovementConsistency(),
    };
  }

  Map<String, String> _detectMovementPhases() {
    // Implement phase detection logic based on joint velocities and positions
    return {};
  }

  Map<String, double> _analyzeMovementTiming(Map<String, String> phases) {
    // Analyze timing between movement phases
    return {};
  }

  List<String> _detectTechniqueFlaws(Map<String, String> phases) {
    // Detect common technique flaws based on joint angles and movement patterns
    return [];
  }

  double _calculateMovementConsistency() {
    if (_motionBuffer.length < _bufferSize) return 0.0;

    // Calculate variance in joint trajectories
    double totalVariance = 0.0;
    int measurements = 0;

    _motionBuffer.first.joints.forEach((jointName, _) {
      List<double> xPositions = [];
      List<double> yPositions = [];
      List<double> zPositions = [];

      for (var frame in _motionBuffer) {
        final joint = frame.joints[jointName];
        if (joint != null) {
          xPositions.add(joint.x);
          yPositions.add(joint.y);
          zPositions.add(joint.z);
        }
      }

      totalVariance += _calculateVariance(xPositions);
      totalVariance += _calculateVariance(yPositions);
      totalVariance += _calculateVariance(zPositions);
      measurements += 3;
    });

    return measurements > 0 ? 1.0 - (totalVariance / measurements).clamp(0.0, 1.0) : 0.0;
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  Map<String, double> _calculateJointLoads(Map<String, List<double>> accelerations) {
    // Calculate estimated forces on each joint based on accelerations
    Map<String, double> loads = {};
    
    accelerations.forEach((jointName, accel) {
      // Simplified force calculation (F = ma)
      final magnitude = math.sqrt(math.pow(accel[0], 2) + math.pow(accel[1], 2) + math.pow(accel[2], 2));
      loads[jointName] = magnitude * 1.0; // Assuming unit mass for relative comparison
    });

    return loads;
  }

  double _calculateEnergyExpenditure(
    Map<String, List<double>> velocities,
    Map<String, List<double>> accelerations,
  ) {
    // Calculate estimated energy expenditure based on work done
    double totalEnergy = 0.0;
    
    velocities.forEach((jointName, vel) {
      final accel = accelerations[jointName];
      if (accel != null) {
        // E = ½mv² + mgh (kinetic + potential energy)
        final kineticEnergy = 0.5 * (math.pow(vel[0], 2) + math.pow(vel[1], 2) + math.pow(vel[2], 2));
        final potentialEnergy = 9.81 * vel[1]; // g * height (y component)
        totalEnergy += kineticEnergy + potentialEnergy;
      }
    });

    return totalEnergy;
  }

  double _calculateMovementEfficiency(double energy, double technique) {
    // Higher technique score and lower energy expenditure = better efficiency
    if (energy <= 0) return 0.0;
    return (technique / energy).clamp(0.0, 1.0);
  }

  double _analyzeTechniqueQuality(Map<String, dynamic> patterns) {
    if (patterns.isEmpty) return 0.0;

    // Analyze technique based on movement patterns
    double score = 0.0;
    int factors = 0;

    // Check movement consistency
    if (patterns.containsKey('consistency')) {
      score += patterns['consistency'] as double;
      factors++;
    }

    // Check for technique flaws
    if (patterns.containsKey('flaws')) {
      final flaws = patterns['flaws'] as List<String>;
      score += 1.0 - (flaws.length / 10).clamp(0.0, 1.0); // Normalize flaw count
      factors++;
    }

    // Check movement timing
    if (patterns.containsKey('timing')) {
      final timing = patterns['timing'] as Map<String, double>;
      if (timing.isNotEmpty) {
        score += timing.values.reduce((a, b) => a + b) / timing.length;
        factors++;
      }
    }

    return factors > 0 ? score / factors : 0.0;
  }

  Future<MotionData?> processVideoFrame(mlkit.InputImage image) async {
    if (_isProcessing || _poseDetector == null) return null;
    
    try {
      _isProcessing = true;
      final List<mlkit.Pose> poses = await _poseDetector!.processImage(image);
      _isProcessing = false;
      
      if (poses.isEmpty) return null;

      final pose = poses.first;
      Map<String, JointPosition> joints = {};
      List<Point3D> jointPositions = [];
      List<double> jointAngles = [];

      // Extract only essential joints for performance
      final essentialJoints = {
        mlkit.PoseLandmarkType.leftShoulder,
        mlkit.PoseLandmarkType.rightShoulder,
        mlkit.PoseLandmarkType.leftElbow,
        mlkit.PoseLandmarkType.rightElbow,
        mlkit.PoseLandmarkType.leftHip,
        mlkit.PoseLandmarkType.rightHip,
        mlkit.PoseLandmarkType.leftKnee,
        mlkit.PoseLandmarkType.rightKnee,
      };

      for (var type in essentialJoints) {
        if (pose.landmarks.containsKey(type)) {
          final landmark = pose.landmarks[type]!;
          final jointName = type.toString().split('.').last;
          joints[jointName] = JointPosition(
            x: landmark.x,
            y: landmark.y,
            z: landmark.z,
            confidence: landmark.likelihood,
          );

          jointPositions.add(Point3D(
            x: landmark.x,
            y: landmark.y,
            z: landmark.z,
          ));
        }
      }

      // Calculate essential angles
      if (pose.landmarks.containsKey(mlkit.PoseLandmarkType.leftElbow)) {
        jointAngles.add(_calculateAngleBetweenVectors(
          [pose.landmarks[mlkit.PoseLandmarkType.leftShoulder]!.x - pose.landmarks[mlkit.PoseLandmarkType.leftElbow]!.x,
           pose.landmarks[mlkit.PoseLandmarkType.leftShoulder]!.y - pose.landmarks[mlkit.PoseLandmarkType.leftElbow]!.y],
          [pose.landmarks[mlkit.PoseLandmarkType.leftWrist]!.x - pose.landmarks[mlkit.PoseLandmarkType.leftElbow]!.x,
           pose.landmarks[mlkit.PoseLandmarkType.leftWrist]!.y - pose.landmarks[mlkit.PoseLandmarkType.leftElbow]!.y],
        ));
      }

      if (pose.landmarks.containsKey(mlkit.PoseLandmarkType.leftKnee)) {
        jointAngles.add(_calculateAngleBetweenVectors(
          [pose.landmarks[mlkit.PoseLandmarkType.leftHip]!.x - pose.landmarks[mlkit.PoseLandmarkType.leftKnee]!.x,
           pose.landmarks[mlkit.PoseLandmarkType.leftHip]!.y - pose.landmarks[mlkit.PoseLandmarkType.leftKnee]!.y],
          [pose.landmarks[mlkit.PoseLandmarkType.leftAnkle]!.x - pose.landmarks[mlkit.PoseLandmarkType.leftKnee]!.x,
           pose.landmarks[mlkit.PoseLandmarkType.leftAnkle]!.y - pose.landmarks[mlkit.PoseLandmarkType.leftKnee]!.y],
        ));
      }

      return MotionData(
        joints: joints,
        jointPositions: jointPositions,
        jointAngles: jointAngles,
        timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
      );
    } catch (e) {
      print('Error processing video frame: $e');
      _isProcessing = false;
      return null;
    }
  }

  double _calculateAngleBetweenVectors(List<double> v1, List<double> v2) {
    final dotProduct = v1[0] * v2[0] + v1[1] * v2[1];
    final magnitude1 = math.sqrt(math.pow(v1[0], 2) + math.pow(v1[1], 2));
    final magnitude2 = math.sqrt(math.pow(v2[0], 2) + math.pow(v2[1], 2));
    
    final cosAngle = dotProduct / (magnitude1 * magnitude2);
    return math.acos(cosAngle.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  Map<String, dynamic> calculateBasicMetrics(MotionData motionData) {
    return {
      'symmetryScore': _calculateBasicSymmetry(motionData),
      'stabilityScore': _calculateBasicStability(motionData),
    };
  }

  double _calculateBasicSymmetry(MotionData motionData) {
    if (motionData.joints.isEmpty) return 0.0;
    
    double symmetryScore = 0.0;
    int comparisons = 0;
    
    final pairs = {
      'Shoulder': ['leftShoulder', 'rightShoulder'],
      'Hip': ['leftHip', 'rightHip'],
      'Knee': ['leftKnee', 'rightKnee'],
    };
    
    pairs.forEach((_, pair) {
      final left = motionData.joints[pair[0]];
      final right = motionData.joints[pair[1]];
      
      if (left != null && right != null) {
        symmetryScore += 1.0 - (left.y - right.y).abs() / 100;
        comparisons++;
      }
    });
    
    return comparisons > 0 ? symmetryScore / comparisons : 0.0;
  }

  double _calculateBasicStability(MotionData motionData) {
    if (motionData.joints.isEmpty) return 0.0;
    
    final coreJoints = ['leftHip', 'rightHip'];
    double totalMovement = 0.0;
    int validJoints = 0;
    
    for (var joint in coreJoints) {
      if (motionData.joints.containsKey(joint)) {
        final pos = motionData.joints[joint]!;
        totalMovement += math.sqrt(pos.x * pos.x + pos.y * pos.y);
        validJoints++;
      }
    }
    
    return validJoints > 0 ? math.max(0.0, 1.0 - (totalMovement / (validJoints * 100))) : 0.0;
  }

  Future<void> savePerformanceData({
    required String athleteId,
    required Map<String, double> metrics,
    String? sportType,
    double? score,
  }) async {
    try {
      await _firestore.collection('performance_metrics').add({
        'athleteId': athleteId,
        'timestamp': FieldValue.serverTimestamp(),
        'metrics': metrics,
        'sportType': sportType,
        'score': score,
      });
    } catch (e) {
      print('Error saving performance data: $e');
    }
  }

  Future<List<PerformanceData>> getAthletePerformanceData(
    String athleteId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('athletePerformanceAnalysis')
          .where('athleteId', isEqualTo: athleteId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
          .where('timestamp', isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PerformanceData(
          id: doc.id,
          athleteId: data['athleteId'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
          metrics: Map<String, double>.from(data['metrics'] as Map),
          motionData: data['motionData'] != null
              ? MotionData.fromJson(data['motionData'] as Map<String, dynamic>)
              : null,
        );
      }).toList();
    } catch (e) {
      print('Error getting athlete performance data: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _metricsStreamController?.close();
    _poseDetector?.close();
  }

  Map<String, dynamic> calculateJointMetrics(MotionData motionData) {
    try {
      double symmetryScore = 0.0;
      double stabilityScore = 0.0;
      double rangeOfMotionScore = 0.0;

      // Calculate symmetry score
      final leftSide = ['leftShoulder', 'leftElbow', 'leftWrist', 'leftHip', 'leftKnee', 'leftAnkle'];
      final rightSide = ['rightShoulder', 'rightElbow', 'rightWrist', 'rightHip', 'rightKnee', 'rightAnkle'];

      for (int i = 0; i < leftSide.length; i++) {
        final leftJoint = motionData.joints[leftSide[i]];
        final rightJoint = motionData.joints[rightSide[i]];

        if (leftJoint != null && rightJoint != null) {
          final yDiff = (leftJoint.y - rightJoint.y).abs();
          symmetryScore += 1.0 - (yDiff / 2.0); // Normalize to 0-1 range
        }
      }
      symmetryScore /= leftSide.length;

      // Calculate stability score
      final keyJoints = ['nose', 'leftShoulder', 'rightShoulder', 'leftHip', 'rightHip'];
      for (final joint in keyJoints) {
        final position = motionData.joints[joint];
        if (position != null) {
          stabilityScore += position.confidence;
        }
      }
      stabilityScore /= keyJoints.length;

      // Calculate range of motion score
      if (motionData.jointAngles.isNotEmpty) {
        final maxAngle = motionData.jointAngles.reduce((a, b) => math.max(a, b));
        final minAngle = motionData.jointAngles.reduce((a, b) => math.min(a, b));
        rangeOfMotionScore = (maxAngle - minAngle) / 180.0; // Normalize to 0-1 range
      }

      return {
        'symmetryScore': symmetryScore,
        'stabilityScore': stabilityScore,
        'rangeOfMotionScore': rangeOfMotionScore,
      };
    } catch (e) {
      print('Error calculating joint metrics: $e');
      return {
        'symmetryScore': 0.0,
        'stabilityScore': 0.0,
        'rangeOfMotionScore': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> calculatePerformanceTrends(
    String athleteId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final performanceData = await getAthletePerformanceData(
        athleteId,
        startDate,
        endDate,
      );

      if (performanceData.isEmpty) {
        return {
          'posture': 0.0,
          'symmetry': 0.0,
          'smoothness': 0.0,
          'range_of_motion': 0.0,
        };
      }

      // Calculate average metrics
      final metrics = performanceData.fold<Map<String, double>>(
        {},
        (map, data) {
          data.metrics.forEach((key, value) {
            map[key] = (map[key] ?? 0.0) + value;
          });
          return map;
        },
      );

      metrics.forEach((key, value) {
        metrics[key] = value / performanceData.length;
      });

      return metrics;
    } catch (e) {
      print('Error calculating performance trends: $e');
      return {
        'posture': 0.0,
        'symmetry': 0.0,
        'smoothness': 0.0,
        'range_of_motion': 0.0,
      };
    }
  }

  Future<PerformanceSession> startTrainingSession({
    required String athleteId,
    required String sportType,
    String? trainingArea,
  }) async {
    try {
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final session = PerformanceSession(
        sessionId: sessionId,
        athleteId: athleteId,
        sportType: sportType,
        startTime: DateTime.now(),
        status: 'active',
      );

      await _firestore
          .collection('athletePerformanceAnalysis')
          .doc(sessionId)
          .set(session.toJson());

      return session;
    } catch (e) {
      print('Error starting training session: $e');
      throw Exception('Failed to start training session');
    }
  }

  Future<void> finalizeSession(String sessionId) async {
    try {
      await _firestore
          .collection('athletePerformanceAnalysis')
          .doc(sessionId)
          .update({
        'status': 'completed',
        'endTime': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error finalizing session: $e');
      throw Exception('Failed to finalize session');
    }
  }

  // Add new analysis methods
  Future<Map<String, dynamic>> analyzeTechnique(List<mlkit.PoseLandmark> pose) async {
    if (pose.isEmpty) return {};

    return {
      'posture_score': _analyzePosture(pose),
      'symmetry_score': _analyzeSymmetry(pose),
      'movement_smoothness': _analyzeMovementSmoothness(),
      'range_of_motion': _analyzeRangeOfMotion(pose),
      'recommendations': await _generateRecommendations(pose),
    };
  }

  double _analyzePosture(List<mlkit.PoseLandmark> pose) {
    // Analyze spine alignment and key joint angles
    double spineAlignment = _calculateSpineAlignment(pose);
    double shoulderAlignment = _calculateShoulderAlignment(pose);
    double hipAlignment = _calculateHipAlignment(pose);
    
    return (spineAlignment + shoulderAlignment + hipAlignment) / 3.0;
  }

  double _analyzeSymmetry(List<mlkit.PoseLandmark> pose) {
    // Compare left and right side movements
    double armSymmetry = _compareLeftRightArms(pose);
    double legSymmetry = _compareLeftRightLegs(pose);
    
    return (armSymmetry + legSymmetry) / 2.0;
  }

  double _analyzeMovementSmoothness() {
    if (_poseHistory.length < 2) return 0.0;
    
    // Calculate jerk (rate of change of acceleration)
    double totalJerk = 0.0;
    for (int i = 2; i < _poseHistory.length; i++) {
      totalJerk += _calculateJerkBetweenFrames(
        _poseHistory[i-2], 
        _poseHistory[i-1], 
        _poseHistory[i]
      );
    }
    
    return _normalizeJerkScore(totalJerk);
  }

  double _analyzeRangeOfMotion(List<mlkit.PoseLandmark> pose) {
    // Calculate key joint angles and compare to ideal ranges
    Map<String, double> jointAngles = _calculateJointAngles(pose);
    return _scoreRangeOfMotion(jointAngles);
  }

  Future<List<String>> _generateRecommendations(List<mlkit.PoseLandmark> pose) async {
    List<String> recommendations = [];
    
    // Analyze current technique
    Map<String, double> scores = {
      'posture': _analyzePosture(pose),
      'symmetry': _analyzeSymmetry(pose),
      'smoothness': _analyzeMovementSmoothness(),
      'range_of_motion': _analyzeRangeOfMotion(pose),
    };
    
    // Generate specific recommendations based on scores
    scores.forEach((metric, score) {
      if (score < 0.7) {
        recommendations.add(_getRecommendationForMetric(metric, score));
      }
    });
    
    return recommendations;
  }

  String _getRecommendationForMetric(String metric, double score) {
    switch (metric) {
      case 'posture':
        return 'Focus on maintaining a straight spine and aligned shoulders';
      case 'symmetry':
        return 'Work on balancing effort between left and right sides';
      case 'smoothness':
        return 'Try to make movements more fluid and controlled';
      case 'range_of_motion':
        return 'Increase flexibility through proper stretching';
      default:
        return 'Continue practicing with proper form';
    }
  }

  // Helper methods for calculations
  double _calculateSpineAlignment(List<mlkit.PoseLandmark> pose) {
    // Calculate angle between shoulders and hips
    // Return normalized score (0-1)
    return 0.8; // Placeholder - implement actual calculation
  }

  double _calculateShoulderAlignment(List<mlkit.PoseLandmark> pose) {
    // Compare shoulder heights and angles
    return 0.8; // Placeholder - implement actual calculation
  }

  double _calculateHipAlignment(List<mlkit.PoseLandmark> pose) {
    // Compare hip positions and angles
    return 0.8; // Placeholder - implement actual calculation
  }

  // Add new methods for session management
  Future<TrainingSession> startNewTrainingSession({
    required String athleteId,
    required String sportType,
    required String trainingArea,
  }) async {
    final session = TrainingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      athleteId: athleteId,
      sportType: sportType,
      startTime: DateTime.now(),
      athleteIds: [athleteId],
      settings: {'trainingArea': trainingArea},
    );
    
    _activeSessions[session.sessionId] = session;
    return session;
  }

  Future<bool> _verifyCoachAthleteRelationship(String coachId, String athleteId) async {
    final snapshot = await _firestore
        .collection('coach_athletes')
        .where('coach_id', isEqualTo: coachId)
        .where('athlete_id', isEqualTo: athleteId)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }

  // Enhanced athlete detection and tracking
  Future<Map<String, dynamic>> processFrameWithAthleteIdentification(
    mlkit.InputImage image,
    String sessionId,
  ) async {
    if (_poseDetector == null) return {};
    
    try {
      final List<mlkit.Pose> poses = await _poseDetector!.processImage(image);
      if (poses.isEmpty) return {};

      final session = _activeSessions[sessionId];
      if (session == null) return {};

      // Process the pose data
      final motionData = _convertPoseToMotionData(poses.first);
      final metrics = await analyzeTechnique(poses.first.landmarks.values.toList());
      
      return {
        'motion_data': motionData,
        'metrics': metrics,
        'multiple_athletes': poses.length > 1,
      };
    } catch (e) {
      print('Error processing frame: $e');
      return {};
    }
  }

  MotionData _convertPoseToMotionData(mlkit.Pose pose) {
    final joints = <String, JointPosition>{};
    final positions = <Point3D>[];
    final angles = <double>[];

    pose.landmarks.forEach((type, landmark) {
      if (landmark.likelihood > 0.5) {
        final point = Point3D(
          x: landmark.x,
          y: landmark.y,
          z: landmark.z ?? 0.0,
        );

        final jointPosition = JointPosition(
          x: landmark.x,
          y: landmark.y,
          z: landmark.z ?? 0.0,
          confidence: landmark.likelihood,
        );

        joints[type.name] = jointPosition;
        positions.add(point);
      }
    });

    return MotionData(
      joints: joints,
      jointPositions: positions,
      jointAngles: angles,
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
  }

  Future<List<JerseyData>> _detectJerseyNumbers(mlkit.InputImage image) async {
    List<JerseyData> jerseyData = [];
    
    try {
      // Use regex to detect numbers in the image
      final boundingBox = Rect.fromLTWH(0, 0, image.metadata?.size.width ?? 0, image.metadata?.size.height ?? 0);
      
      jerseyData.add(JerseyData(
        number: "0", // Default number
        region: boundingBox,
        confidence: 1.0,
        boundingBox: boundingBox,
      ));
    } catch (e) {
      print('Error detecting jersey numbers: $e');
    }
    
    return jerseyData;
  }

  Future<MatchSummary> generateMatchSummary(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) throw Exception('No active session found');

    // Calculate all metrics
    final metrics = await _calculateSessionMetrics(session);
    
    // Generate time series data
    final timeSeriesData = _generateTimeSeriesData(session);
    
    // Analyze performance highlights
    final highlights = await _analyzePerformanceHighlights(
      session,
      metrics,
      timeSeriesData,
    );
    
    // Get competition results
    final competitionResults = await _getCompetitionResults(session);
    
    final summary = MatchSummary(
      sessionId: session.sessionId,
      athleteId: session.athleteId,
      sportType: session.sportType,
      date: session.startTime,
      metrics: metrics,
      timeSeriesData: timeSeriesData,
      highlights: highlights,
      competitionResults: competitionResults,
    );
    
    // Store summary in Firestore
    await _storeMatchSummary(summary);
    
    return summary;
  }

  Future<Map<String, double>> _calculateSessionMetrics(TrainingSession session) async {
    Map<String, double> metrics = {};
    
    // Get sport-specific metrics
    final sportMetrics = olympicMetrics[session.sportType] ?? olympicMetrics['general']!;
    
    // Calculate each metric
    for (var entry in sportMetrics.entries) {
      final metricName = entry.key;
      final definition = entry.value;
      
      metrics[metricName] = await _calculateMetric(
        session,
        metricName,
        definition,
      );
    }
    
    return metrics;
  }

  Future<double> _calculateMetric(
    TrainingSession session,
    String metricName,
    MetricDefinition definition,
  ) async {
    switch (metricName) {
      case 'reaction_time':
        return _calculateReactionTime(session);
      case 'power_output':
        return _calculatePowerOutput(session);
      case 'technique_score':
        return _calculateTechniqueScore(session);
      // Add more metric calculations...
      default:
        return 0.0;
    }
  }

  Map<String, List<double>> _generateTimeSeriesData(TrainingSession session) {
    Map<String, List<double>> timeSeriesData = {};
    
    // Generate time series for each relevant metric
    timeSeriesData['speed'] = _calculateSpeedOverTime(session);
    timeSeriesData['power'] = _calculatePowerOverTime(session);
    timeSeriesData['technique'] = _calculateTechniqueOverTime(session);
    
    return timeSeriesData;
  }

  Future<List<String>> _analyzePerformanceHighlights(
    TrainingSession session,
    Map<String, double> metrics,
    Map<String, List<double>> timeSeriesData,
  ) async {
    List<String> highlights = [];
    
    // Compare with Olympic standards
    final sportMetrics = olympicMetrics[session.sportType] ?? olympicMetrics['general']!;
    
    sportMetrics.forEach((name, definition) {
      final value = metrics[name];
      if (value != null) {
        final performance = definition.isLowerBetter
            ? definition.threshold / value
            : value / definition.threshold;
            
        if (performance >= 0.95) {
          highlights.add('Olympic-level ${definition.name}: ${value.toStringAsFixed(2)} ${definition.unit}');
        } else if (performance >= 0.8) {
          highlights.add('Near Olympic standard in ${definition.name}');
        }
      }
    });
    
    // Analyze peak performances
    timeSeriesData.forEach((metric, values) {
      final peak = values.reduce(math.max);
      highlights.add('Peak $metric: ${peak.toStringAsFixed(2)}');
    });
    
    // Add technique highlights
    final techniqueHighlights = _analyzeTechniqueHighlights(session);
    highlights.addAll(techniqueHighlights);
    
    return highlights;
  }

  Future<Map<String, dynamic>> _getCompetitionResults(TrainingSession session) async {
    // Get competition/match specific results
    final results = await _firestore
        .collection('competition_results')
        .where('athlete_id', isEqualTo: session.athleteId)
        .where('session_id', isEqualTo: session.sessionId)
        .get();
        
    if (results.docs.isNotEmpty) {
      return results.docs.first.data();
    }
    
    return {};
  }

  Future<void> _storeMatchSummary(MatchSummary summary) async {
    await _firestore
        .collection('match_summaries')
        .doc(summary.sessionId)
        .set(summary.toJson());
  }

  // Helper methods for metric calculations
  double _calculateReactionTime(TrainingSession session) {
    // Implementation for reaction time calculation
    return 0.0;
  }

  double _calculatePowerOutput(TrainingSession session) {
    // Calculate power output based on motion data
    return 0.0; // Placeholder implementation
  }

  double _calculateTechniqueScore(TrainingSession session) {
    // Implementation for technique score calculation
    return 0.0;
  }

  List<double> _calculateSpeedOverTime(TrainingSession session) {
    // Implementation for speed over time
    return [];
  }

  List<double> _calculatePowerOverTime(TrainingSession session) {
    // Implementation for power over time
    return [];
  }

  List<double> _calculateTechniqueOverTime(TrainingSession session) {
    // Implementation for technique over time
    return [];
  }

  List<String> _analyzeTechniqueHighlights(TrainingSession session) {
    // Implementation for technique highlights
    return [];
  }

  // Add team analysis methods
  Future<TeamAnalytics> generateTeamAnalytics(
    String teamId,
    String sportType,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get team members
    final athleteIds = await _getTeamAthletes(teamId);
    
    // Analyze each athlete's performance
    Map<String, AthletePerformance> athletePerformances = {};
    Map<String, List<double>> metricAggregates = {};
    
    for (final athleteId in athleteIds) {
      final performance = await _analyzeAthletePerformance(
        athleteId,
        sportType,
        startDate,
        endDate,
      );
      athletePerformances[athleteId] = performance;
      
      // Aggregate metrics for team averages
      performance.metrics.forEach((metric, value) {
        metricAggregates.putIfAbsent(metric, () => []).add(value);
      });
    }
    
    // Calculate team averages
    Map<String, double> teamAverages = {};
    metricAggregates.forEach((metric, values) {
      teamAverages[metric] = values.reduce((a, b) => a + b) / values.length;
    });
    
    // Identify top performers and areas for improvement
    final topPerformers = _identifyTopPerformers(athletePerformances);
    final areasForImprovement = _identifyAreasForImprovement(
      teamAverages,
      sportType,
    );
    
    return TeamAnalytics(
      teamId: teamId,
      sportType: sportType,
      athletes: athletePerformances,
      averages: teamAverages,
      topAthletes: topPerformers,
      improvements: areasForImprovement,
    );
  }

  Future<List<String>> _getTeamAthletes(String teamId) async {
    final snapshot = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .get();
    
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<AthletePerformance> _analyzeAthletePerformance(
    String athleteId,
    String sportType,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get athlete's performance data
    final performanceData = await getAthletePerformanceData(
      athleteId,
      startDate,
      endDate,
    );
    
    // Calculate metrics
    final metrics = await _calculateAthleteMetrics(
      performanceData,
      sportType,
    );
    
    // Calculate overall score
    final overallScore = _calculateOverallScore(metrics, sportType);
    
    // Identify strengths and weaknesses
    final strengths = _identifyStrengths(metrics, sportType);
    final weaknesses = _identifyWeaknesses(metrics, sportType);
    
    // Generate progress data
    final progressData = _generateProgressData(performanceData);
    
    return AthletePerformance(
      athleteId: athleteId,
      metrics: metrics,
      overallScore: overallScore,
      strengths: strengths,
      weaknesses: weaknesses,
      progressData: progressData,
    );
  }

  Future<Map<String, double>> _calculateAthleteMetrics(
    List<PerformanceData> performanceData,
    String sportType,
  ) async {
    Map<String, double> metrics = {};
    
    // Get sport-specific metrics
    final sportSpecificMetrics = sportMetrics[sportType] ?? sportMetrics['general']!;
    
    // Calculate each metric
    for (var entry in sportSpecificMetrics.entries) {
      final metricName = entry.key;
      final definition = entry.value;
      
      double value = 0.0;
      int count = 0;
      
      for (var data in performanceData) {
        if (data.metrics.containsKey(metricName)) {
          value += data.metrics[metricName]!;
          count++;
        }
      }
      
      if (count > 0) {
        metrics[metricName] = value / count;
      }
    }
    
    return metrics;
  }

  double _calculateOverallScore(Map<String, double> metrics, String sportType) {
    if (metrics.isEmpty) return 0.0;
    
    double totalScore = 0.0;
    int count = 0;
    
    final sportSpecificMetrics = sportMetrics[sportType] ?? sportMetrics['general']!;
    
    metrics.forEach((metric, value) {
      final definition = sportSpecificMetrics[metric];
      if (definition != null) {
        final normalizedScore = definition.isLowerBetter
            ? definition.threshold / value
            : value / definition.threshold;
        totalScore += normalizedScore.clamp(0.0, 1.0);
        count++;
      }
    });
    
    return count > 0 ? (totalScore / count) * 100 : 0.0;
  }

  List<String> _identifyStrengths(Map<String, double> metrics, String sportType) {
    List<String> strengths = [];
    final sportSpecificMetrics = sportMetrics[sportType] ?? sportMetrics['general']!;
    
    metrics.forEach((metric, value) {
      final definition = sportSpecificMetrics[metric];
      if (definition != null) {
        final performance = definition.isLowerBetter
            ? definition.threshold / value
            : value / definition.threshold;
            
        if (performance >= 0.9) {
          strengths.add('${definition.name} (${value.toStringAsFixed(2)} ${definition.unit})');
        }
      }
    });
    
    return strengths;
  }

  List<String> _identifyWeaknesses(Map<String, double> metrics, String sportType) {
    List<String> weaknesses = [];
    final sportSpecificMetrics = sportMetrics[sportType] ?? sportMetrics['general']!;
    
    metrics.forEach((metric, value) {
      final definition = sportSpecificMetrics[metric];
      if (definition != null) {
        final performance = definition.isLowerBetter
            ? definition.threshold / value
            : value / definition.threshold;
            
        if (performance < 0.7) {
          weaknesses.add('${definition.name} (${value.toStringAsFixed(2)} ${definition.unit})');
        }
      }
    });
    
    return weaknesses;
  }

  Map<String, List<double>> _generateProgressData(List<PerformanceData> performanceData) {
    Map<String, List<double>> progressData = {};
    
    // Sort data by timestamp
    performanceData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Generate time series for each metric
    for (var data in performanceData) {
      data.metrics.forEach((metric, value) {
        progressData.putIfAbsent(metric, () => []).add(value);
      });
    }
    
    return progressData;
  }

  List<String> _identifyTopPerformers(Map<String, AthletePerformance> performances) {
    // Sort athletes by overall score
    final sortedAthletes = performances.entries.toList()
      ..sort((a, b) => b.value.overallScore.compareTo(a.value.overallScore));
    
    // Return top 3 performers
    return sortedAthletes
        .take(3)
        .map((e) => e.key)
        .toList();
  }

  List<String> _identifyAreasForImprovement(
    Map<String, double> teamAverages,
    String sportType,
  ) {
    List<String> areas = [];
    final sportSpecificMetrics = sportMetrics[sportType] ?? sportMetrics['general']!;
    
    teamAverages.forEach((metric, value) {
      final definition = sportSpecificMetrics[metric];
      if (definition != null) {
        final performance = definition.isLowerBetter
            ? definition.threshold / value
            : value / definition.threshold;
            
        if (performance < 0.7) {
          areas.add('Team ${definition.name}: ${value.toStringAsFixed(2)} ${definition.unit}');
        }
      }
    });
    
    return areas;
  }

  double _compareLeftRightArms(List<mlkit.PoseLandmark> pose) {
    // Compare left and right arm positions and angles
    return 0.8; // Placeholder implementation
  }

  double _compareLeftRightLegs(List<mlkit.PoseLandmark> pose) {
    // Compare left and right leg positions and angles
    return 0.8; // Placeholder implementation
  }

  double _calculateJerkBetweenFrames(
    List<mlkit.PoseLandmark> frame1,
    List<mlkit.PoseLandmark> frame2,
    List<mlkit.PoseLandmark> frame3,
  ) {
    // Calculate jerk between three consecutive frames
    return 0.0; // Placeholder implementation
  }

  double _normalizeJerkScore(double totalJerk) {
    // Normalize jerk score to 0-1 range
    return 1.0 - (totalJerk / 100.0).clamp(0.0, 1.0);
  }

  Map<String, double> _calculateJointAngles(List<mlkit.PoseLandmark> pose) {
    // Calculate angles between joints
    return {}; // Placeholder implementation
  }

  double _scoreRangeOfMotion(Map<String, double> jointAngles) {
    // Score the range of motion based on joint angles
    return 0.8; // Placeholder implementation
  }
} 