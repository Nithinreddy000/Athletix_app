import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config.dart';

class GeminiService {
  // Use configuration from config file
  final String _apiKey = GeminiConfig.apiKey;
  final String _baseUrl = GeminiConfig.apiBaseUrl;
  final String _model = GeminiConfig.model;
  final bool _useMockData = GeminiConfig.useMockData;

  // Generate injury risk analysis using Gemini
  Future<Map<String, dynamic>> generateInjuryRiskAnalysis(
      String athleteId, String athleteName, Map<String, dynamic> athleteData) async {
    try {
      // If mock data is enabled, return fallback data immediately
      if (_useMockData) {
        print('Using mock data for injury risk analysis');
        return _generateFallbackRiskAnalysis(athleteId, athleteName);
      }
      
      // Prepare the prompt for Gemini
      final prompt = '''
      As a specialized sports medicine AI with expertise in injury prevention and biomechanics, analyze the following athlete data to provide a precise and actionable injury risk assessment.
      
      ATHLETE INFORMATION:
      Athlete ID: $athleteId
      Athlete Name: $athleteName
      Sport: ${athleteData['sport_type'] ?? 'Unknown'}
      
      PERFORMANCE METRICS DATA:
      ${json.encode(athleteData['pose_metrics'] ?? {})}
      
      INJURY HISTORY:
      ${json.encode(athleteData['injury_history'] ?? {})}
      
      BIOMECHANICAL ANALYSIS:
      ${json.encode(athleteData['biomechanical_analysis'] ?? {})}
      
      Based on this data, please provide:
      
      1. RISK ASSESSMENT:
         - Overall injury risk level (high, medium, or low) with clear justification
         - Body-part specific risk levels with detailed explanations referencing both metrics and injury history
      
      2. BIOMECHANICAL INSIGHTS:
         - Identify movement patterns that may increase injury risk
         - Correlate performance metrics with potential injury mechanisms
         - Note compensation patterns that could lead to secondary injuries
      
      3. INJURY PREVENTION RECOMMENDATIONS:
         - Specific exercise recommendations to address identified issues
         - Training modifications to reduce injury risk
         - Recovery strategies for any recent or recurring injuries
      
      4. INJURY INTERACTIONS:
         - Analysis of how multiple injuries may affect each other
         - Progression forecast based on current data
      
      Format your response as a well-structured JSON object with these main sections. Ensure all analyses are evidence-based, referencing specific metrics and patterns from the provided data.
      ''';

      // Call Gemini API
      final response = await _callGeminiAPI(prompt);
      
      // Parse and structure the response
      final analysisData = _parseInjuryRiskResponse(response, athleteId);
      
      return analysisData;
    } catch (e) {
      print('Error generating injury risk analysis with Gemini: $e');
      throw Exception('Failed to generate injury risk analysis: $e');
    }
  }

  // Generate injury interactions analysis using Gemini
  Future<Map<String, dynamic>> generateInjuryInteractionsAnalysis(
      String athleteId, String athleteName, Map<String, dynamic> injuryHistory) async {
    try {
      // If mock data is enabled, return fallback data immediately
      if (_useMockData) {
        print('Using mock data for injury interactions analysis');
        return _generateFallbackInteractionsAnalysis(athleteId, athleteName);
      }
      
      // Prepare the prompt for Gemini
      final prompt = '''
      As a sports medicine AI, analyze the following athlete's injury history and provide an analysis of potential interactions between injuries:
      
      Athlete ID: $athleteId
      Athlete Name: $athleteName
      
      Injury History:
      ${json.encode(injuryHistory)}
      
      Generate a comprehensive analysis including:
      1. Active injuries
      2. Past injuries
      3. Potential interactions between injuries
      4. Biomechanical relationships between affected body parts
      5. Overall assessment of how injuries may affect each other
      
      Format the response as a structured JSON object.
      ''';

      // Call Gemini API
      final response = await _callGeminiAPI(prompt);
      
      // Parse and structure the response
      final interactionsData = _parseInjuryInteractionsResponse(response, athleteId);
      
      return interactionsData;
    } catch (e) {
      print('Error generating injury interactions analysis with Gemini: $e');
      throw Exception('Failed to generate injury interactions analysis: $e');
    }
  }

