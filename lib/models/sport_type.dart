enum SportType {
  weightlifting,
  swimming,
  running
}

extension SportTypeExtension on SportType {
  String get displayName {
    switch (this) {
      case SportType.weightlifting:
        return 'Weightlifting';
      case SportType.swimming:
        return 'Swimming';
      case SportType.running:
        return 'Running';
      default:
        return toString().split('.').last;
    }
  }
} 