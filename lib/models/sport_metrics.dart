import 'sport_type.dart';

class SportMetrics {
  static Map<String, dynamic> getDefaultMetrics(SportType sportType) {
    switch (sportType) {
      case SportType.weightlifting:
        return {
          'form': 0.0,
          'power': 0.0,
          'technique': 0.0,
        };
      case SportType.swimming:
        return {
          'stroke': 0.0,
          'coordination': 0.0,
          'efficiency': 0.0,
        };
      case SportType.running:
        return {
          'gait': 0.0,
          'stride': 0.0,
          'posture': 0.0,
        };
      default:
        return {
          'form': 0.0,
          'technique': 0.0,
          'efficiency': 0.0,
        };
    }
  }
} 