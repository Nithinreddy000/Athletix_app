import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ml_algo/ml_algo.dart';
import 'package:ml_preprocessing/ml_preprocessing.dart';

class PerformanceAnalytics {
  // Core metrics based on actual pose detection data
  static Map<String, double> calculatePerformanceMetrics(List<Map<String, dynamic>> poseData) {
    if (poseData.isEmpty) return {};

    // Extract joint positions over time
    final hipPositions = poseData.map((d) => d['hip'] as Map<String, double>).toList();
    final kneePositions = poseData.map((d) => d['knee'] as Map<String, double>).toList();
    final anklePositions = poseData.map((d) => d['ankle'] as Map<String, double>).toList();
    final timestamps = poseData.map((d) => d['timestamp'] as int).toList();

    // Calculate basic movement metrics
    final verticalDisplacement = _calculateVerticalDisplacement(hipPositions);
    final movementSpeed = _calculateMovementSpeed(hipPositions, timestamps);
    final jointAngles = _calculateJointAngles(hipPositions, kneePositions, anklePositions);
    final stability = _calculatePosturalStability(hipPositions);

    return {
      'verticalRange': verticalDisplacement,
      'averageSpeed': _calculateMean(movementSpeed),
      'maxSpeed': movementSpeed.reduce(max),
      'jointConsistency': _calculateJointConsistency(jointAngles),
      'stabilityScore': stability,
    };
  }

  // Calculate vertical movement range
  static double _calculateVerticalDisplacement(List<Map<String, double>> positions) {
    if (positions.isEmpty) return 0.0;
    
    final heights = positions.map((p) => p['y']!).toList();
    return (heights.reduce(max) - heights.reduce(min)).abs();
  }

  // Calculate movement speed between frames
  static List<double> _calculateMovementSpeed(
    List<Map<String, double>> positions,
    List<int> timestamps,
  ) {
    List<double> speeds = [];
    
    for (int i = 1; i < positions.length; i++) {
      final dx = positions[i]['x']! - positions[i-1]['x']!;
      final dy = positions[i]['y']! - positions[i-1]['y']!;
      final distance = sqrt(dx * dx + dy * dy);
      final timeDiff = (timestamps[i] - timestamps[i-1]) / 1000.0; // Convert to seconds
      
      speeds.add(distance / timeDiff);
    }
    
    return speeds;
  }

  // Calculate angles between joints
  static List<List<double>> _calculateJointAngles(
    List<Map<String, double>> hips,
    List<Map<String, double>> knees,
    List<Map<String, double>> ankles,
  ) {
    List<List<double>> angles = [];
    
    for (int i = 0; i < hips.length; i++) {
      final hipKneeAngle = _calculateAngle(
        hips[i]['x']!, hips[i]['y']!,
        knees[i]['x']!, knees[i]['y']!,
      );
      
      final kneeAnkleAngle = _calculateAngle(
        knees[i]['x']!, knees[i]['y']!,
        ankles[i]['x']!, ankles[i]['y']!,
      );
      
      angles.add([hipKneeAngle, kneeAnkleAngle]);
    }
    
    return angles;
  }

  // Calculate angle between two points relative to vertical
  static double _calculateAngle(double x1, double y1, double x2, double y2) {
    return atan2(x2 - x1, y2 - y1) * 180 / pi;
  }

  // Calculate postural stability based on hip movement
  static double _calculatePosturalStability(List<Map<String, double>> hipPositions) {
    if (hipPositions.isEmpty) return 0.0;
    
    // Calculate deviation from mean position
    final meanX = _calculateMean(hipPositions.map((p) => p['x']!).toList());
    final meanY = _calculateMean(hipPositions.map((p) => p['y']!).toList());
    
    final deviations = hipPositions.map((p) {
      final dx = p['x']! - meanX;
      final dy = p['y']! - meanY;
      return sqrt(dx * dx + dy * dy);
    }).toList();
    
    // Lower deviation means better stability
    final maxDeviation = deviations.reduce(max);
    return maxDeviation > 0 ? (1.0 - _calculateMean(deviations) / maxDeviation).clamp(0.0, 1.0) : 1.0;
  }

