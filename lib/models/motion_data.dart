class MotionData {
  final Map<String, JointPosition> joints;
  final List<Point3D> jointPositions;
  final List<double> jointAngles;
  final double timestamp;

  MotionData({
    required this.joints,
    required this.jointPositions,
    required this.jointAngles,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'joints': joints.map((key, value) => MapEntry(key, value.toJson())),
    'jointPositions': jointPositions.map((pos) => pos.toJson()).toList(),
    'jointAngles': jointAngles,
    'timestamp': timestamp,
  };

  factory MotionData.fromJson(Map<String, dynamic> json) => MotionData(
    joints: (json['joints'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, JointPosition.fromJson(value as Map<String, dynamic>)),
    ),
    jointPositions: (json['jointPositions'] as List<dynamic>)
        .map((pos) => Point3D.fromJson(pos as Map<String, dynamic>))
        .toList(),
    jointAngles: (json['jointAngles'] as List<dynamic>?)
        ?.map((angle) => (angle as num).toDouble())
        .toList() ?? [],
    timestamp: json['timestamp']?.toDouble() ?? 0.0,
  );
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

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'z': z,
    'confidence': confidence,
  };

  factory JointPosition.fromJson(Map<String, dynamic> json) => JointPosition(
    x: json['x']?.toDouble() ?? 0.0,
    y: json['y']?.toDouble() ?? 0.0,
    z: json['z']?.toDouble() ?? 0.0,
    confidence: json['confidence']?.toDouble() ?? 0.0,
  );
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

  // Add getters for dx and dy to make it compatible with Offset
  double get dx => x;
  double get dy => y;

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'z': z,
  };

  factory Point3D.fromJson(Map<String, dynamic> json) => Point3D(
    x: json['x']?.toDouble() ?? 0.0,
    y: json['y']?.toDouble() ?? 0.0,
    z: json['z']?.toDouble() ?? 0.0,
  );
} 