import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/performance_data.dart';
import 'package:flutter/material.dart';
import '../models/performance_models.dart';

class PerformanceSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _sessionSubscription;
  String? _currentSessionId;
  final String _pythonBackendUrl = 'http://10.0.2.2:8000'; // Android emulator localhost
  
  // Start a new recording session
  Future<String> startSession(String athleteId, String sportType) async {
    try {
      final coachId = _auth.currentUser?.uid;
      if (coachId == null) throw Exception('Coach not authenticated');

      // First check and cleanup any existing active sessions
      await _cleanupExistingSession(athleteId);

      // Create initial session data with required fields
      final sessionData = {
        'athleteId': athleteId,
        'coachId': coachId,
        'sportType': sportType,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'lastUpdated': FieldValue.serverTimestamp(),
        'stats': {
          'smoothness': 0.0,
          'symmetry': 0.0,
          'balance': 0.0,
          'form_score': 0.0,
        },
        'metadata': {
          'deviceInfo': 'mobile',
          'appVersion': '1.0.0',
          'sessionType': 'training',
          'analysisVersion': '2.0'
        },
      };

      // Create session document with specific ID based on timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sessionId = timestamp.toString();
      
      // Create document with specific ID
      await _firestore
          .collection('athletePerformanceAnalysis')
          .doc(sessionId)
          .set(sessionData);
      
      _currentSessionId = sessionId;
      
      // Create active session reference
      final activeSessionData = {
        'sessionId': sessionId,
        'startTime': FieldValue.serverTimestamp(),
        'athleteId': athleteId,
        'status': 'active'
      };
      
      await _firestore.collection('active_sessions').doc(athleteId).set(activeSessionData);
      
      print('Created training session document: $sessionId');
      return sessionId;

    } catch (e) {
      print('Error starting session: $e');
      if (_currentSessionId != null) {
        await _cleanupFailedSession(_currentSessionId!, athleteId);
      }
      rethrow;
    }
  }

  // Cleanup any existing active session
  Future<void> _cleanupExistingSession(String athleteId) async {
    try {
      final activeDoc = await _firestore.collection('active_sessions').doc(athleteId).get();
      if (activeDoc.exists) {
        final existingSessionId = activeDoc.data()?['sessionId'] as String?;
        if (existingSessionId != null) {
          // Update the session status to completed
          await _firestore.collection('athletePerformanceAnalysis').doc(existingSessionId).update({
            'status': 'completed',
            'endTime': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          // Delete the active session reference
          await activeDoc.reference.delete();
          
          print('Cleaned up existing session: $existingSessionId');
        }
      }
    } catch (e) {
      print('Error cleaning up existing session: $e');
    }
  }

  // Cleanup failed session creation
  Future<void> _cleanupFailedSession(String sessionId, String athleteId) async {
    try {
      await _firestore.collection('athletePerformanceAnalysis').doc(sessionId).delete();
      await _firestore.collection('active_sessions').doc(athleteId).delete();
    } catch (e) {
      print('Error cleaning up failed session: $e');
    }
  }

  // Update pose data using Python backend
  Future<Map<String, dynamic>> updatePoseData(mlkit.Pose pose, String athleteId) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        if (_currentSessionId == null) {
          print('No active session found for athlete $athleteId');
          // Create a new session if none exists
          _currentSessionId = await startSession(athleteId, 'default');
          await Future.delayed(Duration(milliseconds: 500)); // Wait for session creation
        }

        // Convert pose landmarks to JSON format
        final poseData = _convertPoseToJson(pose);
        final requestData = {
          'session_id': _currentSessionId,
          'athlete_id': athleteId,
          'pose_data': poseData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Send pose data to Python backend
        final response = await http.post(
          Uri.parse('$_pythonBackendUrl/analyze_pose'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestData),
        ).timeout(
          Duration(seconds: 60),
          onTimeout: () {
            print('Backend request timed out, attempt ${retryCount + 1} of $maxRetries');
            throw TimeoutException('Backend request timed out');
          },
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to analyze pose: ${response.body}');
        }

        final metrics = json.decode(response.body);
        
        // Check if metrics contains error
        if (metrics.containsKey('error')) {
          throw Exception(metrics['error']);
        }

        // Update Firestore with the metrics
        final docRef = _firestore
            .collection('athletePerformanceAnalysis')
            .doc(_currentSessionId);
            
        // Check if document exists first
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          print('Session document not found, creating new session');
          // Create the document if it doesn't exist
          await docRef.set({
            'athleteId': athleteId,
            'startTime': FieldValue.serverTimestamp(),
            'status': 'active',
            'stats': metrics,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Update existing document
          await docRef.update({
            'stats': metrics,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        return metrics;

      } catch (e, stackTrace) {
        print('Error updating pose data (attempt ${retryCount + 1}): $e');
        print('Stack trace: $stackTrace');
        
        // If document not found, clear session ID to create new one
        if (e.toString().contains('NOT_FOUND')) {
          _currentSessionId = null;
        }
        
        retryCount++;
        if (retryCount >= maxRetries) {
          return {
            'error': e.toString(),
            'analysis': {
              'smoothness': 0.0,
              'symmetry': 0.0,
              'balance': 0.0,
              'form_score': 0.0,
            }
          };
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return {
      'error': 'Max retries exceeded',
      'analysis': {
        'smoothness': 0.0,
        'symmetry': 0.0,
        'balance': 0.0,
        'form_score': 0.0,
      }
    };
  }

  // Convert pose to JSON format for Python backend
  Map<String, dynamic> _convertPoseToJson(mlkit.Pose pose) {
    final landmarks = <String, dynamic>{};
    
    print('Converting ${pose.landmarks.length} landmarks to JSON');
    
    pose.landmarks.forEach((type, landmark) {
      // Convert to numeric index for MediaPipe format
      final index = type.index;
      landmarks[index.toString()] = {
        'x': landmark.x,
        'y': landmark.y,
        'z': landmark.z,
        'likelihood': landmark.likelihood,
      };
      
      print('Converting landmark: ${type.name} -> $index (${landmark.x}, ${landmark.y}, ${landmark.z})');
    });
    
    return landmarks;
  }

  // Get pose connections for visualization
  List<List<String>> _getPoseConnections() {
    return [
      ['leftShoulder', 'rightShoulder'],
      ['leftShoulder', 'leftElbow'],
      ['leftElbow', 'leftWrist'],
      ['rightShoulder', 'rightElbow'],
      ['rightElbow', 'rightWrist'],
      ['leftShoulder', 'leftHip'],
      ['rightShoulder', 'rightHip'],
      ['leftHip', 'rightHip'],
      ['leftHip', 'leftKnee'],
      ['leftKnee', 'leftAnkle'],
      ['rightHip', 'rightKnee'],
      ['rightKnee', 'rightAnkle'],
    ];
  }

  // Get historical analysis from Python backend with error handling
  Future<Map<String, dynamic>> getHistoricalAnalysis(String athleteId) async {
    try {
      final response = await http.post(
        Uri.parse('$_pythonBackendUrl/historical_analysis'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'athlete_id': athleteId,
          'start_date': DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
          'end_date': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get historical analysis: ${response.body}');
      }
    } catch (e) {
      print('Error getting historical analysis: $e');
      return {
        'error': e.toString(),
        'historical_data': [],
        'trends': {
          'average_form': 0.0,
          'improvement_rate': 0.0,
          'best_session': null,
          'recent_trend': 0.0,
          'consistency': 0.0,
        }
      };
    }
  }

  // Helper method to convert pose to image
  Future<List<int>> _convertPoseToImage(mlkit.Pose pose) async {
    // This is a placeholder - implement actual conversion
    // You might want to use a Canvas to draw the pose and convert to image
    throw UnimplementedError('Need to implement pose to image conversion');
  }

  // Listen to active session
  Stream<DocumentSnapshot> listenToActiveSession(String athleteId) {
    return _firestore
        .collection('active_sessions')
        .doc(athleteId)
        .snapshots()
        .asyncMap((activeDoc) async {
          if (!activeDoc.exists) {
            return await _firestore
                .collection('athletePerformanceAnalysis')
                .doc('placeholder')
                .get(); // Return empty doc instead of throwing
          }
          final sessionId = activeDoc.get('sessionId') as String;
          final sessionDoc = await _firestore
              .collection('athletePerformanceAnalysis')
              .doc(sessionId)
              .get();
              
          if (!sessionDoc.exists) {
            // If session doesn't exist, cleanup and return empty doc
            await _cleanupExistingSession(athleteId);
            return await _firestore
                .collection('athletePerformanceAnalysis')
                .doc('placeholder')
                .get();
          }
          
          return sessionDoc;
        });
  }

  // Get previous sessions from specific collection
  Stream<QuerySnapshot> getPreviousSessions(String athleteId) {
    return _firestore
        .collection('athletePerformanceAnalysis')
        .where('athleteId', isEqualTo: athleteId)
        .where('status', isEqualTo: 'completed')
        .orderBy('startTime', descending: true)
        .limit(10) // Limit results and remove unnecessary ordering
        .snapshots();
  }

  Map<String, dynamic> _convertPoseToMap(mlkit.Pose pose) {
    final Map<String, dynamic> poseMap = {};
    
    pose.landmarks.forEach((type, landmark) {
      poseMap[type.name] = {
        'x': landmark.x,
        'y': landmark.y,
        'z': landmark.z,
        'likelihood': landmark.likelihood,
      };
    });
    
    return {
      'timestamp': FieldValue.serverTimestamp(),
      'landmarks': poseMap,
    };
  }

  Future<void> updateSessionStats(String athleteId, Map<String, dynamic> stats) async {
    try {
      await _firestore
          .collection('active_sessions')
          .doc(athleteId)
          .update({'stats': stats});
    } catch (e) {
      print('Error updating session stats: $e');
      rethrow;
    }
  }

  Future<void> saveFrame(String athleteId, Map<String, dynamic> frameData) async {
    try {
      // If no current session, try to get active session
      if (_currentSessionId == null) {
        final activeDoc = await _firestore
            .collection('active_sessions')
            .doc(athleteId)
            .get();
            
        if (!activeDoc.exists) {
          print('No active session found, creating new session');
          // Create a new session if none exists
          _currentSessionId = await startSession(athleteId, 'default');
          // Wait a bit for the session to be created
          await Future.delayed(Duration(milliseconds: 500));
        } else {
          _currentSessionId = activeDoc.get('sessionId') as String;
        }
      }
      
      // Get session document reference
      final sessionRef = _firestore
          .collection('athletePerformanceAnalysis')
          .doc(_currentSessionId);
          
      // Check if session exists
      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) {
        print('Session document not found, creating new session');
        // Create a new session with the current ID
        await sessionRef.set({
          'athleteId': athleteId,
          'startTime': FieldValue.serverTimestamp(),
          'status': 'active',
          'lastUpdated': FieldValue.serverTimestamp(),
          'stats': {
            'smoothness': 0.0,
            'symmetry': 0.0,
            'balance': 0.0,
            'form_score': 0.0,
          }
        });
        // Wait a bit for the document to be created
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      // Now save the frame
      await sessionRef
          .collection('frames')
          .add({
            ...frameData,
            'timestamp': FieldValue.serverTimestamp(),
            'athleteId': athleteId,
            'sessionId': _currentSessionId,
          });
    } catch (e) {
      print('Error saving frame: $e');
      // If we get a NOT_FOUND error, clear the current session ID so we'll create a new one next time
      if (e.toString().contains('NOT_FOUND')) {
        _currentSessionId = null;
      }
    }
  }

  Future<List<Map<String, dynamic>>> getSessionFrames(String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('athletePerformanceAnalysis')
          .doc(sessionId)
          .collection('frames')
          .orderBy('timestamp')
          .get();

      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print('Error getting session frames: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('athletePerformanceAnalysis')
          .doc(sessionId)
          .get();

      if (!doc.exists) {
        return {};
      }

      return Map<String, dynamic>.from(doc.get('stats') ?? {});
    } catch (e) {
      print('Error getting session stats: $e');
      return {};
    }
  }

  Future<void> updatePerformanceMetrics(
    String athleteId,
    Map<String, dynamic> metrics,
  ) async {
    try {
      if (_currentSessionId == null) {
        throw Exception('No active session');
      }

      await _firestore
          .collection('athletePerformanceAnalysis')
          .doc(_currentSessionId)
          .update({
            'stats': metrics,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error updating performance metrics: $e');
      rethrow;
    }
  }

  // End an active session
  Future<void> endSession(String sessionId, String athleteId) async {
    try {
      // Update the session status to completed
      await _firestore.collection('athletePerformanceAnalysis').doc(sessionId).update({
        'status': 'completed',
        'endTime': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Remove from active sessions
      await _firestore.collection('active_sessions').doc(athleteId).delete();
      
      // Clear current session
      _currentSessionId = null;
      
      print('Successfully ended session: $sessionId');
    } catch (e) {
      print('Error ending session: $e');
      rethrow;
    }
  }

  void dispose() {
    _sessionSubscription?.cancel();
  }
} 