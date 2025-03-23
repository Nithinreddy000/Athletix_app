import 'package:cloudinary_public/cloudinary_public.dart';
import '../config.dart';
import 'dart:typed_data';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  CloudinaryPublic? _cloudinary;

  factory CloudinaryService() {
    return _instance;
  }

  CloudinaryService._internal();

  void initialize() {
    if (_cloudinary == null) {
      _cloudinary = CloudinaryPublic(
        CloudinaryConfig.cloudName,
        CloudinaryConfig.uploadPreset,
        cache: false,
      );
    }
  }

  Future<CloudinaryResponse> uploadPDF(
    Uint8List fileBytes,
    String fileName,
    String folder,
  ) async {
    if (_cloudinary == null) {
      throw Exception('CloudinaryService not initialized');
    }

    try {
      final response = await _cloudinary!.uploadFile(
        CloudinaryFile.fromBytesData(
          fileBytes,
          identifier: fileName,
          folder: folder,
          resourceType: CloudinaryResourceType.Raw,
        ),
      );
      return response;
    } catch (e) {
      print('Cloudinary upload error: $e');
      throw Exception('Failed to upload file to Cloudinary: $e');
    }
  }

  // Note: Cloudinary Public API doesn't support file deletion
  // You'll need to handle deletion through your backend or use the admin API
  Future<void> deleteFile(String publicId) async {
    try {
      // For now, we'll just log the deletion request
      print('Note: File deletion needs to be handled through backend: $publicId');
      // TODO: Implement deletion through your backend service
    } catch (e) {
      print('Cloudinary delete error: $e');
      rethrow;
    }
  }
} 