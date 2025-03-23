import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart'; // Import the config to get the URL

class MeshData {
  final String name;
  final Map<String, double> center;
  final Map<String, double> dimensions;
  final Map<String, Map<String, double>> bbox;
  final Map<String, dynamic> optimalCamera;

  MeshData({
    required this.name,
    required this.center,
    required this.dimensions,
    required this.bbox,
    required this.optimalCamera,
  });

  factory MeshData.fromJson(Map<String, dynamic> json) {
    return MeshData(
      name: json['name'],
      center: Map<String, double>.from(json['center']),
      dimensions: Map<String, double>.from(json['dimensions']),
      bbox: {
        'min': Map<String, double>.from(json['bbox']['min']),
        'max': Map<String, double>.from(json['bbox']['max']),
      },
      optimalCamera: json['optimal_camera'],
    );
  }
}

class MeshDataService {
  final String baseUrl;
  Map<String, Map<String, MeshData>>? _meshDataCache;

  // Use the cloud run URL from config by default
  MeshDataService({this.baseUrl = AppConfig.apiBaseUrl});

  Future<Map<String, MeshData>> getMeshData(String modelUrl) async {
    try {
      // Extract model name from URL
      final uri = Uri.parse(modelUrl);
      final modelName = uri.pathSegments.last.replaceAll('.glb', '');
      
      print('Attempting to load mesh data for model: $modelName');

      // Check cache first
      if (_meshDataCache?.containsKey(modelName) ?? false) {
        print('Returning cached mesh data for: $modelName');
        return _meshDataCache![modelName]!;
      }

      // Construct mesh data URL
      final meshDataUrl = '$baseUrl/mesh_data/${modelName}_mesh_data.json';
      print('Fetching mesh data from: $meshDataUrl');

      final response = await http.get(Uri.parse(meshDataUrl));
      
      if (response.statusCode == 200) {
        print('Successfully received mesh data response');
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        final meshData = jsonData.map((key, value) => MapEntry(
          key,
          MeshData.fromJson(value as Map<String, dynamic>),
        ));

        // Cache the data
        _meshDataCache ??= {};
        _meshDataCache![modelName] = meshData;

        print('Successfully parsed mesh data with ${meshData.length} meshes');
        return meshData;
      } else {
        print('Failed to load mesh data. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load mesh data. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error loading mesh data: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to load mesh data: $e');
    }
  }

  String? findMatchingMesh(Map<String, MeshData> meshData, String bodyPart) {
    final normalizedBodyPart = bodyPart.toLowerCase();
    print('Finding mesh for body part: $normalizedBodyPart');
    
    // Try exact match first
    final exactMatch = meshData.keys.firstWhere(
      (key) => key.toLowerCase() == normalizedBodyPart,
      orElse: () => '',
    );
    
    if (exactMatch.isNotEmpty) {
      print('Found exact match: $exactMatch');
      return exactMatch;
    }

    // Try partial match
    final partialMatch = meshData.keys.firstWhere(
      (key) => key.toLowerCase().contains(normalizedBodyPart) ||
               normalizedBodyPart.contains(key.toLowerCase()),
      orElse: () => '',
    );
    
    if (partialMatch.isNotEmpty) {
      print('Found partial match: $partialMatch');
      return partialMatch;
    }

    print('No matching mesh found for: $bodyPart');
    return null;
  }

  Map<String, dynamic>? getOptimalCameraPosition(MeshData meshData) {
    try {
      final bestAngle = meshData.optimalCamera['best_angles'][0];
      final distance = meshData.optimalCamera['distance'];
      
      final position = {
        'orbit': '${bestAngle['theta']}deg ${bestAngle['phi']}deg ${distance}m',
        'target': '${meshData.center['x']}m ${meshData.center['y']}m ${meshData.center['z']}m',
        'fieldOfView': '30deg',
      };
      
      print('Calculated camera position: $position');
      return position;
    } catch (e) {
      print('Error calculating camera position: $e');
      return null;
    }
  }
} 