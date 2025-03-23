import 'package:cloud_firestore/cloud_firestore.dart';

class BiometricData {
  final double heartRate;
  final double oxygenLevel;
  final double stamina;
  final DateTime timestamp;

  BiometricData({
    required this.heartRate,
    required this.oxygenLevel,
    required this.stamina,
    required this.timestamp,
  });

  factory BiometricData.fromMap(Map<String, dynamic> map) {
    return BiometricData(
      heartRate: map['heartRate']?.toDouble() ?? 0.0,
      oxygenLevel: map['oxygenLevel']?.toDouble() ?? 0.0,
      stamina: map['stamina']?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heartRate': heartRate,
      'oxygenLevel': oxygenLevel,
      'stamina': stamina,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class MotionData {
  final Map<String, JointPosition> joints;
  final List<Point3D> jointPositions;
  final List<double> jointAngles;
  final double timestamp;

  MotionData({
    required this.joints,
    List<Point3D>? jointPositions,
    List<double>? jointAngles,
    required this.timestamp,
  }) : 
    this.jointPositions = jointPositions ?? [],
    this.jointAngles = jointAngles ?? [];

  Map<String, dynamic> toJson() {
    return {
      'joints': joints.map((key, value) => MapEntry(key, value.toJson())),
      'jointPositions': jointPositions.map((pos) => pos.toMap()).toList(),
      'jointAngles': jointAngles,
      'timestamp': timestamp,
    };
  }

  factory MotionData.fromJson(Map<String, dynamic> json) {
    final jointsMap = json['joints'] as Map<String, dynamic>;
    final joints = jointsMap.map(
      (key, value) => MapEntry(
        key,
        JointPosition.fromJson(value as Map<String, dynamic>),
      ),
    );

    final List<Point3D> positions = [];
    if (json['jointPositions'] != null) {
      (json['jointPositions'] as List).forEach((pos) {
        positions.add(Point3D.fromMap(pos as Map<String, dynamic>));
      });
    }

    return MotionData(
      joints: joints,
      jointPositions: positions,
      jointAngles: (json['jointAngles'] as List?)?.cast<double>() ?? [],
      timestamp: json['timestamp'] as double,
    );
  }
}

class JointPosition {
  final double x;
  final double y;
  final double z;
  final double confidence;

  JointPosition({
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
      'confidence': confidence,
    };
  }

  factory JointPosition.fromJson(Map<String, dynamic> json) {
    return JointPosition(
      x: json['x'] as double,
      y: json['y'] as double,
      z: json['z'] as double,
      confidence: json['confidence'] as double,
    );
  }
}

class Point3D {
  final double x;
  final double y;
  final double z;

  Point3D({
    required this.x,
    required this.y,
    required this.z,
  });

  factory Point3D.fromMap(Map<String, dynamic> map) {
    return Point3D(
      x: map['x']?.toDouble() ?? 0.0,
      y: map['y']?.toDouble() ?? 0.0,
      z: map['z']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'z': z,
    };
  }
}

class StatisticalData {
  final int wins;
  final int losses;
  final double accuracy;
  final double consistency;
  final DateTime timestamp;

  StatisticalData({
    required this.wins,
    required this.losses,
    required this.accuracy,
    required this.consistency,
    required this.timestamp,
  });

  factory StatisticalData.fromMap(Map<String, dynamic> map) {
    return StatisticalData(
      wins: map['wins']?.toInt() ?? 0,
      losses: map['losses']?.toInt() ?? 0,
      accuracy: map['accuracy']?.toDouble() ?? 0.0,
      consistency: map['consistency']?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wins': wins,
      'losses': losses,
      'accuracy': accuracy,
      'consistency': consistency,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class PerformanceData {
  final String id;
  final DateTime timestamp;
  final Map<String, double> metrics;
  final String? sportType;
  final double score;
  final String? outcome;

  PerformanceData({
    required this.id,
    required this.timestamp,
    required this.metrics,
    this.sportType,
    this.score = 0.0,
    this.outcome,
  });

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    return PerformanceData(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metrics: Map<String, double>.from(json['metrics'] as Map),
      sportType: json['sportType'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      outcome: json['outcome'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'metrics': metrics,
      'sportType': sportType,
      'score': score,
      'outcome': outcome,
    };
  }
} 