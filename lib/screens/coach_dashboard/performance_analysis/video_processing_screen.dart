import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants.dart';
import 'package:video_player/video_player.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class VideoProcessingScreen extends StatefulWidget {
  final String videoUrl;
  final String analysisId;

  const VideoProcessingScreen({
    Key? key,
    required this.videoUrl,
    required this.analysisId,
  }) : super(key: key);

  @override
  _VideoProcessingScreenState createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  late VideoPlayerController _controller;
  late Stream<DocumentSnapshot> _analysisStream;
  bool _isInitialized = false;
  String _status = 'Initializing...';
  double _progress = 0.0;
  List<Map<String, dynamic>> _currentPoseData = [];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _setupAnalysisStream();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.videoUrl);
    await _controller.initialize();
    setState(() {
      _isInitialized = true;
    });
    _controller.play();
    _controller.setLooping(true);
  }

  void _setupAnalysisStream() {
    _analysisStream = FirebaseFirestore.instance
        .collection('athletePerformanceAnalysis')
        .doc(widget.analysisId)
        .snapshots();

    _analysisStream.listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _status = data['status'] ?? 'Processing...';
        _progress = (data['progress'] ?? 0.0).toDouble();
        
        if (data['currentPoseData'] != null) {
          _currentPoseData = List<Map<String, dynamic>>.from(data['currentPoseData']);
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Processing Video'),
        backgroundColor: bgColor,
      ),
      body: Container(
        color: bgColor,
        child: Column(
          children: [
            if (_isInitialized)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_controller),
                    CustomPaint(
                      painter: PoseDetectionPainter(
                        poseData: _currentPoseData,
                        videoSize: _controller.value.size,
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _status,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(child: CircularProgressIndicator()),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Processing Steps:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: defaultPadding),
                    _buildProcessingStep(
                      'Pose Detection',
                      _progress >= 0.3,
                      _progress < 0.3 ? (_progress / 0.3) : 1.0,
                    ),
                    _buildProcessingStep(
                      'Form Analysis',
                      _progress >= 0.6,
                      _progress < 0.6 ? ((_progress - 0.3) / 0.3) : 1.0,
                    ),
                    _buildProcessingStep(
                      'Metrics Calculation',
                      _progress >= 0.9,
                      _progress < 0.9 ? ((_progress - 0.6) / 0.3) : 1.0,
                    ),
                    _buildProcessingStep(
                      'Generating Report',
                      _progress >= 1.0,
                      _progress < 1.0 ? ((_progress - 0.9) / 0.1) : 1.0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep(String title, bool isActive, double progress) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? primaryColor : Colors.grey[800],
            ),
            child: isActive
                ? Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isActive ? primaryColor : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PoseDetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> poseData;
  final Size videoSize;

  PoseDetectionPainter({
    required this.poseData,
    required this.videoSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var pose in poseData) {
      // Draw landmarks
      for (var landmark in pose['landmarks']) {
        final point = _normalizePoint(
          Offset(landmark['x'], landmark['y']),
          videoSize,
          size,
        );
        canvas.drawCircle(point, 4, paint);
      }

      // Draw connections
      for (var connection in pose['connections']) {
        final start = _normalizePoint(
          Offset(connection['start']['x'], connection['start']['y']),
          videoSize,
          size,
        );
        final end = _normalizePoint(
          Offset(connection['end']['x'], connection['end']['y']),
          videoSize,
          size,
        );
        canvas.drawLine(start, end, paint);
      }
    }
  }

  Offset _normalizePoint(Offset point, Size videoSize, Size canvasSize) {
    return Offset(
      point.dx * canvasSize.width / videoSize.width,
      point.dy * canvasSize.height / videoSize.height,
    );
  }

  @override
  bool shouldRepaint(PoseDetectionPainter oldDelegate) => true;
} 