  // Calculate consistency of joint angles over time
  static double _calculateJointConsistency(List<List<double>> angles) {
    if (angles.isEmpty) return 0.0;
    
    // Calculate standard deviation for each joint
    final deviations = List.generate(angles[0].length, (joint) {
      final jointAngles = angles.map((a) => a[joint]).toList();
      return _calculateStandardDeviation(jointAngles);
    });
    
    // Lower deviation means more consistent movement
    final maxDeviation = deviations.reduce(max);
    return maxDeviation > 0 ? (1.0 - _calculateMean(deviations) / 90.0).clamp(0.0, 1.0) : 1.0;
  }

  // Analyze specific movements based on pose data
  static Map<String, dynamic> analyzeSpecificMovement(
    List<Map<String, dynamic>> poseData,
    String movementType,
  ) {
    if (poseData.isEmpty) return {};

    final hipPositions = poseData.map((d) => d['hip'] as Map<String, double>).toList();
    final kneePositions = poseData.map((d) => d['knee'] as Map<String, double>).toList();
    final anklePositions = poseData.map((d) => d['ankle'] as Map<String, double>).toList();
    final timestamps = poseData.map((d) => d['timestamp'] as int).toList();

    switch (movementType.toLowerCase()) {
      case 'jump':
        return _analyzeJumpMetrics(hipPositions, timestamps);
      case 'squat':
        return _analyzeSquatMetrics(hipPositions, kneePositions, anklePositions);
      case 'sprint':
        return _analyzeSprintMetrics(hipPositions, timestamps);
      default:
        return {};
    }
  }

  static Map<String, dynamic> _analyzeJumpMetrics(
    List<Map<String, double>> hipPositions,
    List<int> timestamps,
  ) {
    if (hipPositions.isEmpty) return {};

    // Find jump phases based on vertical position
    final heights = hipPositions.map((p) => p['y']!).toList();
    final startHeight = heights[0];
    final maxHeight = heights.reduce(max);
    final jumpHeight = maxHeight - startHeight;

    // Find takeoff and landing points
    final takeoffIndex = heights.indexWhere((h) => h > startHeight + 0.1); // 10cm threshold
    final landingIndex = heights.lastIndexWhere((h) => h > startHeight + 0.1);
    
    // Calculate metrics
    final flightTime = (timestamps[landingIndex] - timestamps[takeoffIndex]) / 1000.0;
    final takeoffSpeed = jumpHeight / (flightTime / 2); // Basic physics: h = v0t - (1/2)gt²

    return {
      'jumpHeight': jumpHeight,
      'flightTime': flightTime,
      'takeoffSpeed': takeoffSpeed,
      'symmetry': _calculateJumpSymmetry(heights.sublist(takeoffIndex, landingIndex)),
    };
  }

  static Map<String, dynamic> _analyzeSquatMetrics(
    List<Map<String, double>> hips,
    List<Map<String, double>> knees,
    List<Map<String, double>> ankles,
  ) {
    // Calculate key angles throughout movement
    final angles = _calculateJointAngles(hips, knees, ankles);
    final kneeAngles = angles.map((a) => a[0]).toList(); // Hip-knee angle
    
    // Find lowest position (maximum knee flexion)
    final maxFlexionIndex = kneeAngles.indexOf(kneeAngles.reduce(max));
    
    return {
      'depthAngle': kneeAngles[maxFlexionIndex],
      'consistency': _calculateJointConsistency(angles),
      'stability': _calculatePosturalStability(hips),
      'symmetry': _calculateSquatSymmetry(kneeAngles),
    };
  }

  static Map<String, dynamic> _analyzeSprintMetrics(
    List<Map<String, double>> hipPositions,
    List<int> timestamps,
  ) {
    final speeds = _calculateMovementSpeed(hipPositions, timestamps);
    
    return {
      'maxSpeed': speeds.reduce(max),
      'averageSpeed': _calculateMean(speeds),
      'acceleration': _calculateAcceleration(speeds, timestamps),
      'strideConsistency': _calculateStrideConsistency(hipPositions),
    };
  }

