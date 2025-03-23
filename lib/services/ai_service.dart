import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

class AIService {
  final Dio _dio = Dio();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _baseUrl = Config.apiBaseUrl; // Use central config

  /// Analyze injury data using Gemini AI
  /// This will send the injury description to Gemini for analysis
  /// and update the recovery progress based on the AI response
  Future<Map<String, dynamic>> analyzeInjury({
    required String reportId,
    required String description,
    required String bodyPart,
    required String severity,
    String? side,
  }) async {
    try {
      print('Analyzing injury: $bodyPart - $description');
      
      // Create a request to send to the backend AI service
      final data = {
        'description': description,
        'body_part': bodyPart,
        'severity': severity,
        'side': side ?? '',
      };

      // Create a timeout for the request to ensure quick UI response
      Map<String, dynamic> fallbackResult = _calculateFallbackRecoveryProgress(severity);
      
      // Start a timer to use fallback after 3 seconds
      bool hasTimedOut = false;
      Future.delayed(const Duration(seconds: 3), () {
        hasTimedOut = true;
      });

      try {
        // Send to backend for Gemini analysis
        final response = await _dio.post(
          '$_baseUrl/analyze_injury',
          data: jsonEncode(data),
          options: Options(
            contentType: 'application/json',
            headers: {
              'Accept': 'application/json',
            },
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );

        if (response.statusCode == 200 && !hasTimedOut) {
          final analysisResult = response.data;
          print('Analysis successful: $analysisResult');
          
          // Update the recovery progress in Firestore
          await _updateInjuryData(reportId, bodyPart, side, analysisResult);
          
          return analysisResult;
        } else {
          throw Exception('Failed to analyze injury or request timed out');
        }
      } catch (e) {
        print('Error sending request to backend: $e');
        
        // If there was an error or timeout with the request, use fallback calculation
        // Also update Firestore with the fallback data
        await _updateInjuryData(reportId, bodyPart, side, fallbackResult);
        return fallbackResult;
      }
    } catch (e) {
      print('Error analyzing injury: $e');
      
      // Fallback recovery progress calculation if AI analysis fails
      final fallbackResult = _calculateFallbackRecoveryProgress(severity);
      await _updateInjuryData(reportId, bodyPart, side, fallbackResult);
      return fallbackResult;
    }
  }

  /// Update the injury data in the medical report with AI analysis results
  Future<void> _updateInjuryData(
    String reportId, 
    String bodyPart, 
    String? side,
    Map<String, dynamic> analysisResult
  ) async {
    try {
      print('Updating injury data for report $reportId, body part: $bodyPart, side: $side');
      print('Analysis result contains recovery_progress: ${analysisResult['recovery_progress']}');
      
      // Get the current report
      final docSnapshot = await _firestore
          .collection('medical_reports')
          .doc(reportId)
          .get();
      
      if (!docSnapshot.exists) {
        print('Report not found: $reportId');
        throw Exception('Report not found');
      }
      
      final data = docSnapshot.data()!;
      
      // Check if injury_data is directly in the document or nested in analysis_result
      List injuryData = [];
      bool isNested = false;
      String updateField = 'injury_data';
      
      if (data['injury_data'] != null) {
        injuryData = data['injury_data'] as List;
      } else if (data['analysis_result'] != null && 
                (data['analysis_result'] as Map<String, dynamic>).containsKey('injury_data')) {
        injuryData = (data['analysis_result'] as Map<String, dynamic>)['injury_data'] as List;
        isNested = true;
        updateField = 'analysis_result.injury_data';
      }
      
      print('Found ${injuryData.length} injuries in the report');
      
      // Find the specific injury to update
      bool foundMatch = false;
      for (int i = 0; i < injuryData.length; i++) {
        final injury = injuryData[i] as Map<String, dynamic>;
        
        // Check if this is the injury we want to update
        if (injury['bodyPart'] == bodyPart && 
            (side == null || injury['side'] == side)) {
          
          // Update with AI analysis data
          final recoveryProgress = analysisResult['recovery_progress'] ?? 
              injury['recoveryProgress'] ?? 
              0;
          
          final estimatedRecoveryTime = analysisResult['estimated_recovery_time'] ?? 
              injury['estimatedRecoveryTime'] ?? 
              'Unknown';
              
          final recommendedTreatment = analysisResult['recommended_treatment'] ?? 
              injury['recommendedTreatment'] ?? 
              '';
          
          print('Found matching injury at index $i');
          print('Updating recovery progress from ${injury['recoveryProgress'] ?? 0} to $recoveryProgress');
          
          // Update the injury data
          injuryData[i] = {
            ...injury,
            'recoveryProgress': recoveryProgress,
            'estimatedRecoveryTime': estimatedRecoveryTime,
            'recommendedTreatment': recommendedTreatment,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
          
          foundMatch = true;
          break;
        }
      }
      
      if (!foundMatch) {
        print('No matching injury found in document');
        return;
      }
      
      // Save the updated data
      try {
        if (isNested) {
          // Update the nested injury_data in analysis_result
          final Map<String, dynamic> analysisResultData = Map<String, dynamic>.from(data['analysis_result'] as Map);
          analysisResultData['injury_data'] = injuryData;
          
          await _firestore
              .collection('medical_reports')
              .doc(reportId)
              .update({
                'analysis_result': analysisResultData,
              });
        } else {
          // Update the direct injury_data field
          await _firestore
              .collection('medical_reports')
              .doc(reportId)
              .update({
                'injury_data': injuryData,
              });
        }
        
        print('Successfully updated Firestore document with new recovery progress data');
      } catch (e) {
        print('Error updating Firestore: $e');
        throw e;
      }
    } catch (e) {
      print('Error in _updateInjuryData: $e');
      throw Exception('Failed to update injury data: $e');
    }
  }

  /// Fallback method to calculate recovery progress when AI analysis fails
  Map<String, dynamic> _calculateFallbackRecoveryProgress(String severity) {
    // Extract severity level from the severity string
    final normalizedSeverity = severity.toLowerCase();
    int recoveryProgress = 0;
    String estimatedTime = "Unknown";
    
    if (normalizedSeverity.contains('mild')) {
      recoveryProgress = 50;
      estimatedTime = "2-4 weeks";
    } else if (normalizedSeverity.contains('moderate')) {
      recoveryProgress = 25;
      estimatedTime = "4-8 weeks";
    } else if (normalizedSeverity.contains('severe')) {
      recoveryProgress = 10;
      estimatedTime = "8-12 weeks";
    } else {
      // Default case
      recoveryProgress = 25;
      estimatedTime = "4-6 weeks";
    }
    
    return {
      'recovery_progress': recoveryProgress,
      'estimated_recovery_time': estimatedTime,
      'recommended_treatment': 'Please consult with a medical professional for appropriate treatment.',
    };
  }

  /// Check if an athlete has any active injuries
  Future<bool> hasActiveInjury(String athleteId) async {
    try {
      // Get all medical reports for the athlete
      final QuerySnapshot reportsSnapshot = await _firestore
          .collection('medical_reports')
          .where('athlete_id', isEqualTo: athleteId)
          .get();
      
      // Check each report for active injuries
      for (final doc in reportsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List? injuryData = data['injury_data'] as List?;
        
        if (injuryData != null && injuryData.isNotEmpty) {
          for (var injury in injuryData) {
            if (injury is Map<String, dynamic> && 
                injury['status'] == 'active') {
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking active injuries: $e');
      return false;
    }
  }

  /// Get all active injuries for an athlete
  Future<List<Map<String, dynamic>>> getActiveInjuries(String athleteId) async {
    try {
      final List<Map<String, dynamic>> activeInjuries = [];
      
      // Get all medical reports for the athlete
      final QuerySnapshot reportsSnapshot = await _firestore
          .collection('medical_reports')
          .where('athlete_id', isEqualTo: athleteId)
          .get();
      
      // Extract active injuries from all reports
      for (final doc in reportsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List? injuryData = data['injury_data'] as List?;
        
        if (injuryData != null && injuryData.isNotEmpty) {
          for (var injury in injuryData) {
            if (injury is Map<String, dynamic> && 
                injury['status'] == 'active') {
              activeInjuries.add({
                'report_id': doc.id,
                'athlete_id': data['athlete_id'],
                'athlete_name': data['athlete_name'],
                ...injury,
              });
            }
          }
        }
      }
      
      return activeInjuries;
    } catch (e) {
      print('Error getting active injuries: $e');
      return [];
    }
  }
} 