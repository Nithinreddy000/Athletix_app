import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../config.dart';

class MedicalReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Dio _dio = Dio();
  final String _baseUrl = Config.apiBaseUrl;  // Using central config instead of hardcoded URL
  
  Future<Map<String, dynamic>> uploadMedicalReport({
    required String athleteId,
    required String title,
    required String diagnosis,
    required Uint8List pdfBytes,
    Uint8List? modelBytes,
    String? modelFileName,
  }) async {
    try {
      print('Uploading medical report for athlete: $athleteId');
      
      // Create form data
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          pdfBytes,
          filename: 'report.pdf',
        ),
        'athlete_id': athleteId,
        'title': title,
        'diagnosis': diagnosis,
      });

      // Send to Flask backend for processing
      final response = await _dio.post(
        '$_baseUrl/upload_report',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print('Upload successful. Response data:');
        print('Model URL: ${data['model_url']}');
        print('Injury data: ${data['injury_data']}');

        // Store the report in Firestore
        await _firestore.collection('medical_reports').add({
          'athlete_id': athleteId,
          'title': title,
          'diagnosis': diagnosis,
          'timestamp': FieldValue.serverTimestamp(),
          'injury_data': data['injury_data'],
          'model_url': data['model_url'],
          'status': 'processed'
        });

        return data;
      } else {
        throw Exception('Failed to upload medical report: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading medical report: $e');
      throw Exception('Failed to upload medical report: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMedicalReports(String athleteId) async {
    try {
      print('Fetching medical reports for athlete: $athleteId');
      
      // Get medical reports from Firestore
      final QuerySnapshot snapshot = await _firestore
          .collection('medical_reports')
          .where('athlete_id', isEqualTo: athleteId)
          .get();

      final reports = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final analysisResult = data['analysis_result'] as Map<String, dynamic>?;
        final injuryData = analysisResult?['injury_data'] as List? ?? [];
        
        // Get model URL and normalize path
        String modelUrl = data['slicer_model_url'] ?? '';
        if (modelUrl.isNotEmpty) {
          // Ensure forward slashes for web URLs
          modelUrl = modelUrl.replaceAll('\\', '/');
          
          // Make sure it has the proper format for API access
          if (!modelUrl.startsWith('http') && !modelUrl.startsWith('/')) {
            modelUrl = '/$modelUrl';
          }
        }
        
        return {
          'id': doc.id,
          'timestamp': data['created_at'] ?? data['lastUpdated'] ?? Timestamp.now(),
          'injury_data': injuryData,
          'model_url': modelUrl,  // Updated normalized URL
          'status': data['status'] ?? 'pending',
          'diagnosis': data['description'] ?? '',
          'athlete_id': data['athlete_id'] ?? '',
          'athlete_name': data['athlete_name'] ?? '',
          'title': data['title'] ?? 'Medical Report',
        };
      }).toList();

      print('Fetched ${reports.length} reports with data:');
      reports.forEach((report) {
        print('Report ID: ${report['id']}');
        print('Injury Data: ${report['injury_data']}');
        print('Model URL: ${report['model_url']}');
      });
      
      return reports;
    } catch (e) {
      print('Error fetching medical reports: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Failed to fetch medical reports: $e');
    }
  }

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'recovered':
        return '#4CAF50';
      case 'recovering':
        return '#FFA500';
      default:
        return '#FF0000';
    }
  }

  int _calculateRecoveryProgress(String status) {
    switch (status.toLowerCase()) {
      case 'recovered':
        return 100;
      case 'recovering':
        return 50;
      default:
        return 0;
    }
  }

  Map<String, double> _getBodyPartCoordinates(String bodyPart) {
    // Updated coordinates based on ModelCoordinatesService's fallback zones
    final coordinates = {
      'head': {'x': 0.335, 'y': 0.26, 'z': 0.0},
      'neck': {'x': 0.335, 'y': 0.32, 'z': 0.0},
      'right_shoulder': {'x': 0.298, 'y': 0.322, 'z': 0.0},
      'left_shoulder': {'x': 0.37, 'y': 0.33, 'z': 0.0},
      'right_upper_arm': {'x': 0.277, 'y': 0.335, 'z': 0.0},
      'left_upper_arm': {'x': 0.25, 'y': 0.335, 'z': 0.0},
      'right_forearm': {'x': 0.24, 'y': 0.335, 'z': 0.0},
      'left_forearm': {'x': 0.465, 'y': 0.33, 'z': 0.0},
      'right_hand': {'x': 0.21, 'y': 0.335, 'z': 0.0},
      'left_hand': {'x': 0.465, 'y': 0.33, 'z': 0.0},
      'spine_top': {'x': 0.335, 'y': 0.37, 'z': -0.1},
      'spine_down': {'x': 0.335, 'y': 0.43, 'z': -0.1},
      'waist': {'x': 0.335, 'y': 0.48, 'z': -0.1},
      'right_thigh': {'x': 0.317, 'y': 0.573, 'z': 0.0},
      'left_thigh': {'x': 0.355, 'y': 0.57, 'z': 0.0},
      'right_calf': {'x': 0.312, 'y': 0.71, 'z': 0.0},
      'left_calf': {'x': 0.355, 'y': 0.715, 'z': 0.0},
      'right_foot': {'x': 0.3125, 'y': 0.8, 'z': 0.0},
      'left_foot': {'x': 0.355, 'y': 0.8, 'z': 0.0},
      // Aliases for common terms
      'back': {'x': 0.335, 'y': 0.4, 'z': -0.1},
      'spine': {'x': 0.335, 'y': 0.4, 'z': -0.1},
      'shoulder': {'x': 0.298, 'y': 0.322, 'z': 0.0}, // defaults to right
      'arm': {'x': 0.277, 'y': 0.335, 'z': 0.0}, // defaults to right
      'leg': {'x': 0.317, 'y': 0.573, 'z': 0.0}, // defaults to right
      'foot': {'x': 0.3125, 'y': 0.8, 'z': 0.0}, // defaults to right
    };
    
    final normalizedBodyPart = bodyPart.toLowerCase();
    return Map<String, double>.from(coordinates[normalizedBodyPart] ?? 
        {'x': 0.335, 'y': 0.5, 'z': 0.0}); // Default center point if not found
  }

  Future<bool> deleteMedicalReport(String reportId) async {
    try {
      // Delete report through Python backend
      final response = await _dio.delete(
        '$_baseUrl/medical_reports/$reportId',
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting medical report: $e');
      return false;
    }
  }
} 