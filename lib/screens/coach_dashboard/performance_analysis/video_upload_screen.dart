import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path/path.dart' as path;
import '../../../services/performance_sync_service.dart';
import 'performance_analysis_screen.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../../../config.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../models/motion_data.dart';

// Conditionally import dart:html for web
import 'web_video_player.dart' if (dart.library.html) 'dart:html' as html;

class VideoUploadScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const VideoUploadScreen({
    Key? key,
    required this.athleteId,
    required this.athleteName,
  }) : super(key: key);

  @override
  _VideoUploadScreenState createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  File? _selectedVideo;
  Uint8List? _selectedVideoBytes;
  String? _selectedVideoName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _sessionId;
  String _sessionType = 'training';
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  StreamSubscription? _analysisSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _videoUrl;
  String _status = 'initial';

  // Add new variables for validation
  static const int _maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
  static const List<String> _supportedFormats = ['mp4', 'mov', 'avi', 'webm'];
  bool _isProcessing = false;
  String? _processingError;

  // Add new field for coach ID
  String? _coachId;
  
  // Update Cloudinary instance to use config
  final cloudinary = CloudinaryPublic(
    CloudinaryConfig.cloudName,
    CloudinaryConfig.uploadPreset,
    cache: false,
  );
  
  // Add new fields for pose detection
  PoseDetector? _poseDetector;
  List<Point3D>? _currentPosePoints;
  Size? _videoSize;

  @override
  void initState() {
    super.initState();
    _fetchCoachId();
    _initializePoseDetector();
  }

  Future<void> _fetchCoachId() async {
    try {
      // First try to get the current user (coach)
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // If we're logged in as a coach, use their ID
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists && userDoc.data()?['role'] == 'coach') {
          setState(() {
            _coachId = currentUser.uid;
          });
          print('Using current user as coach: $_coachId');
          return;
        }
      }

      // If not logged in as coach, try to get coach ID from athlete's data
      print('Fetching athlete document for ID: ${widget.athleteId}');
      
      // First try direct ID lookup
      var athleteDoc = await _firestore
          .collection('users')
          .doc(widget.athleteId)
          .get();
      
      // If not found, try looking up by email
      if (!athleteDoc.exists) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: widget.athleteId)
            .limit(1)
            .get();
            
        if (querySnapshot.docs.isNotEmpty) {
          athleteDoc = querySnapshot.docs.first;
        }
      }
      
      if (athleteDoc.exists) {
        final data = athleteDoc.data();
        print('Athlete data: $data');
        
        if (data != null && data.containsKey('coachId')) {
          setState(() {
            _coachId = data['coachId'];
          });
          print('Found coach ID from athlete data: $_coachId');
        } else {
          print('No coachId field found in athlete data');
          _showError('Coach ID not found in athlete data');
        }
      } else {
        print('Athlete document not found');
        _showError('Athlete data not found');
      }
    } catch (e) {
      print('Error fetching coach ID: $e');
      _showError('Error fetching coach data: $e');
    }
  }

  Future<void> _initializePoseDetector() async {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    );
    _poseDetector = PoseDetector(options: options);
  }

  @override
  void dispose() {
    _poseDetector?.close();
    _videoController?.dispose();
    _analysisSubscription?.cancel();
    if (kIsWeb && _videoUrl != null) {
      try {
        html.Url.revokeObjectUrl(_videoUrl!);
      } catch (e) {
        print('Error revoking URL: $e');
      }
    }
    setState(() {
      _isUploading = false;
    });
    super.dispose();
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoController != null) {
      await _videoController!.dispose();
    }

    try {
      if (kIsWeb && _selectedVideoBytes != null) {
        // For web, create a blob URL
        final blob = html.Blob([_selectedVideoBytes]);
        _videoUrl = html.Url.createObjectUrl(blob);
        _videoController = VideoPlayerController.network(_videoUrl!);
      } else if (!kIsWeb && _selectedVideo != null) {
        // For mobile, use file
        _videoController = VideoPlayerController.file(_selectedVideo!);
      }

      if (_videoController != null) {
        await _videoController!.initialize();
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video player: $e');
      _showError('Error initializing video player: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _processingError = null; // Reset any previous errors
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      // If user cancels the picker
      if (result == null) {
        setState(() {
          _isUploading = false;
          _selectedVideo = null;
          _selectedVideoBytes = null;
          _selectedVideoName = null;
        });
        return;
      }

      // Reset video controller if exists
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }

      // Handle web platform
      if (kIsWeb) {
        _selectedVideoBytes = result.files.first.bytes;
        _selectedVideoName = result.files.first.name;
      } else {
        _selectedVideo = File(result.files.first.path!);
        _selectedVideoName = path.basename(_selectedVideo!.path);
      }

      // Initialize video player
      await _initializeVideoPlayer();
      
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    } catch (e) {
      print('Error picking video: $e');
      setState(() {
        _isUploading = false;
        _selectedVideo = null;
        _selectedVideoBytes = null;
        _selectedVideoName = null;
        _processingError = 'Error selecting video: $e';
      });
      _showError('Error selecting video: $e');
    }
  }

  Future<void> _uploadVideo() async {
    // Validate input
    if ((_selectedVideo == null && _selectedVideoBytes == null) || _selectedVideoName == null) {
      _showError('Please select a video first');
      return;
    }

    if (_coachId == null) {
      _showError('Coach data not available. Please try again.');
      return;
    }

    try {
      // Reset states
      setState(() {
        _isUploading = true;
        _isProcessing = true;
        _uploadProgress = 0.0;
        _processingError = null;
        _status = 'uploading';
      });

      // Generate session ID
      _sessionId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      final docRef = _firestore.collection('athletePerformanceAnalysis').doc(_sessionId);
      
      // Create initial document
      await docRef.set({
        'athleteId': widget.athleteId,
        'coachId': _coachId,
        'sessionType': _sessionType,
        'status': 'uploading',
        'timestamp': FieldValue.serverTimestamp(),
        'processingProgress': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Upload to Cloudinary with timeout
      print('Starting Cloudinary upload...');
      try {
        CloudinaryResponse response;
        final uploadFuture = kIsWeb && _selectedVideoBytes != null
            ? cloudinary.uploadFile(
                CloudinaryFile.fromBytesData(
                  _selectedVideoBytes!,
                  identifier: '${DateTime.now().millisecondsSinceEpoch}_${_selectedVideoName ?? 'video.mp4'}',
                  resourceType: CloudinaryResourceType.Video,
                  folder: 'athlete_videos'
                )
              )
            : cloudinary.uploadFile(
                CloudinaryFile.fromFile(
                  _selectedVideo!.path,
                  resourceType: CloudinaryResourceType.Video,
                  folder: 'athlete_videos'
                )
              );

        // Add timeout to upload
        response = await uploadFuture.timeout(
          Duration(minutes: 5),
          onTimeout: () {
            throw TimeoutException('Video upload timed out. Please try again with a smaller video.');
          },
        );

        print('Cloudinary upload successful: ${response.secureUrl}');
        
        // Update document with video URL
        await docRef.update({
          'videoUrl': response.secureUrl,
          'status': 'processing',
          'lastUpdated': FieldValue.serverTimestamp(),
          'processingProgress': 0.5,
        });

        // Start analysis
        final serverUrl = kIsWeb 
            ? 'http://localhost:8000/analyze_video'
            : 'http://10.0.2.2:8000/analyze_video';
        
        var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
        
        // Add video file
        if (kIsWeb && _selectedVideoBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'video',
              _selectedVideoBytes!,
              filename: _selectedVideoName ?? 'video.mp4',
            ),
          );
        } else if (!kIsWeb && _selectedVideo != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'video',
              _selectedVideo!.path,
              filename: path.basename(_selectedVideo!.path),
            ),
          );
        }
        
        // Add form fields
        request.fields['athlete_id'] = widget.athleteId;
        request.fields['coach_id'] = _coachId!;
        request.fields['session_type'] = _sessionType;
        if (_sessionId == null) {
          throw Exception('Session ID is not available');
        }
        request.fields['session_id'] = _sessionId!;
        
        // Send request with timeout
        final streamedResponse = await request.send().timeout(
          Duration(minutes: 2),
          onTimeout: () {
            throw TimeoutException('Analysis request timed out. Please try again.');
          },
        );
        
        final analysisResponse = await http.Response.fromStream(streamedResponse);

        if (analysisResponse.statusCode == 200) {
          _listenToAnalysisProgress();
        } else {
          throw Exception('Analysis request failed with status ${analysisResponse.statusCode}: ${analysisResponse.body}');
        }

      } catch (cloudinaryError) {
        print('Error uploading to Cloudinary: $cloudinaryError');
        // Update document with error
        await docRef.update({
          'status': 'error',
          'error': cloudinaryError.toString(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        throw cloudinaryError;
      }

    } catch (e) {
      print('Error during upload process: $e');
      
      // Update document with error if exists
      if (_sessionId != null) {
        try {
          await _firestore
              .collection('athletePerformanceAnalysis')
              .doc(_sessionId)
              .update({
                'status': 'error',
                'error': e.toString(),
                'lastUpdated': FieldValue.serverTimestamp(),
              });
        } catch (updateError) {
          print('Error updating Firestore document: $updateError');
        }
      }
      
      // Reset states
      setState(() {
        _isUploading = false;
        _isProcessing = false;
        _processingError = e.toString();
        _status = 'error';
        _uploadProgress = 0.0;
      });

      // Show appropriate error message
      String errorMessage = 'Upload failed: ';
      if (e is TimeoutException) {
        errorMessage += 'Request timed out. Please try again with a smaller video.';
      } else if (e.toString().contains('not-found')) {
        errorMessage += 'Session data was lost. Please try again.';
      } else {
        errorMessage += e.toString();
      }
      _showError(errorMessage);
    }
  }

  void _listenToAnalysisProgress() {
    if (_sessionId == null) return;

    try {
      // Listen to the main document with video URL
      _analysisSubscription = _firestore
          .collection('athletePerformanceAnalysis')
          .doc(_sessionId)
          .snapshots()
          .listen(
        (mainSnapshot) async {
          if (!mounted) return;
          
          if (!mainSnapshot.exists) {
            setState(() {
              _isUploading = false;
              _isProcessing = false;
              _processingError = 'Analysis session not found';
            });
            _showError('Analysis session not found');
            return;
          }

          try {
            final mainData = mainSnapshot.data()!;
            final mainStatus = mainData['status'] as String;
            final progress = (mainData['processingProgress'] as num?)?.toDouble() ?? 0.0;
            final lastUpdated = mainData['lastUpdated'] as Timestamp?;
            final videoUrl = mainData['videoUrl'] as String?;

            // If this document has video URL and is not completed, check other documents
            if (videoUrl != null && mainStatus != 'completed') {
              // Query to find any document with the same athleteId that has completed status
              final completedDocs = await _firestore
                  .collection('athletePerformanceAnalysis')
                  .where('athleteId', isEqualTo: widget.athleteId)
                  .where('status', isEqualTo: 'completed')
                  .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: 5))))
                  .get();

              // If we found any completed document, update this document
              if (completedDocs.docs.isNotEmpty) {
                final completedDoc = completedDocs.docs.first;
                final completedData = completedDoc.data();
                
                // Copy metrics and other data from completed document
                await _firestore
                    .collection('athletePerformanceAnalysis')
                    .doc(_sessionId)
                    .update({
                      'status': 'completed',
                      'processingProgress': 1.0,
                      'lastUpdated': FieldValue.serverTimestamp(),
                      'metrics': completedData['metrics'] ?? {},
                      'recommendations': completedData['recommendations'] ?? {},
                      'completedAt': completedData['completedAt'] ?? FieldValue.serverTimestamp(),
                    });
                return; // The listener will pick up the update
              }
            }

            // Update pose data if available
            _updatePoseData(mainData['current_frame_data'] as Map<String, dynamic>?);

            // Check if the document hasn't been updated in the last 2 minutes
            if (lastUpdated != null) {
              final now = DateTime.now();
              final lastUpdateTime = lastUpdated.toDate();
              if (now.difference(lastUpdateTime).inMinutes > 2 && mainStatus == 'processing') {
                if (!mounted) return;
                setState(() {
                  _isUploading = false;
                  _isProcessing = false;
                  _processingError = 'Processing timed out. Please try again.';
                });
                _showError('Processing timed out. Please try again.');
                return;
              }
            }

            if (!mounted) return;
            setState(() {
              if (mainStatus == 'uploading') {
                _isUploading = true;
                _isProcessing = false;
                _uploadProgress = progress;
                _status = 'uploading';
              } else if (mainStatus == 'processing') {
                _isUploading = false;
                _isProcessing = true;
                _uploadProgress = 0.5 + (progress * 0.5); // Scale progress to 50-100%
                _status = 'processing';
              } else if (mainStatus == 'completed') {
                _isUploading = false;
                _isProcessing = false;
                _uploadProgress = 1.0;
                _status = 'completed';
                _showSuccess('Video analysis completed');
                // Add a small delay before navigation to ensure the success message is shown
                Future.delayed(Duration(seconds: 1), () {
                  if (mounted) {
                    _navigateToResults();
                  }
                });
              } else if (mainStatus == 'error') {
                _isUploading = false;
                _isProcessing = false;
                _status = 'error';
                _processingError = mainData['error'] as String?;
                _showError('Analysis failed: ${mainData['error']}');
              }
            });
          } catch (e) {
            print('Error processing snapshot data: $e');
            if (!mounted) return;
            setState(() {
              _isUploading = false;
              _isProcessing = false;
              _processingError = 'Error processing analysis data: $e';
            });
            _showError('Error processing analysis data: $e');
          }
        },
        onError: (error) {
          print('Error in Firestore listener: $error');
          if (!mounted) return;
          setState(() {
            _isUploading = false;
            _isProcessing = false;
            _processingError = error.toString();
          });
          _showError('Error monitoring analysis progress: $error');
        },
      );
    } catch (e) {
      print('Error setting up Firestore listener: $e');
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _isProcessing = false;
        _processingError = 'Error setting up analysis monitoring: $e';
      });
      _showError('Error setting up analysis monitoring: $e');
    }
  }

  void _navigateToResults() {
    if (_sessionId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PerformanceAnalysisScreen(
            athleteId: widget.athleteId,
            athleteName: widget.athleteName,
            sessionId: _sessionId!,
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Add method to update pose data
  void _updatePoseData(Map<String, dynamic>? data) {
    if (data == null) return;
    
    try {
      final poseData = data['pose_keypoints'] as List<dynamic>?;
      if (poseData != null) {
        List<Point3D> points = [];
        for (var i = 0; i < poseData.length; i += 3) {
          if (i + 2 < poseData.length) {
            points.add(Point3D(
              x: (poseData[i] as num).toDouble(),
              y: (poseData[i + 1] as num).toDouble(),
              z: (poseData[i + 2] as num).toDouble(),
            ));
          }
        }
        
        if (mounted) {
          setState(() {
            _currentPosePoints = points;
            print('Updated pose points: ${points.length} keypoints');
          });
        }
      }
    } catch (e) {
      print('Error updating pose data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Video - ${widget.athleteName}'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Preview with Processing Overlay
              _buildVideoPreview(),

              SizedBox(height: 16),

              // Session Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _sessionType,
                        decoration: InputDecoration(
                          labelText: 'Session Type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          'training',
                          'competition',
                          'assessment',
                          'practice',
                        ].map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.toUpperCase()),
                        )).toList(),
                        onChanged: (value) => setState(() => _sessionType = value!),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Video Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Selection',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),
                      if (_selectedVideo == null && _selectedVideoBytes == null)
                        Center(
                          child: Column(
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.video_library),
                                label: Text('Select Video'),
                                onPressed: !_isUploading ? _pickVideo : null,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Supported formats: MP4, MOV, AVI, WEBM\nMax size: 100MB',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            Text(
                              'Selected: ${_selectedVideoName ?? path.basename(_selectedVideo?.path ?? '')}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _selectedVideo = null;
                                      _selectedVideoBytes = null;
                                      _selectedVideoName = null;
                                      _videoController?.dispose();
                                      _videoController = null;
                                      if (kIsWeb && _videoUrl != null) {
                                        html.Url.revokeObjectUrl(_videoUrl!);
                                        _videoUrl = null;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              if (_isUploading || _isProcessing) ...[
                SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isProcessing ? 'Processing Video...' : 'Uploading Video...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _status == 'completed' ? 1.0 : _uploadProgress,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _status == 'completed' 
                              ? '100%' 
                              : '${(_uploadProgress * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_processingError != null) ...[
                SizedBox(height: 16),
                Card(
                  color: Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _processingError!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.upload),
                label: Text('Upload & Analyze'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: ((_selectedVideo != null || _selectedVideoBytes != null) && !_isUploading)
                    ? _uploadVideo
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!(_videoController?.value.isInitialized ?? false)) return SizedBox.shrink();

    return Card(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Video Player
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
              
              // Pose Detection Overlay
              if (_currentPosePoints != null)
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: CustomPaint(
                      painter: PoseOverlayPainter(
                        points: _currentPosePoints!,
                        imageSize: Size(
                          _videoController!.value.size.width,
                          _videoController!.value.size.height,
                        ),
                      ),
                    ),
                  ),
                ),

              // Processing Overlay
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Video Controls
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isVideoPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: !_isProcessing ? () {
                  setState(() {
                    _isVideoPlaying = !_isVideoPlaying;
                    _isVideoPlaying
                        ? _videoController!.play()
                        : _videoController!.pause();
                  });
                } : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PoseOverlayPainter extends CustomPainter {
  final List<Point3D> points;
  final Size imageSize;

  PoseOverlayPainter({
    required this.points,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw points
    for (var point in points) {
      final scaledPoint = _scalePoint(
        Offset(point.x.toDouble(), point.y.toDouble()),
        imageSize,
        size,
      );
      canvas.drawCircle(scaledPoint, 6, paint);
    }

    // Define pose connections (pairs of point indices that should be connected)
    final connections = [
      [11, 13], // left shoulder to left elbow
      [13, 15], // left elbow to left wrist
      [12, 14], // right shoulder to right elbow
      [14, 16], // right elbow to right wrist
      [11, 12], // shoulders
      [23, 24], // hips
      [23, 25], // left hip to left knee
      [25, 27], // left knee to left ankle
      [24, 26], // right hip to right knee
      [26, 28], // right knee to right ankle
      [11, 23], // left shoulder to left hip
      [12, 24], // right shoulder to right hip
    ];

    // Draw connections
    for (var connection in connections) {
      if (connection[0] < points.length && connection[1] < points.length) {
        final point1 = _scalePoint(
          Offset(points[connection[0]].x.toDouble(), points[connection[0]].y.toDouble()),
          imageSize,
          size,
        );
        final point2 = _scalePoint(
          Offset(points[connection[1]].x.toDouble(), points[connection[1]].y.toDouble()),
          imageSize,
          size,
        );
        canvas.drawLine(point1, point2, linePaint);
      }
    }
  }

  Offset _scalePoint(Offset point, Size imageSize, Size canvasSize) {
    return Offset(
      point.dx * canvasSize.width / imageSize.width,
      point.dy * canvasSize.height / imageSize.height,
    );
  }

  @override
  bool shouldRepaint(PoseOverlayPainter oldDelegate) {
    return true; // Always repaint for real-time updates
  }
} 