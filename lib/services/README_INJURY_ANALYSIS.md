# Injury Analysis Service

This service provides advanced injury analysis capabilities for the Athlete Management System. It analyzes injury data from medical reports and pose detection metrics from matches to detect patterns, predict potential reinjury risks, and provide insights on how past injuries might affect current ones.

## Features

1. **Injury Risk Analysis**
   - Analyzes past injury history and current pose metrics
   - Calculates risk levels (high, medium, low) for each affected body part
   - Identifies risk factors based on recovery progress and biomechanical patterns
   - Provides tailored recommendations for each athlete

2. **Injury Interactions Analysis**
   - Detects potential interactions between past and current injuries
   - Identifies compensation patterns that may develop due to multiple injuries
   - Analyzes biomechanical relationships between different body parts
   - Provides explanations of how injuries may affect each other

3. **Coach-Specific Analysis**
   - Aggregates injury analysis for all athletes under a specific coach
   - Helps coaches prioritize attention based on injury risk levels
   - Provides team-wide insights on injury patterns

## Implementation Details

### Data Sources

The service integrates data from two main Firestore collections:

1. **medical_reports**: Contains injury records with details such as:
   - Affected body parts
   - Diagnosis information
   - Recovery progress
   - Treatment recommendations

2. **matches**: Contains pose detection metrics from performance recordings:
   - Joint angles and positions
   - Movement quality metrics
   - Stability and symmetry scores
   - Sport-specific performance indicators

### Analysis Methodology

The service employs several analytical approaches:

1. **Historical Pattern Analysis**
   - Identifies recurring injuries in the same body part
   - Calculates time between injury occurrences
   - Tracks recovery progress over time

2. **Biomechanical Relationship Mapping**
   - Maps relationships between different body parts (e.g., knee-ankle, hip-back)
   - Identifies how injuries in one area may affect others
   - Detects compensation patterns in movement

3. **Pose Metrics Evaluation**
   - Analyzes current movement patterns for warning signs
   - Compares metrics against established thresholds
   - Identifies deviations that may indicate injury risk

### Integration Points

The service is integrated into the application at these points:

1. **Performance Insights Screen**
   - Displays injury analysis in a dedicated tab
   - Shows risk levels and recommendations for the selected athlete
   - Visualizes injury interactions and patterns

2. **Coach Dashboard**
   - Provides summary of injury risks across the team
   - Highlights athletes requiring attention
   - Enables filtering and sorting based on injury status

## Usage

### Analyzing Injury Risk

```dart
final injuryAnalysisService = InjuryAnalysisService();
final riskAnalysis = await injuryAnalysisService.analyzeInjuryRisk(athleteId);

// Access risk level
final riskLevel = riskAnalysis['risk_level']; // 'high', 'medium', 'low'

// Access risk factors
final riskFactors = riskAnalysis['risk_factors']; // List of risk factors

// Access recommendations
final recommendations = riskAnalysis['recommendations']; // List of recommendations
```

### Analyzing Injury Interactions

```dart
final interactionsAnalysis = await injuryAnalysisService.analyzeInjuryInteractions(athleteId);

// Access active injuries
final activeInjuries = interactionsAnalysis['active_injuries']; // List of active injuries

// Access past injuries
final pastInjuries = interactionsAnalysis['past_injuries']; // List of past injuries

// Access interactions
final interactions = interactionsAnalysis['interactions']; // List of interaction details
```

### Getting Coach-Specific Analysis

```dart
final coachAnalysis = await injuryAnalysisService.getCoachAthleteInjuryAnalysis(coachId);

// Iterate through athletes
for (final athleteAnalysis in coachAnalysis) {
  final athleteId = athleteAnalysis['athlete_id'];
  final athleteName = athleteAnalysis['athlete_name'];
  final riskAnalysis = athleteAnalysis['risk_analysis'];
  final interactionsAnalysis = athleteAnalysis['interactions_analysis'];
  
  // Process athlete-specific analysis
}
```

## Future Enhancements

1. **Machine Learning Integration**
   - Implement predictive models for injury risk
   - Train on historical data to improve accuracy
   - Incorporate sport-specific injury patterns

2. **Real-time Monitoring**
   - Provide alerts when pose metrics indicate increased risk
   - Monitor recovery progress in real-time
   - Track adherence to rehabilitation protocols

3. **Expanded Biomechanical Analysis**
   - Add more detailed biomechanical relationships
   - Incorporate sport-specific movement patterns
   - Analyze technique variations and their impact on injury risk 