  // Helper methods for basic statistical calculations
  static double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = _calculateMean(values);
    final squaredDiffs = values.map((v) => pow(v - mean, 2)).toList();
    return sqrt(_calculateMean(squaredDiffs));
  }

  static double _calculateJumpSymmetry(List<double> heights) {
    if (heights.isEmpty) return 0.0;
    
    final midpoint = heights.length ~/ 2;
    final ascent = heights.sublist(0, midpoint);
    final descent = heights.sublist(midpoint).reversed.toList();
    
    // Compare ascent and descent phases
    final diffs = List.generate(
      min(ascent.length, descent.length),
      (i) => (ascent[i] - descent[i]).abs(),
    );
    
    return (1.0 - _calculateMean(diffs) / heights.reduce(max)).clamp(0.0, 1.0);
  }

  static double _calculateSquatSymmetry(List<double> angles) {
    if (angles.isEmpty) return 0.0;
    
    final maxAngleIndex = angles.indexOf(angles.reduce(max));
    final descent = angles.sublist(0, maxAngleIndex);
    final ascent = angles.sublist(maxAngleIndex).reversed.toList();
    
    final diffs = List.generate(
      min(descent.length, ascent.length),
      (i) => (descent[i] - ascent[i]).abs(),
    );
    
    return (1.0 - _calculateMean(diffs) / 90.0).clamp(0.0, 1.0);
  }

  static double _calculateAcceleration(List<double> speeds, List<int> timestamps) {
    if (speeds.length < 2) return 0.0;
    
    List<double> accelerations = [];
    for (int i = 1; i < speeds.length; i++) {
      final speedDiff = speeds[i] - speeds[i - 1];
      final timeDiff = (timestamps[i] - timestamps[i - 1]) / 1000.0;
      accelerations.add(speedDiff / timeDiff);
    }
    
    return accelerations.reduce(max);
  }

  static double _calculateStrideConsistency(List<Map<String, double>> positions) {
    if (positions.length < 4) return 0.0;
    
    // Calculate vertical oscillation consistency
    final heights = positions.map((p) => p['y']!).toList();
    final peaks = _findPeaks(heights);
    
    if (peaks.isEmpty) return 0.0;
    
    // Calculate consistency of stride height
    final peakHeights = peaks.map((i) => heights[i]).toList();
    final heightDeviation = _calculateStandardDeviation(peakHeights);
    
    return (1.0 - heightDeviation / heights.reduce(max)).clamp(0.0, 1.0);
  }

  static List<int> _findPeaks(List<double> values) {
    List<int> peaks = [];
    
    for (int i = 1; i < values.length - 1; i++) {
      if (values[i] > values[i - 1] && values[i] > values[i + 1]) {
        peaks.add(i);
      }
    }
    
    return peaks;
  }

  // Core performance metrics
  static Map<String, double> calculatePerformanceMetrics(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) {
      return {
        'performanceIndex': 0.0,
        'techniqueScore': 0.0,
        'powerOutput': 0.0,
        'movementEfficiency': 0.0,
        'recoveryRate': 0.0,
        'balanceScore': 0.0,
        'consistency': 0.0,
        'fatigueIndex': 0.0,
        'explosiveness': 0.0,
        'stabilityScore': 0.0,
      };
    }

    // Calculate max values
    double maxSpeed = 0.0;
    double maxAccel = 0.0;
    double maxHeight = 0.0;
    double totalPower = 0.0;
    List<double> speedVariations = [];
    List<double> angleVariations = [];

    for (var data in sessionData) {
      final speed = data['speed'] as double;
      final accel = data['acceleration'] as double;
      final height = data['height'] as double;
      final angle = data['angle'] as double;

      maxSpeed = max(maxSpeed, speed);
      maxAccel = max(maxAccel, accel);
      maxHeight = max(maxHeight, height);
      
      // Calculate power (simplified)
      final power = speed * accel + height * 9.81;
      totalPower += power;
      
      // Track variations for consistency calculation
      if (speedVariations.isNotEmpty) {
        speedVariations.add((speed - speedVariations.last).abs());
        angleVariations.add((angle - angleVariations.last).abs());
      }
      speedVariations.add(speed);
      angleVariations.add(angle);
    }

    // Calculate derived metrics
    final avgPower = totalPower / sessionData.length;
    final consistency = _calculateConsistency(speedVariations, angleVariations);
    final efficiency = _calculateEfficiency(sessionData);
    final fatigue = _calculateFatigueIndex(sessionData);
    final technique = _calculateTechniqueScore(sessionData);
    final stability = _calculateStabilityScore(sessionData);
    final explosiveness = _calculateExplosiveness(sessionData);
    final recovery = _calculateRecoveryRate(sessionData);
    final balance = _calculateBalanceScore(sessionData);

    // Normalize all metrics to 0-1 range
    return {
      'performanceIndex': _normalizeMetric(avgPower, 0, totalPower),
      'techniqueScore': technique,
      'powerOutput': _normalizeMetric(maxAccel * maxSpeed, 0, maxAccel * maxSpeed * 1.5),
      'movementEfficiency': efficiency,
      'recoveryRate': recovery,
      'balanceScore': balance,
      'consistency': consistency,
      'fatigueIndex': fatigue,
      'explosiveness': explosiveness,
      'stabilityScore': stability,
    };
  }

  // Advanced analysis methods
  static List<Map<String, dynamic>> generateDetailedRecommendations(Map<String, double> metrics) {
    List<Map<String, dynamic>> recommendations = [];

    // Analyze technique
    if (metrics['techniqueScore']! < 0.7) {
      recommendations.add({
        'category': 'Technique',
        'priority': 'High',
        'recommendation': 'Focus on form improvement',
        'details': 'Current technique score indicates room for improvement. Consider:',
        'actions': [
          'Review movement patterns with coach',
          'Practice basic form drills',
          'Record and analyze movement sequences'
        ]
      });
    }

    // Analyze power output
    if (metrics['powerOutput']! < 0.6) {
      recommendations.add({
        'category': 'Power',
        'priority': 'High',
        'recommendation': 'Enhance explosive strength',
        'details': 'Power output below target range. Suggested focus:',
        'actions': [
          'Incorporate plyometric exercises',
          'Add explosive movement training',
          'Gradually increase intensity'
        ]
      });
    }

    // Analyze efficiency
    if (metrics['movementEfficiency']! < 0.65) {
      recommendations.add({
        'category': 'Efficiency',
        'priority': 'Medium',
        'recommendation': 'Improve movement economy',
        'details': 'Movement efficiency can be optimized. Consider:',
        'actions': [
          'Focus on smooth transitions',
          'Practice energy conservation',
          'Work on rhythm and timing'
        ]
      });
    }

    return recommendations;
  }

  // Movement pattern analysis
  static Map<String, List<double>> analyzeMovementPatterns(List<Map<String, dynamic>> sessionData) {
    // Split movement into phases
    List<double> preparationPhase = [];
    List<double> executionPhase = [];
    List<double> recoveryPhase = [];
    
    bool inPreparation = true;
    bool inExecution = false;
    
    for (var i = 0; i < sessionData.length; i++) {
      final speed = sessionData[i]['speed'] as double;
      final accel = sessionData[i]['acceleration'] as double;
      
      if (inPreparation && accel > 2.0) {
        inPreparation = false;
        inExecution = true;
      } else if (inExecution && speed < 0.5) {
        inExecution = false;
      }
      
      if (inPreparation) {
        preparationPhase.add(speed);
      } else if (inExecution) {
        executionPhase.add(speed);
      } else {
        recoveryPhase.add(speed);
      }
    }
    
    return {
      'preparationPhase': preparationPhase,
      'executionPhase': executionPhase,
      'recoveryPhase': recoveryPhase,
    };
  }

  // Specialized movement analysis
  static Map<String, dynamic> analyzeSpecificMovement(
    List<Map<String, dynamic>> sessionData,
    String movementType,
  ) {
    switch (movementType) {
      case 'jump':
        return _analyzeJump(sessionData);
      case 'sprint':
        return _analyzeSprint(sessionData);
      case 'squat':
        return _analyzeSquat(sessionData);
      default:
        return {};
    }
  }

  // Helper methods for metric calculations
  static double _calculateConsistency(List<double> speedVars, List<double> angleVars) {
    if (speedVars.isEmpty || angleVars.isEmpty) return 0.0;
    
    final speedVariance = _calculateVariance(speedVars);
    final angleVariance = _calculateVariance(angleVars);
    
    // Lower variance = higher consistency
    return 1.0 - min((speedVariance + angleVariance) / 2, 1.0);
  }

  static double _calculateEfficiency(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return 0.0;
    
    double totalWork = 0.0;
    double totalEnergy = 0.0;
    
    for (var data in sessionData) {
      final speed = data['speed'] as double;
      final accel = data['acceleration'] as double;
      final height = data['height'] as double;
      
      // Calculate work done (simplified)
      totalWork += speed * accel * height;
      // Calculate energy expenditure (simplified)
      totalEnergy += pow(speed, 2) + pow(accel, 2) + pow(height, 2);
    }
    
    return totalWork / (totalEnergy + 1e-6);
  }

  static double _calculateFatigueIndex(List<Map<String, dynamic>> sessionData) {
    if (sessionData.length < 2) return 0.0;
    
    // Split session into quarters
    final quarterSize = sessionData.length ~/ 4;
    final firstQuarter = sessionData.sublist(0, quarterSize);
    final lastQuarter = sessionData.sublist(sessionData.length - quarterSize);
    
    // Calculate average power for each quarter
    double firstPower = 0.0;
    double lastPower = 0.0;
    
    for (var data in firstQuarter) {
      firstPower += data['speed'] as double * (data['acceleration'] as double);
    }
    for (var data in lastQuarter) {
      lastPower += data['speed'] as double * (data['acceleration'] as double);
    }
    
    firstPower /= quarterSize;
    lastPower /= quarterSize;
    
    // Calculate fatigue as power drop-off
    return min(max(0.0, (firstPower - lastPower) / firstPower), 1.0);
  }

  static double _calculateTechniqueScore(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return 0.0;
    
    double totalScore = 0.0;
    
    for (var data in sessionData) {
      final angle = data['angle'] as double;
      final speed = data['speed'] as double;
      final accel = data['acceleration'] as double;
      
      // Score based on movement smoothness and control
      final angleControl = 1.0 - min(abs(angle - 90) / 90, 1.0);
      final speedControl = 1.0 - min(abs(speed - 5) / 5, 1.0);
      final accelControl = 1.0 - min(abs(accel - 2) / 2, 1.0);
      
      totalScore += (angleControl + speedControl + accelControl) / 3;
    }
    
    return totalScore / sessionData.length;
  }

  static double _calculateStabilityScore(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return 0.0;
    
    double angleVariability = 0.0;
    List<double> angles = sessionData.map((d) => d['angle'] as double).toList();
    
    for (var i = 1; i < angles.length; i++) {
      angleVariability += (angles[i] - angles[i - 1]).abs();
    }
    
    // Lower variability = higher stability
    return 1.0 - min(angleVariability / sessionData.length / 90, 1.0);
  }

  static double _calculateExplosiveness(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return 0.0;
    
    double maxPowerSpike = 0.0;
    
    for (var i = 1; i < sessionData.length; i++) {
      final powerChange = (sessionData[i]['speed'] as double * sessionData[i]['acceleration'] as double) -
                         (sessionData[i - 1]['speed'] as double * sessionData[i - 1]['acceleration'] as double);
      maxPowerSpike = max(maxPowerSpike, powerChange);
    }
    
    return min(maxPowerSpike / 10, 1.0); // Normalize to 0-1
  }

  static double _calculateRecoveryRate(List<Map<String, dynamic>> sessionData) {
    if (sessionData.length < 3) return 0.0;
    
    List<double> recoveryRates = [];
    double peakPower = 0.0;
    int peakIndex = -1;
    
    // Find power peaks
    for (var i = 1; i < sessionData.length - 1; i++) {
      final power = sessionData[i]['speed'] as double * sessionData[i]['acceleration'] as double;
      final prevPower = sessionData[i - 1]['speed'] as double * sessionData[i - 1]['acceleration'] as double;
      final nextPower = sessionData[i + 1]['speed'] as double * sessionData[i + 1]['acceleration'] as double;
      
      if (power > prevPower && power > nextPower) {
        if (power > peakPower) {
          peakPower = power;
          peakIndex = i;
        }
      }
    }
    
    if (peakIndex > 0) {
      // Calculate recovery rate after peak
      double recoveryRate = 0.0;
      int recoveryPoints = 0;
      
      for (var i = peakIndex + 1; i < min(peakIndex + 10, sessionData.length); i++) {
        final power = sessionData[i]['speed'] as double * sessionData[i]['acceleration'] as double;
        recoveryRate += (peakPower - power) / peakPower;
        recoveryPoints++;
      }
      
      if (recoveryPoints > 0) {
        return 1.0 - min(recoveryRate / recoveryPoints, 1.0);
      }
    }
    
    return 0.0;
  }

  static double _calculateBalanceScore(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return 0.0;
    
    double totalDeviation = 0.0;
    
    for (var data in sessionData) {
      final angle = data['angle'] as double;
      // Calculate deviation from vertical (90 degrees)
      totalDeviation += (angle - 90).abs();
    }
    
    // Convert to balance score (lower deviation = higher balance)
    return 1.0 - min(totalDeviation / (sessionData.length * 90), 1.0);
  }

  // Movement-specific analysis methods
  static Map<String, dynamic> _analyzeJump(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return {};
    
    double maxHeight = 0.0;
    double takeoffVelocity = 0.0;
    double explosiveness = 0.0;
    double landingControl = 1.0;
    double symmetry = 1.0;
    
    for (var data in sessionData) {
      maxHeight = max(maxHeight, data['height'] as double);
      takeoffVelocity = max(takeoffVelocity, data['speed'] as double);
      explosiveness = max(explosiveness, data['acceleration'] as double);
    }
    
    return {
      'jumpHeight': _normalizeMetric(maxHeight, 0, 1.0),
      'takeoffVelocity': _normalizeMetric(takeoffVelocity, 0, 10.0),
      'explosiveness': _normalizeMetric(explosiveness, 0, 20.0),
      'landingControl': landingControl,
      'symmetry': symmetry,
    };
  }

  static Map<String, dynamic> _analyzeSprint(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return {};
    
    double maxSpeed = 0.0;
    double maxAccel = 0.0;
    double endurance = 1.0;
    double efficiency = 1.0;
    double frequency = 1.0;
    
    for (var data in sessionData) {
      maxSpeed = max(maxSpeed, data['speed'] as double);
      maxAccel = max(maxAccel, data['acceleration'] as double);
    }
    
    return {
      'maxSpeed': _normalizeMetric(maxSpeed, 0, 12.0),
      'accelerationRate': _normalizeMetric(maxAccel, 0, 15.0),
      'speedEndurance': endurance,
      'strideEfficiency': efficiency,
      'stepFrequency': frequency,
    };
  }

  static Map<String, dynamic> _analyzeSquat(List<Map<String, dynamic>> sessionData) {
    if (sessionData.isEmpty) return {};
    
    double maxDepth = 0.0;
    double control = 1.0;
    double power = 0.0;
    double symmetry = 1.0;
    double stability = 1.0;
    
    for (var data in sessionData) {
      maxDepth = max(maxDepth, data['angle'] as double);
      power = max(power, data['acceleration'] as double);
    }
    
    return {
      'depthAngle': _normalizeMetric(maxDepth, 0, 140.0),
      'descendingControl': control,
      'ascendingPower': _normalizeMetric(power, 0, 10.0),
      'symmetry': symmetry,
      'stabilityScore': stability,
    };
  }

  // Utility methods
  static double _normalizeMetric(double value, double min, double max) {
    return (value - min) / (max - min);
  }

  static double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }
} 