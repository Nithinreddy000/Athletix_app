import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _baseUrl = kIsWeb 
    ? '/api' // Use relative path for web
    : Config.apiBaseUrl;

  // Create a new match
  Future<String> createMatch({
    required String sport,
    required DateTime date,
    required List<String> athletes,
  }) async {
    try {
      final docRef = await _firestore.collection('matches').add({
        'sport': sport,
        'date': Timestamp.fromDate(date),
        'athletes': athletes,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create match: $e');
    }
  }

  // Upload match video
  Future<String> uploadMatchVideo(String matchId, File videoFile) async {
    try {
      final fileName = 'matches/$matchId/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(videoFile);
      final url = await ref.getDownloadURL();

      // Update match with video URL
      await _firestore.collection('matches').doc(matchId).update({
        'videoUrl': url,
        'status': 'video_uploaded',
      });

      return url;
    } catch (e) {
      throw Exception('Failed to upload match video: $e');
    }
  }

  // Process match video with AI
  Future<Map<String, dynamic>> processMatchVideo(String matchId, File videoFile, String sport) async {
    try {
      // Get coach ID (current user ID)
      final currentUser = FirebaseAuth.instance.currentUser;
      final coachId = currentUser?.uid ?? 'unknown_coach';
      
      // Create multipart request
      var uri = Uri.parse('$_baseUrl/process_match_video');
      var request = http.MultipartRequest('POST', uri);
      
      // Add fields
      request.fields['match_id'] = matchId;
      request.fields['sport_type'] = sport;
      request.fields['coach_id'] = coachId;
      
      // Add video file
      request.files.add(await http.MultipartFile.fromPath(
        'video',
        videoFile.path,
      ));
      
      print('Sending video processing request to: $_baseUrl/process_match_video');
      print('Match ID: $matchId, Sport: $sport, Coach ID: $coachId');
      
      // Send the request
      var response = await request.send();
      
      // Read response
      final responseString = await response.stream.bytesToString();
      final responseData = json.decode(responseString);
      
      print('Video processing response: $responseData');
      
      // Update match status based on response
      if (response.statusCode == 202) {
        // Successfully started processing
        await _firestore.collection('matches').doc(matchId).update({
          'status': 'processing',
          'processing_started_at': FieldValue.serverTimestamp(),
          'enhanced_processing': true, // Flag to indicate enhanced processing
        });
        
        // Show a notification to the coach
        await _firestore.collection('notifications').add({
          'user_id': coachId,
          'title': 'Video Processing Started',
          'message': 'Your match video is being processed with enhanced AI analysis. You will be notified when it\'s ready.',
          'type': 'video_processing',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'match_id': matchId,
        });
      } else {
        // Failed to start processing
        await _firestore.collection('matches').doc(matchId).update({
          'status': 'processing_failed',
          'error_message': responseData['error'] ?? 'Unknown error',
        });
      }
      
      return responseData;
    } catch (e) {
      print('Error processing match video: $e');
      // Update match with error status
      await _firestore.collection('matches').doc(matchId).update({
        'status': 'processing_failed',
        'error_message': e.toString(),
      });
      throw Exception('Failed to process match video: $e');
    }
  }
  
  // Check match processing status with enhanced information
  Future<Map<String, dynamic>> checkProcessingStatus(String matchId) async {
    try {
      print('Checking processing status for match: $matchId');
      
      // First check Firestore for the latest status
      final matchDoc = await _firestore.collection('matches').doc(matchId).get();
      
      if (!matchDoc.exists) {
        print('Match document not found: $matchId');
        return {
          'match_id': matchId,
          'status': 'error',
          'error_message': 'Match document not found'
        };
      }
      
      final matchData = matchDoc.data() ?? {};
      final status = matchData['status'] as String? ?? 'unknown';
      
      print('Match status from Firestore: $status');
      
      // If processing is already completed or failed, return Firestore data
      if (status == 'completed' || status == 'error' || status == 'processing_failed') {
        print('Match processing is already in final state: $status');
        
        // Get performance data directly from the match document
        final performanceData = matchData['performance_data'] ?? {};
        
        return {
          'match_id': matchId,
          'status': status,
          'processed_video_url': matchData['processedVideoUrl'] ?? matchData['processed_video_url'],
          'error_message': matchData['error_message'],
          'processing_time': matchData['processing_end'] != null && matchData['processing_start'] != null 
              ? (matchData['processing_end'] as Timestamp).toDate().difference(
                  (matchData['processing_start'] as Timestamp).toDate()
                ).inSeconds
              : null,
          'performances': performanceData,
          'enhanced_processing': matchData['enhanced_processing'] ?? false,
        };
      }
      
      // Try to check with the backend API, but handle connection errors gracefully
      try {
        print('Checking with backend API: $_baseUrl/match_processing_status/$matchId');
        final response = await http.get(
          Uri.parse('$_baseUrl/match_processing_status/$matchId'),
        ).timeout(Duration(seconds: 5)); // Add timeout to prevent hanging
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('Backend API response: ${response.body}');
          
          // Update Firestore if status has changed
          if (data['status'] != status) {
            print('Status changed from $status to ${data['status']}, updating Firestore');
            await _firestore.collection('matches').doc(matchId).update({
              'status': data['status'],
              'processedVideoUrl': data['processed_video_url'],
              'error_message': data['error_message'],
            });
            
            // If processing completed, send a notification
            if (data['status'] == 'completed') {
              final coachId = matchData['coach_id'] as String? ?? '';
              if (coachId.isNotEmpty) {
                await _firestore.collection('notifications').add({
                  'user_id': coachId,
                  'title': 'Video Processing Completed',
                  'message': 'Your match video has been processed and is ready to view with enhanced analytics.',
                  'type': 'video_processing_completed',
                  'read': false,
                  'timestamp': FieldValue.serverTimestamp(),
                  'match_id': matchId,
                  'video_url': data['processed_video_url'],
                });
              }
            }
          }
          
          return data;
        } else {
          print('Backend API returned error: ${response.statusCode} - ${response.body}');
          // Fall back to Firestore data
          return {
            'match_id': matchId,
            'status': status,
            'processed_video_url': matchData['processedVideoUrl'] ?? matchData['processed_video_url'],
            'error_message': 'Backend API error: ${response.statusCode}',
          };
        }
      } catch (apiError) {
        // Handle connection errors by falling back to Firestore data
        print('Error connecting to backend API: $apiError');
        
        // Return current status from Firestore without auto-completing
        return {
          'match_id': matchId,
          'status': status,
          'processed_video_url': matchData['processedVideoUrl'] ?? matchData['processed_video_url'],
          'error_message': 'Backend API unavailable: $apiError',
        };
      }
    } catch (e) {
      print('Error checking processing status: $e');
      // Return a default response instead of throwing an exception
      return {
        'match_id': matchId,
        'status': 'unknown',
        'error_message': 'Failed to check processing status: $e',
      };
    }
  }

  // Save match summary
  Future<void> saveMatchSummary(String matchId, Map<String, dynamic> summary) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'summary': summary,
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Process injury predictions based on performance and medical data
      await _processInjuryPredictions(matchId);
    } catch (e) {
      throw Exception('Failed to save match summary: $e');
    }
  }

  // Get match details
  Future<Map<String, dynamic>> getMatchDetails(String matchId) async {
    try {
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (!doc.exists) {
        throw Exception('Match not found');
      }
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get match details: $e');
    }
  }

  // Get athlete's matches
  Future<List<Map<String, dynamic>>> getAthleteMatches(String athleteId) async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('athletes', arrayContains: athleteId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to get athlete matches: $e');
    }
  }

  // Process injury predictions
  Future<void> _processInjuryPredictions(String matchId) async {
    try {
      final match = await getMatchDetails(matchId);
      final athletes = match['athletes'] as List<String>;

      for (final athleteId in athletes) {
        // Get athlete's medical records
        final medicalRecords = await _firestore
            .collection('medical_reports')
            .where('athlete_id', isEqualTo: athleteId)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        // Get athlete's recent performances
        final performances = await _firestore
            .collection('matches')
            .where('athletes', arrayContains: athleteId)
            .orderBy('date', descending: true)
            .limit(5)
            .get();

        // Analyze performance trends and medical history
        final predictions = await _analyzeInjuryRisk(
          athleteId,
          medicalRecords.docs.map((doc) => doc.data()).toList(),
          performances.docs.map((doc) => doc.data()).toList(),
        );

        // Save predictions
        await _firestore.collection('injury_predictions').add({
          'athlete_id': athleteId,
          'match_id': matchId,
          'predictions': predictions,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error processing injury predictions: $e');
    }
  }

  // Analyze injury risk based on performance and medical data
  Future<Map<String, dynamic>> _analyzeInjuryRisk(
    String athleteId,
    List<Map<String, dynamic>> medicalHistory,
    List<Map<String, dynamic>> performances,
  ) async {
    // This is a simplified risk analysis
    // In a real application, this would use more sophisticated algorithms
    
    double riskScore = 0.0;
    List<String> riskFactors = [];

    // Check recent injuries
    final recentInjuries = medicalHistory
        .where((record) => record['injuries'] != null)
        .expand((record) => (record['injuries'] as List))
        .where((injury) => injury['status'] == 'active' || injury['status'] == 'recovering')
        .toList();

    if (recentInjuries.isNotEmpty) {
      riskScore += 0.3;
      riskFactors.add('Recent injuries detected');
    }

    // Check performance decline
    if (performances.length >= 2) {
      final latestPerformance = performances[0];
      final previousPerformance = performances[1];
      
      if (_hasPerformanceDecline(latestPerformance, previousPerformance)) {
        riskScore += 0.2;
        riskFactors.add('Recent performance decline');
      }
    }

    // Check injury history patterns
    final injuryPatterns = _analyzeInjuryPatterns(medicalHistory);
    if (injuryPatterns.isNotEmpty) {
      riskScore += 0.2;
      riskFactors.addAll(injuryPatterns);
    }

    return {
      'risk_score': riskScore,
      'risk_level': _getRiskLevel(riskScore),
      'risk_factors': riskFactors,
      'recommendations': _generateRecommendations(riskScore, riskFactors),
    };
  }

  bool _hasPerformanceDecline(
    Map<String, dynamic> latest,
    Map<String, dynamic> previous,
  ) {
    // Implement performance decline detection logic
    // This would depend on the sport and metrics being tracked
    return false; // Placeholder
  }

  List<String> _analyzeInjuryPatterns(List<Map<String, dynamic>> medicalHistory) {
    // Implement injury pattern analysis
    // Look for recurring injuries or related issues
    return []; // Placeholder
  }

  String _getRiskLevel(double score) {
    if (score >= 0.7) return 'high';
    if (score >= 0.4) return 'medium';
    return 'low';
  }

  List<String> _generateRecommendations(double riskScore, List<String> factors) {
    List<String> recommendations = [];

    if (riskScore >= 0.7) {
      recommendations.add('Immediate medical evaluation recommended');
      recommendations.add('Consider reducing training intensity');
    } else if (riskScore >= 0.4) {
      recommendations.add('Monitor closely during training');
      recommendations.add('Focus on recovery and prevention');
    } else {
      recommendations.add('Continue regular training program');
      recommendations.add('Maintain preventive exercises');
    }

    // Add specific recommendations based on risk factors
    for (final factor in factors) {
      if (factor.contains('injuries')) {
        recommendations.add('Follow rehabilitation program strictly');
      }
      if (factor.contains('performance decline')) {
        recommendations.add('Review and adjust training program');
      }
    }

    return recommendations;
  }
} 