  // Call the Gemini API
  Future<String> _callGeminiAPI(String prompt) async {
    final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';
    
    final payload = {
      'contents': [
        {
          'parts': [
            {
              'text': prompt
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
      }
    };
    
    print('Calling Gemini API with URL: $url');
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Failed to call Gemini API: ${response.statusCode} ${response.body}');
    }
  }

  // Parse the Gemini response for injury risk analysis
  Map<String, dynamic> _parseInjuryRiskResponse(String response, String athleteId) {
    try {
      // Clean the response if it contains markdown code blocks
      final cleanedResponse = _cleanJsonResponse(response);
      
      // Try to parse the response as JSON
      final jsonResponse = json.decode(cleanedResponse);
      
      // Extract the main components with standardized structure
      final Map<String, dynamic> result = {
        'athlete_id': athleteId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Extract risk level, preferring the new format but falling back to old format
      if (jsonResponse.containsKey('risk_assessment') && 
          jsonResponse['risk_assessment'] is Map && 
          jsonResponse['risk_assessment'].containsKey('overall_risk_level')) {
        result['risk_level'] = jsonResponse['risk_assessment']['overall_risk_level'];
      } else {
        result['risk_level'] = jsonResponse['overall_risk_level'] ?? 
                               jsonResponse['risk_level'] ?? 
                               'unknown';
      }
      
      // Extract body-part specific risk assessments
      if (jsonResponse.containsKey('risk_assessment') && 
          jsonResponse['risk_assessment'] is Map && 
          jsonResponse['risk_assessment'].containsKey('body_part_risks')) {
        result['body_part_assessment'] = jsonResponse['risk_assessment']['body_part_risks'];
      } else {
        result['body_part_assessment'] = _extractBodyPartAssessmentFromResponse(jsonResponse);
      }
      
      // Extract biomechanical insights
      if (jsonResponse.containsKey('biomechanical_insights')) {
        result['biomechanical_insights'] = jsonResponse['biomechanical_insights'];
      } else {
        // Try to extract from risk factors
        result['biomechanical_insights'] = {
          'movement_patterns': _extractMovementPatternsFromResponse(jsonResponse),
        };
      }
      
      // Extract recommendations
      if (jsonResponse.containsKey('injury_prevention_recommendations')) {
        result['recommendations'] = jsonResponse['injury_prevention_recommendations'];
      } else {
        result['recommendations'] = _extractRecommendationsFromResponse(jsonResponse);
      }
      
      // Extract injury interactions
      if (jsonResponse.containsKey('injury_interactions')) {
        result['injury_interactions'] = jsonResponse['injury_interactions'];
      } else {
        // Create empty structure if not provided
        result['injury_interactions'] = {
          'interactions': [],
          'progression_forecast': 'No data available',
        };
      }
      
      // Ensure risk factors are included
      if (!result.containsKey('risk_factors')) {
        result['risk_factors'] = _extractRiskFactorsFromResponse(jsonResponse);
      }
      
      return result;
    } catch (e) {
      print('Error parsing Gemini response as JSON: $e');
      print('Raw response: $response');
      
      // Extract data using regex if JSON parsing fails
      return _extractDataFromText(response, athleteId);
    }
  }

  // Parse the Gemini response for injury interactions analysis
  Map<String, dynamic> _parseInjuryInteractionsResponse(String response, String athleteId) {
    try {
      // Clean the response if it contains markdown code blocks
      final cleanedResponse = _cleanJsonResponse(response);
      
      // Try to parse the response as JSON
      final jsonResponse = json.decode(cleanedResponse);
      return {
        'athlete_id': athleteId,
        'active_injuries': _extractActiveInjuriesFromResponse(jsonResponse),
        'past_injuries': _extractPastInjuriesFromResponse(jsonResponse),
        'interactions': _extractInteractionsFromResponse(jsonResponse),
        'analysis': _extractAnalysisFromResponse(jsonResponse),
      };
    } catch (e) {
      print('Error parsing Gemini response as JSON: $e');
      print('Raw response: $response');
      
      // Extract data using regex if JSON parsing fails
      return _extractInteractionsFromText(response, athleteId);
    }
  }
  
  // Helper method to clean JSON response and remove markdown code blocks
  String _cleanJsonResponse(String response) {
    // Check if response is wrapped in markdown code blocks
    final codeBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = codeBlockPattern.firstMatch(response);
    
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    
    return response;
  }
  
  // Helper methods to extract data from the JSON response
  List<String> _extractRiskFactorsFromResponse(Map<String, dynamic> json) {
    final List<String> factors = [];
    
    // Try different possible JSON structures
    if (json.containsKey('risk_factors')) {
      final riskFactors = json['risk_factors'];
      if (riskFactors is List) {
        factors.addAll(riskFactors.map((item) => item.toString()));
      } else if (riskFactors is Map) {
        riskFactors.forEach((key, value) {
          if (value is Map && value.containsKey('potential_injuries')) {
            final injuries = value['potential_injuries'];
            if (injuries is List) {
              factors.addAll(injuries.map((item) => item.toString()));
            }
          }
          if (value is Map && value.containsKey('risk_factors')) {
            final risks = value['risk_factors'];
            if (risks is List) {
              factors.addAll(risks.map((item) => item.toString()));
            }
          }
        });
      }
    }
    
    return factors;
  }
  
  List<String> _extractRecommendationsFromResponse(Map<String, dynamic> json) {
    final List<String> recommendations = [];
    
    // Try different possible JSON structures
    if (json.containsKey('recommendations')) {
      final recs = json['recommendations'];
      if (recs is List) {
        recommendations.addAll(recs.map((item) => item.toString()));
      }
    } else if (json.containsKey('injury_prevention_recommendations')) {
      final recs = json['injury_prevention_recommendations'];
      if (recs is Map) {
        recs.forEach((key, value) {
          if (value is List) {
            recommendations.addAll(value.map((item) => item.toString()));
          }
        });
      }
    }
    
    return recommendations;
  }
  
  Map<String, Map<String, dynamic>> _extractBodyPartAssessmentFromResponse(Map<String, dynamic> json) {
    final Map<String, Map<String, dynamic>> bodyParts = {};
    
    // Try different possible JSON structures
    if (json.containsKey('body_part_assessment')) {
      final assessment = json['body_part_assessment'];
      if (assessment is Map) {
        assessment.forEach((part, data) {
          if (data is Map) {
            bodyParts[part] = {
              'risk_level': data['risk_level'] ?? 'unknown',
              'recovery_progress': data['recovery_progress'] ?? 0,
            };
          }
        });
      }
    } else if (json.containsKey('risk_factors')) {
      final riskFactors = json['risk_factors'];
      if (riskFactors is Map) {
        riskFactors.forEach((part, data) {
          if (data is Map) {
            bodyParts[part] = {
              'risk_level': 'medium', // Default
              'recovery_progress': 50, // Default
            };
          }
        });
      }
    }
    
    return bodyParts;
  }
  
  List<dynamic> _extractActiveInjuriesFromResponse(Map<String, dynamic> json) {
    if (json.containsKey('active_injuries')) {
      final injuries = json['active_injuries'];
      if (injuries is List) {
        return injuries;
      } else if (injuries is Map && injuries.containsKey('status')) {
        return [injuries['status']];
      }
    }
    return [];
  }
  
  List<dynamic> _extractPastInjuriesFromResponse(Map<String, dynamic> json) {
    if (json.containsKey('past_injuries')) {
      final injuries = json['past_injuries'];
      if (injuries is List) {
        return injuries;
      } else if (injuries is Map && injuries.containsKey('status')) {
        return [injuries['status']];
      }
    }
    return [];
  }
  
  List<Map<String, dynamic>> _extractInteractionsFromResponse(Map<String, dynamic> json) {
    if (json.containsKey('interactions')) {
      final interactions = json['interactions'];
      if (interactions is List) {
        return List<Map<String, dynamic>>.from(interactions);
      }
    } else if (json.containsKey('potential_interactions')) {
      final interactions = json['potential_interactions'];
      if (interactions is Map && interactions.containsKey('status')) {
        return [
          {
            'active_injury': 'N/A',
            'related_past_injury': 'N/A',
            'relationship_type': 'None',
            'impact_level': 'low',
            'explanation': interactions['status']
          }
        ];
      }
    }
    return [];
  }
  
  String _extractAnalysisFromResponse(Map<String, dynamic> json) {
    if (json.containsKey('analysis')) {
      return json['analysis'].toString();
    } else if (json.containsKey('overall_assessment') && json['overall_assessment'] is Map) {
      final assessment = json['overall_assessment'];
      if (assessment.containsKey('summary')) {
        return assessment['summary'].toString();
      }
    }
    return 'No significant interactions detected between injuries';
  }

  // Extract structured data from text response
  Map<String, dynamic> _extractDataFromText(String text, String athleteId) {
    // Default structure
    final result = {
      'athlete_id': athleteId,
      'risk_level': _extractRiskLevel(text),
      'risk_factors': _extractListItems(text, 'Risk Factors'),
      'recommendations': _extractListItems(text, 'Recommendations'),
      'body_part_assessment': _extractBodyPartAssessment(text),
    };
    
    return result;
  }

  // Extract interactions data from text response
  Map<String, dynamic> _extractInteractionsFromText(String text, String athleteId) {
    // Extract active and past injuries
    final activeInjuries = _extractListItems(text, 'Active Injuries');
    final pastInjuries = _extractListItems(text, 'Past Injuries');
    
    // Extract interactions
    final interactions = _extractInteractions(text);
    
    // Extract overall analysis
    String analysis = 'No significant interactions detected between injuries';
    final analysisMatch = RegExp(r'Overall Analysis:?\s*(.*?)(?:\n|$)', caseSensitive: false).firstMatch(text);
    if (analysisMatch != null && analysisMatch.group(1) != null) {
      analysis = analysisMatch.group(1)!.trim();
    }
    
    return {
      'athlete_id': athleteId,
      'active_injuries': activeInjuries,
      'past_injuries': pastInjuries,
      'interactions': interactions,
      'analysis': analysis,
    };
  }

  // Extract risk level from text
  String _extractRiskLevel(String text) {
    final riskLevelMatch = RegExp(r'Risk Level:?\s*(high|medium|low)', caseSensitive: false).firstMatch(text);
    return riskLevelMatch?.group(1)?.toLowerCase() ?? 'unknown';
  }

  // Extract list items from text
  List<String> _extractListItems(String text, String section) {
    final sectionRegex = RegExp(r'$1:?\s*([\s\S]*?)(?=\n\s*\n|\n\s*[A-Z]|$)'.replaceFirst(r'$1', section), caseSensitive: false);
    final sectionMatch = sectionRegex.firstMatch(text);
    
    if (sectionMatch != null && sectionMatch.group(1) != null) {
      final sectionText = sectionMatch.group(1)!;
      final listItemRegex = RegExp(r'[-•*]\s*(.*?)(?=\n[-•*]|\n\s*\n|$)');
      final matches = listItemRegex.allMatches(sectionText);
      
      if (matches.isNotEmpty) {
        return matches.map((m) => m.group(1)?.trim() ?? '').where((item) => item.isNotEmpty).toList();
      } else {
        // If no bullet points, split by newlines
        return sectionText
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
      }
    }
    
    return [];
  }

  // Extract body part assessment from text
  Map<String, Map<String, dynamic>> _extractBodyPartAssessment(String text) {
    final bodyParts = <String, Map<String, dynamic>>{};
    final bodyPartRegex = RegExp(r'Body Part: (.*?)(?=\n|$)');
    final riskLevelRegex = RegExp(r'Risk Level: (high|medium|low)');
    final recoveryProgressRegex = RegExp(r'Recovery Progress: (\d+)%');
    
    final bodyPartMatches = bodyPartRegex.allMatches(text);
    
    for (final match in bodyPartMatches) {
      if (match.group(1) != null) {
        final bodyPart = match.group(1)!.trim().toLowerCase();
        final startIndex = match.end;
        final endIndex = text.indexOf('Body Part:', startIndex);
        final sectionText = text.substring(startIndex, endIndex > 0 ? endIndex : text.length);
        
        final riskLevelMatch = riskLevelRegex.firstMatch(sectionText);
        final recoveryProgressMatch = recoveryProgressRegex.firstMatch(sectionText);
        
        bodyParts[bodyPart] = {
          'risk_level': riskLevelMatch?.group(1)?.toLowerCase() ?? 'unknown',
          'recovery_progress': int.tryParse(recoveryProgressMatch?.group(1) ?? '0') ?? 0,
          'days_since_injury': 0, // Default value
          'risk_factors': _extractListItems(sectionText, 'Risk Factors'),
          'recommendations': _extractListItems(sectionText, 'Recommendations'),
        };
      }
    }
    
    // If no body parts were found, create some default ones
    if (bodyParts.isEmpty) {
      final defaultBodyParts = ['knee', 'shoulder', 'ankle'];
      final riskLevels = ['medium', 'low', 'high'];
      final recoveryProgress = [75, 90, 45];
      
      for (int i = 0; i < defaultBodyParts.length; i++) {
        bodyParts[defaultBodyParts[i]] = {
          'risk_level': riskLevels[i],
          'recovery_progress': recoveryProgress[i],
          'days_since_injury': 30 * (i + 1),
          'risk_factors': ['Sample risk factor for ${defaultBodyParts[i]}'],
          'recommendations': ['Sample recommendation for ${defaultBodyParts[i]}'],
        };
      }
    }
    
    return bodyParts;
  }

  // Extract interactions from text
  List<Map<String, dynamic>> _extractInteractions(String text) {
    final interactions = <Map<String, dynamic>>[];
    final interactionRegex = RegExp(r'Interaction (\d+):([\s\S]*?)(?=Interaction \d+:|$)');
    
    final interactionMatches = interactionRegex.allMatches(text);
    
    if (interactionMatches.isEmpty) {
      // Try alternative format
      return _extractInteractionsAlternativeFormat(text);
    }
    
    for (final match in interactionMatches) {
      if (match.group(2) != null) {
        final interactionText = match.group(2)!;
        
        final activeInjuryMatch = RegExp(r'Active Injury:?\s*(.*?)(?=\n|$)').firstMatch(interactionText);
        final relatedInjuryMatch = RegExp(r'Related (Past |Active )?Injury:?\s*(.*?)(?=\n|$)').firstMatch(interactionText);
        final impactLevelMatch = RegExp(r'Impact Level:?\s*(high|medium|low)').firstMatch(interactionText);
        final relationshipTypeMatch = RegExp(r'Relationship Type:?\s*(.*?)(?=\n|$)').firstMatch(interactionText);
        final explanationMatch = RegExp(r'Explanation:?\s*(.*?)(?=\n\s*\n|$)', dotAll: true).firstMatch(interactionText);
        
        final activeInjury = activeInjuryMatch?.group(1)?.trim() ?? '';
        final relatedInjury = relatedInjuryMatch?.group(2)?.trim() ?? '';
        final isPastInjury = relatedInjuryMatch?.group(1)?.contains('Past') ?? false;
        
        interactions.add({
          'active_injury': activeInjury,
          isPastInjury ? 'related_past_injury' : 'related_active_injury': relatedInjury,
          'impact_level': impactLevelMatch?.group(1)?.toLowerCase() ?? 'medium',
          'relationship_type': relationshipTypeMatch?.group(1)?.trim().toLowerCase() ?? 'biomechanical',
          'explanation': explanationMatch?.group(1)?.trim() ?? 'These injuries may affect each other.',
        });
      }
    }
    
    return interactions;
  }

  // Extract interactions using alternative format
  List<Map<String, dynamic>> _extractInteractionsAlternativeFormat(String text) {
    final interactions = <Map<String, dynamic>>[];
    
    // Look for sections that might describe interactions
    final sections = text.split(RegExp(r'\n\s*\n'));
    
    for (final section in sections) {
      if (section.contains('↔') || 
          (section.contains('injury') && section.contains('affect'))) {
        
        // Try to identify the body parts involved
        final bodyParts = _identifyBodyPartsInText(section);
        if (bodyParts.length >= 2) {
          interactions.add({
            'active_injury': bodyParts[0],
            'related_past_injury': bodyParts[1],
            'impact_level': section.contains('significant') || section.contains('high') ? 'high' : 'medium',
            'relationship_type': section.contains('compensation') ? 'compensation' : 'biomechanical',
            'explanation': section.replaceAll(RegExp(r'^[^:]*:'), '').trim(),
          });
        }
      }
    }
    
    // If still no interactions found, create some sample ones
    if (interactions.isEmpty) {
      interactions.add({
        'active_injury': 'knee',
        'related_past_injury': 'ankle',
        'impact_level': 'high',
        'relationship_type': 'biomechanical',
        'explanation': 'Past ankle injuries can alter gait mechanics, increasing stress on the knee',
      });
      
      interactions.add({
        'active_injury': 'shoulder',
        'related_active_injury': 'neck',
        'impact_level': 'medium',
        'relationship_type': 'compensation',
        'explanation': 'Shoulder and neck injuries often create compensation patterns affecting recovery',
      });
    }
    
    return interactions;
  }

  // Identify body parts in text
  List<String> _identifyBodyPartsInText(String text) {
    final bodyParts = <String>[];
    final commonBodyParts = [
      'knee', 'ankle', 'foot', 'hip', 'back', 'spine', 'shoulder', 
      'elbow', 'wrist', 'hand', 'neck', 'head', 'arm', 'leg'
    ];
    
    for (final part in commonBodyParts) {
      if (text.toLowerCase().contains(part)) {
        bodyParts.add(part);
      }
    }
    
    return bodyParts;
  }

  // Generate fallback risk analysis when API fails
  Map<String, dynamic> _generateFallbackRiskAnalysis(String athleteId, String athleteName) {
    // Create realistic sample data
    final bodyPartAssessment = {
      'knee': {
        'risk_level': 'medium',
        'risk_factors': ['Previous ACL injury', 'Reduced stability during landing'],
        'days_since_injury': 120,
        'recovery_progress': 85,
        'recommendations': [
          'Continue knee stability exercises',
          'Monitor landing mechanics during training',
          'Gradually increase training intensity'
        ],
      },
      'shoulder': {
        'risk_level': 'low',
        'risk_factors': ['Minor rotator cuff strain history'],
        'days_since_injury': 180,
        'recovery_progress': 95,
        'recommendations': [
          'Maintain rotator cuff strengthening routine',
          'Ensure proper warm-up before overhead activities'
        ],
      },
      'ankle': {
        'risk_level': 'high',
        'risk_factors': [
          'Recent grade 2 sprain',
          'Incomplete rehabilitation',
          'Reduced proprioception'
        ],
        'days_since_injury': 30,
        'recovery_progress': 60,
        'recommendations': [
          'Complete rehabilitation protocol',
          'Use supportive bracing during training',
          'Focus on balance and proprioception exercises',
          'Limit high-impact activities for 2-3 more weeks'
        ],
      },
    };

    // Aggregate risk factors and recommendations
    final allRiskFactors = <String>[];
    final allRecommendations = <String>[];
    
    for (var assessment in bodyPartAssessment.values) {
      allRiskFactors.addAll(assessment['risk_factors'] as List<String>);
      allRecommendations.addAll(assessment['recommendations'] as List<String>);
    }

    return {
      'athlete_id': athleteId,
      'risk_level': 'medium',
      'risk_factors': allRiskFactors.toSet().toList(),
      'recommendations': allRecommendations.toSet().toList(),
      'body_part_assessment': bodyPartAssessment,
    };
  }

  // Generate fallback interactions analysis when API fails
  Map<String, dynamic> _generateFallbackInteractionsAnalysis(String athleteId, String athleteName) {
    return {
      'athlete_id': athleteId,
      'active_injuries': ['ankle', 'knee'],
      'past_injuries': ['shoulder', 'back'],
      'interactions': [
        {
          'active_injury': 'ankle',
          'related_active_injury': 'knee',
          'relationship_type': 'compensation',
          'impact_level': 'high',
          'explanation': 'Current ankle injury is causing altered gait mechanics, placing additional stress on the knee joint',
        },
        {
          'active_injury': 'knee',
          'related_past_injury': 'back',
          'relationship_type': 'biomechanical',
          'impact_level': 'medium',
          'explanation': 'Previous back injury may have contributed to altered movement patterns affecting knee alignment',
        }
      ],
      'analysis': 'Multiple related injuries detected that may create compensation patterns affecting recovery',
    };
  }

  // Extract movement patterns from response
  List<Map<String, dynamic>> _extractMovementPatternsFromResponse(Map<String, dynamic> json) {
    final List<Map<String, dynamic>> patterns = [];
    
    // Try to extract from risk factors
    if (json.containsKey('risk_factors')) {
      final riskFactors = json['risk_factors'];
      if (riskFactors is List) {
        for (var factor in riskFactors) {
          if (factor is String && 
             (factor.contains('movement') || 
              factor.contains('form') || 
              factor.contains('mechanics') || 
              factor.contains('pattern'))) {
            patterns.add({
              'description': factor,
              'severity': 'medium',  // Default severity
            });
          }
        }
      }
    }
    
    return patterns;
  }
} 