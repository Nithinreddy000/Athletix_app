import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = "Athlete Management System";
  
  // API Configuration
  static const String apiVersion = "v1";
  
  // Using Google Cloud Run URL instead of Render
  static const String apiBaseUrl = 'http://34.30.180.220/';
  
  // Theme Configuration
  static const Color primaryColor = Color(0xFF2697FF);
  static const Color secondaryColor = Color(0xFF2A2D3E);
  static const Color bgColor = Color(0xFF212332);
  
  // Performance Analysis
  static const int minVideoLength = 3; // Minimum video length in seconds
  static const int maxVideoLength = 300; // Maximum video length in seconds
  
  // Feature Flags
  static const bool enableRealTimeAnalysis = true;
  static const bool enablePoseDetection = true;
  static const bool enableAdvancedMetrics = true;
  static const bool enableInjuryVisualization = true;
  static const bool enableUnityModels = false;
  static const bool enableEnhancedThreeViewer = true;
  
  // Cache Configuration
  static const Duration cacheDuration = Duration(hours: 24);
}

class CloudinaryConfig {
  static const String cloudName = 'ddu7ck4pg';
  // Note: This upload preset must be created in your Cloudinary account and configured as "unsigned"
  static const String uploadPreset = 'athlete_videos';  // Changed from ml_default to a custom preset
  static const String apiKey = '933679325529897';
  static const String apiSecret = 'wRO_IJL4GwbesMK4X6F-WZvR5Bo';
}

class Config {
  // API base URL - updated to Google Cloud Run URL
  static const String apiBaseUrl = 'http://34.30.180.220/';
  
  // Fallback URL in case the primary URL is not reachable
  static const String fallbackApiBaseUrl = 'http://34.30.180.220/';
  
  // Enable mock mode for testing without a backend
  static const bool enableMockMode = false;
  
  // For production, use your deployed backend URL
  // static const String apiBaseUrl = 'https://your-production-backend.com';
}

class GeminiConfig {
  // API key from python_backend/config.json
  static const String apiKey = 'AIzaSyCxlsb7Ya9viMJmzaBY7FmpcCf1ZXbAKlE';
  
  // Gemini API base URL
  static const String apiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  // Gemini model to use
  static const String model = 'gemini-2.0-flash';
  
  // Whether to use mock data instead of calling the actual API
  // Set to true only for testing without a valid API key
  static const bool useMockData = false;
}

// You can add other configuration constants here 