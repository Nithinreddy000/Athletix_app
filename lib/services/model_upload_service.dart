import 'dart:io';
import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ModelUploadService {
  final CloudinaryPublic cloudinary;
  
  // Initialize with your Cloudinary credentials
  ModelUploadService({
    required String cloudName,
    required String uploadPreset,
  }) : cloudinary = CloudinaryPublic(cloudName, uploadPreset);
  
  /// Upload a 3D model file to Cloudinary and return the URL
  Future<String> uploadModelFile(File modelFile) async {
    try {
      // Upload the file to Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          modelFile.path,
          resourceType: CloudinaryResourceType.raw,
          folder: '3d_models',
        ),
      );
      
      // Return the secure URL with web-friendly parameters
      return getWebFriendlyUrl(response.secureUrl);
    } catch (e) {
      debugPrint('Error uploading model file: $e');
      rethrow;
    }
  }
  
  /// Upload a 3D model from a byte array to Cloudinary and return the URL
  Future<String> uploadModelBytes(Uint8List modelBytes, String fileName) async {
    try {
      if (kIsWeb) {
        // For web, upload directly from bytes
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            modelBytes,
            identifier: fileName,
            resourceType: CloudinaryResourceType.raw,
            folder: '3d_models',
          ),
        );
        
        return getWebFriendlyUrl(response.secureUrl);
      } else {
        // For mobile/desktop, create a temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(modelBytes);
        
        // Upload the file to Cloudinary
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            tempFile.path,
            resourceType: CloudinaryResourceType.raw,
            folder: '3d_models',
          ),
        );
        
        // Clean up the temporary file
        await tempFile.delete();
        
        // Return the secure URL with web-friendly parameters
        return getWebFriendlyUrl(response.secureUrl);
      }
    } catch (e) {
      debugPrint('Error uploading model bytes: $e');
      rethrow;
    }
  }
  
  /// Download a 3D model from a URL and return it as a File
  Future<File> downloadModelToFile(String url) async {
    try {
      if (kIsWeb) {
        throw Exception('Direct file download is not supported on web platform');
      }
      
      // Extract filename from URL or generate a random one
      String fileName = url.split('/').last.split('?').first;
      if (fileName.isEmpty) {
        fileName = 'model_${DateTime.now().millisecondsSinceEpoch}.glb';
      }
      
      // Make the HTTP request to download the file
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download model: ${response.statusCode}');
      }
      
      // Create a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      
      // Write the file
      await file.writeAsBytes(response.bodyBytes);
      
      return file;
    } catch (e) {
      debugPrint('Error downloading model: $e');
      rethrow;
    }
  }
  
  /// Get a direct URL for a model that can be used in web applications
  String getWebFriendlyUrl(String url) {
    // Ensure CORS is enabled for web access
    if (url.contains('cloudinary.com')) {
      // Add CORS-friendly parameters for Cloudinary URLs
      if (!url.contains('fl_attachment')) {
        url = '$url?fl_attachment=false';
      }
      
      // Add additional parameters for better Three.js compatibility
      if (!url.contains('Expires')) {
        // Add a long expiration time
        url = '$url&Expires=${DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000}';
      }
      
      // Add CORS headers
      if (!url.contains('Access-Control-Allow-Origin')) {
        url = '$url&Access-Control-Allow-Origin=*';
      }
    }
    
    return url;
  }
  
  /// Get the file extension from a URL
  String getFileExtension(String url) {
    final fileName = url.split('/').last.split('?').first;
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'glb'; // Default to GLB if no extension found
  }
  
  /// Check if the URL is for a supported 3D model format
  bool isSupportedModelFormat(String url) {
    final extension = getFileExtension(url);
    return ['glb', 'gltf', 'obj', 'fbx'].contains(extension);
  }
} 