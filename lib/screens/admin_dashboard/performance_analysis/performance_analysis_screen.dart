import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../services/performance_service.dart';
import '../../../constants.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';

class RecordPerformanceScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const RecordPerformanceScreen({
    Key? key,
    required this.athleteId,
    required this.athleteName,
  }) : super(key: key);

  @override
  _RecordPerformanceScreenState createState() => _RecordPerformanceScreenState();
}

class _RecordPerformanceScreenState extends State<RecordPerformanceScreen> {
  final PerformanceService _performanceService = PerformanceService();
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
      enableClassification: true,
    ),
  );
  bool _isRecording = false;
  CameraController? _cameraController;
  List<Pose> _detectedPoses = [];
  Size? _imageSize;
  Timer? _metricsTimer;
  
  // Store the latest metrics
  Map<String, dynamic> _currentMetrics = {};

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    _metricsTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Try to get the back camera first
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.bgra8888 
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController?.initialize();
      
      // Set the right orientation
      await _cameraController?.lockCaptureOrientation(DeviceOrientation.portraitUp);
      
      if (mounted) {
        setState(() {
          _imageSize = Size(
            _cameraController!.value.previewSize!.height,
            _cameraController!.value.previewSize!.width,
          );
        });
      }
    } catch (e) {
      _showError('Error initializing camera: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera not initialized');
      return;
    }

    if (_isRecording) return;

    try {
      await _cameraController?.startImageStream((image) {
        if (!_isRecording) return;
        _processFrame(image);
      });

      // Start periodic metrics calculation and storage
      _metricsTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_currentMetrics.isNotEmpty) {
          _storeMetrics();
        }
      });

      setState(() {
        _isRecording = true;
        _imageSize = Size(
          _cameraController!.value.previewSize!.height,
          _cameraController!.value.previewSize!.width,
        );
      });
    } catch (e) {
      _showError('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      await _cameraController?.stopImageStream();
      _metricsTimer?.cancel();
      setState(() {
        _isRecording = false;
        _detectedPoses = [];
      });
    } catch (e) {
      _showError('Error stopping recording: $e');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (!mounted) return;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation90deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final poses = await _poseDetector.processImage(inputImage);
      
      if (poses.isNotEmpty) {
        // Calculate metrics from the detected pose
        _currentMetrics = _calculateMetrics(poses.first);
        
        setState(() {
          _detectedPoses = poses;
        });
      }
    } catch (e) {
      print('Error processing frame: $e');
    }
  }

  Map<String, dynamic> _calculateMetrics(Pose pose) {
    // Calculate various metrics from the pose
    double symmetryScore = _calculateSymmetryScore(pose);
    double stabilityScore = _calculateStabilityScore(pose);
    List<double> jointAngles = _calculateJointAngles(pose);
    
    return {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'symmetryScore': symmetryScore,
      'stabilityScore': stabilityScore,
      'jointAngles': jointAngles,
      'confidence': pose.allPoseLandmarks.fold(0.0, (sum, landmark) => sum + landmark.likelihood) / pose.allPoseLandmarks.length,
    };
  }

  double _calculateSymmetryScore(Pose pose) {
    // Compare left and right side landmarks
    final pairs = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle],
    ];

    double totalDiff = 0;
    int validPairs = 0;

    for (var pair in pairs) {
      final left = pose.landmarks[pair[0]];
      final right = pose.landmarks[pair[1]];
      if (left != null && right != null) {
        totalDiff += (left.y - right.y).abs();
        validPairs++;
      }
    }

    return validPairs > 0 ? 1.0 - (totalDiff / validPairs / 100) : 0.0;
  }

  double _calculateStabilityScore(Pose pose) {
    // Calculate stability based on key points movement
    final keyPoints = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    double totalMovement = 0;
    int validPoints = 0;

    for (var point in keyPoints) {
      final landmark = pose.landmarks[point];
      if (landmark != null) {
        totalMovement += landmark.likelihood;
        validPoints++;
      }
    }

    return validPoints > 0 ? totalMovement / validPoints : 0.0;
  }

  List<double> _calculateJointAngles(Pose pose) {
    // Calculate angles for major joints
    return [
      _calculateAngle(pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
      _calculateAngle(pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
      _calculateAngle(pose, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
      _calculateAngle(pose, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    ];
  }

  double _calculateAngle(Pose pose, PoseLandmarkType first, PoseLandmarkType mid, PoseLandmarkType last) {
    final firstLandmark = pose.landmarks[first];
    final midLandmark = pose.landmarks[mid];
    final lastLandmark = pose.landmarks[last];

    if (firstLandmark == null || midLandmark == null || lastLandmark == null) {
      return 0.0;
    }

    // Calculate vectors
    final a = [firstLandmark.x - midLandmark.x, firstLandmark.y - midLandmark.y];
    final b = [lastLandmark.x - midLandmark.x, lastLandmark.y - midLandmark.y];

    // Calculate angle using dot product
    final dot = a[0] * b[0] + a[1] * b[1];
    final magA = sqrt(a[0] * a[0] + a[1] * a[1]);
    final magB = sqrt(b[0] * b[0] + b[1] * b[1]);

    return acos(dot / (magA * magB)) * 180 / pi;
  }

  Future<void> _storeMetrics() async {
    try {
      await FirebaseFirestore.instance
          .collection('athletes')
          .doc(widget.athleteId)
          .collection('performance_data')
          .add(_currentMetrics);
    } catch (e) {
      print('Error storing metrics: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record Performance'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_isRecording) {
              _stopRecording();
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 9,
              child: _cameraController?.value.isInitialized == true
                  ? Stack(
                      children: [
                        // Camera preview
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          child: CameraPreview(_cameraController!),
                        ),
                        // Pose overlay
                        if (_detectedPoses.isNotEmpty && _imageSize != null)
                          CustomPaint(
                            painter: PosePainter(
                              poses: _detectedPoses,
                              imageSize: _imageSize!,
                              screenSize: MediaQuery.of(context).size,
                            ),
                          ),
                        // Recording indicator
                        if (_isRecording)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Recording',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Athlete name
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.athleteName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Initializing camera...'),
                        ],
                      ),
                    ),
            ),
            // Record button
            Container(
              padding: EdgeInsets.all(defaultPadding),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.fiber_manual_record,
                      size: 32,
                    ),
                    label: Text(
                      _isRecording ? 'Stop Recording' : 'Start Recording',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: defaultPadding * 2,
                        vertical: defaultPadding,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for drawing pose detection results
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final Size screenSize;
  final bool isAndroid = Platform.isAndroid;

  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green.withOpacity(0.8);

    for (final pose in poses) {
      // Draw connections between landmarks
      _drawPoseConnections(canvas, pose, paint);
      
      // Draw landmarks
      for (final landmark in pose.landmarks.values) {
        if (landmark.likelihood > 0.5) {  // Only draw high confidence landmarks
          final position = _translatePosition(
            landmark.x,
            landmark.y,
            imageSize,
            screenSize,
          );
          
          canvas.drawCircle(
            position,
            6,
            paint..color = Colors.red.withOpacity(0.8),
          );
        }
      }
    }
  }

  void _drawPoseConnections(Canvas canvas, Pose pose, Paint paint) {
    // Define connections between landmarks with colors
    final connections = [
      // Upper body
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, Colors.blue],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, Colors.green],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, Colors.green],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, Colors.green],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, Colors.green],
      // Torso
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, Colors.yellow],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, Colors.yellow],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, Colors.blue],
      // Lower body
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, Colors.purple],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, Colors.purple],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, Colors.purple],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, Colors.purple],
    ];

    for (final connection in connections) {
      final start = pose.landmarks[connection[0] as PoseLandmarkType];
      final end = pose.landmarks[connection[1] as PoseLandmarkType];
      final color = connection[2] as Color;

      if (start != null && end != null && 
          start.likelihood > 0.5 && end.likelihood > 0.5) {  // Only draw high confidence connections
        final startPos = _translatePosition(
          start.x,
          start.y,
          imageSize,
          screenSize,
        );
        final endPos = _translatePosition(
          end.x,
          end.y,
          imageSize,
          screenSize,
        );

        canvas.drawLine(
          startPos, 
          endPos, 
          paint..color = color.withOpacity(0.8),
        );
      }
    }
  }

  Offset _translatePosition(
    double x,
    double y,
    Size imageSize,
    Size screenSize,
  ) {
    // Handle the mirroring and rotation based on platform and camera
    if (isAndroid) {
      return Offset(
        screenSize.width - (x * screenSize.width / imageSize.width),
        y * screenSize.height / imageSize.height,
      );
    } else {
      return Offset(
        x * screenSize.width / imageSize.width,
        y * screenSize.height / imageSize.height,
      );
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
} 