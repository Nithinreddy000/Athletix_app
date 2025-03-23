import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'motion_data.dart';

class MetricDefinition {
  final String name;
  final String description;
  final String unit;
  final double threshold;
  final bool isLowerBetter;
  final Map<String, MetricDefinition>? subMetrics;

  const MetricDefinition({
    required this.name,
    required this.description,
    required this.unit,
    required this.threshold,
    required this.isLowerBetter,
    this.subMetrics,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'unit': unit,
    'threshold': threshold,
    'isLowerBetter': isLowerBetter,
    if (subMetrics != null)
      'subMetrics': subMetrics!.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class TrainingSession {
  final String id;
  final String sessionId;
  final String athleteId;
  final String sportType;
  final DateTime startTime;
  final List<String> athleteIds;
  final Map<String, dynamic> settings;
  Map<String, List<double>> metrics;
  List<MotionData> motionData;
  
  TrainingSession({
    required this.id,
    required this.sessionId,
    required this.athleteId,
    required this.sportType,
    required this.startTime,
    required this.athleteIds,
    required this.settings,
    Map<String, List<double>>? metrics,
    List<MotionData>? motionData,
  }) : 
    this.metrics = metrics ?? {},
    this.motionData = motionData ?? [];
}

class AthleteTrackingData {
  final String id;
  Point3D lastPosition;
  DateTime lastSeen;
  List<Point3D> trajectory;
  Map<String, double> metrics;
  String? jerseyNumber;
  double confidence;
  List<Point3D> positionHistory;

  AthleteTrackingData({
    required this.id,
    required this.lastPosition,
    required this.lastSeen,
    List<Point3D>? trajectory,
    Map<String, double>? metrics,
    this.jerseyNumber,
    this.confidence = 0.0,
    List<Point3D>? positionHistory,
  }) : 
    this.trajectory = trajectory ?? [],
    this.metrics = metrics ?? {},
    this.positionHistory = positionHistory ?? [];
}

class MatchSummary {
  final String sessionId;
  final String athleteId;
  final DateTime date;
  final String sportType;
  final Map<String, double> metrics;
  final List<String> highlights;
  final Map<String, List<double>> timeSeriesData;
  final Map<String, dynamic> competitionResults;

  MatchSummary({
    required this.sessionId,
    required this.athleteId,
    required this.date,
    required this.sportType,
    required this.metrics,
    required this.highlights,
    required this.timeSeriesData,
    required this.competitionResults,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'athleteId': athleteId,
    'date': date.toIso8601String(),
    'sportType': sportType,
    'metrics': metrics,
    'highlights': highlights,
    'timeSeriesData': timeSeriesData,
    'competitionResults': competitionResults,
  };
}

class TeamAnalytics {
  final String teamId;
  final String sportType;
  final Map<String, AthletePerformance> athletes;
  final Map<String, double> averages;
  final List<String> topAthletes;
  final List<String> improvements;

  TeamAnalytics({
    required this.teamId,
    required this.sportType,
    required this.athletes,
    required this.averages,
    required this.topAthletes,
    required this.improvements,
  });

  Map<String, dynamic> toJson() => {
    'teamId': teamId,
    'sportType': sportType,
    'athletes': athletes.map((k, v) => MapEntry(k, v.toJson())),
    'averages': averages,
    'topAthletes': topAthletes,
    'improvements': improvements,
  };
}

class AthletePerformance {
  final String athleteId;
  final Map<String, double> metrics;
  final List<String> strengths;
  final List<String> weaknesses;
  final double overallScore;
  final Map<String, List<double>> progressData;

  AthletePerformance({
    required this.athleteId,
    required this.metrics,
    required this.strengths,
    required this.weaknesses,
    required this.overallScore,
    required this.progressData,
  });

  Map<String, dynamic> toJson() => {
    'athleteId': athleteId,
    'metrics': metrics,
    'strengths': strengths,
    'weaknesses': weaknesses,
    'overallScore': overallScore,
    'progressData': progressData,
  };
}

class JerseyData {
  final String number;
  final Rect region;
  final double confidence;
  final Rect boundingBox;

  JerseyData({
    required this.number,
    required this.region,
    required this.confidence,
    required this.boundingBox,
  });
}

class TrackedAthlete {
  final mlkit.Pose pose;
  final String? jerseyNumber;
  final double confidence;
  final Offset position;

  TrackedAthlete({
    required this.pose,
    this.jerseyNumber,
    required this.confidence,
    required this.position,
  });
}

class PerformanceData {
  final String id;
  final String athleteId;
  final DateTime timestamp;
  final Map<String, double> metrics;
  final MotionData? motionData;

  PerformanceData({
    required this.id,
    required this.athleteId,
    required this.timestamp,
    required this.metrics,
    this.motionData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'athleteId': athleteId,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'metrics': metrics,
    'motionData': motionData?.toJson(),
  };

  factory PerformanceData.fromJson(Map<String, dynamic> json) => PerformanceData(
    id: json['id'] as String,
    athleteId: json['athleteId'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    metrics: Map<String, double>.from(json['metrics'] as Map),
    motionData: json['motionData'] != null 
        ? MotionData.fromJson(json['motionData'] as Map<String, dynamic>)
        : null,
  );
}

class PerformanceSession {
  final String sessionId;
  final String athleteId;
  final String sportType;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final Map<String, double>? stats;

  PerformanceSession({
    required this.sessionId,
    required this.athleteId,
    required this.sportType,
    required this.startTime,
    this.endTime,
    required this.status,
    this.stats,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'athleteId': athleteId,
    'sportType': sportType,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime?.millisecondsSinceEpoch,
    'status': status,
    'stats': stats,
  };

  factory PerformanceSession.fromJson(Map<String, dynamic> json) => PerformanceSession(
    sessionId: json['sessionId'] as String,
    athleteId: json['athleteId'] as String,
    sportType: json['sportType'] as String,
    startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
    endTime: json['endTime'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int)
        : null,
    status: json['status'] as String,
    stats: json['stats'] != null 
        ? Map<String, double>.from(json['stats'] as Map)
        : null,
  );
}

class PoseLandmark {
  final double x;
  final double y;
  final double z;
  final double confidence;
  final PoseLandmarkType type;

  PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
    required this.type,
  });
}

enum PoseLandmarkType {
  nose,
  leftEye,
  rightEye,
  leftEar,
  rightEar,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

enum SportType {
  cricket,
  football,
  basketball
}

class AthleteProfile {
  final String id;
  final String name;
  final String jerseyNumber;
  final SportType sportType;
  final Map<String, dynamic> sportSpecificMetrics;

  AthleteProfile({
    required this.id,
    required this.name,
    required this.jerseyNumber,
    required this.sportType,
    required this.sportSpecificMetrics,
  });

  factory AthleteProfile.fromJson(Map<String, dynamic> json) {
    return AthleteProfile(
      id: json['id'],
      name: json['name'],
      jerseyNumber: json['jerseyNumber'],
      sportType: SportType.values.firstWhere(
        (e) => e.toString() == 'SportType.${json['sportType']}'
      ),
      sportSpecificMetrics: json['sportSpecificMetrics'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'jerseyNumber': jerseyNumber,
    'sportType': sportType.toString().split('.').last,
    'sportSpecificMetrics': sportSpecificMetrics,
  };
}

class SportMetrics {
  static Map<String, dynamic> getDefaultMetrics(SportType sport) {
    switch (sport) {
      case SportType.cricket:
        return {
          'batting': {
            'strikeRate': 0.0,
            'battingForm': 0.0,
            'footwork': 0.0,
            'timing': 0.0,
            'shotSelection': 0.0,
          },
          'bowling': {
            'pace': 0.0,
            'accuracy': 0.0,
            'consistency': 0.0,
            'action': 0.0,
            'variation': 0.0,
          }
        };
      
      case SportType.football:
        return {
          'technical': {
            'passingAccuracy': 0.0,
            'ballControl': 0.0,
            'shootingPower': 0.0,
            'dribbling': 0.0,
            'firstTouch': 0.0,
          },
          'physical': {
            'sprintSpeed': 0.0,
            'stamina': 0.0,
            'agility': 0.0,
            'strength': 0.0,
            'jumpingHeight': 0.0,
          }
        };
      
      case SportType.basketball:
        return {
          'offense': {
            'shootingAccuracy': 0.0,
            'threePointAccuracy': 0.0,
            'dribbling': 0.0,
            'passing': 0.0,
            'courtVision': 0.0,
          },
          'defense': {
            'blocking': 0.0,
            'stealing': 0.0,
            'rebounding': 0.0,
            'positioning': 0.0,
            'manToMan': 0.0,
          }
        };
    }
  }
}

class PerformanceAnalysis {
  final String id;
  final String athleteId;
  final String videoUrl;
  final SportType sportType;
  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> poseData;
  final List<Map<String, dynamic>> detectedAthletes;
  final DateTime timestamp;

  PerformanceAnalysis({
    required this.id,
    required this.athleteId,
    required this.videoUrl,
    required this.sportType,
    required this.metrics,
    required this.poseData,
    required this.detectedAthletes,
    required this.timestamp,
  });

  factory PerformanceAnalysis.fromJson(Map<String, dynamic> json) {
    return PerformanceAnalysis(
      id: json['id'],
      athleteId: json['athleteId'],
      videoUrl: json['videoUrl'],
      sportType: SportType.values.firstWhere(
        (e) => e.toString() == 'SportType.${json['sportType']}'
      ),
      metrics: json['metrics'] ?? {},
      poseData: List<Map<String, dynamic>>.from(json['poseData'] ?? []),
      detectedAthletes: List<Map<String, dynamic>>.from(json['detectedAthletes'] ?? []),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'athleteId': athleteId,
    'videoUrl': videoUrl,
    'sportType': sportType.toString().split('.').last,
    'metrics': metrics,
    'poseData': poseData,
    'detectedAthletes': detectedAthletes,
    'timestamp': Timestamp.fromDate(timestamp),
  };
} 