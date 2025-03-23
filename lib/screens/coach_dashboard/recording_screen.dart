import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../services/performance_service.dart';
import '../../../models/performance_models.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'match_summary_screen.dart';

class RecordingScreen extends StatefulWidget {
  final CameraController controller;
  final bool isMainRecorder;
  final String recordingMode;
  final String cameraPosition;

  const RecordingScreen({
    Key? key,
    required this.controller,
    required this.isMainRecorder,
    required this.recordingMode,
    required this.cameraPosition,
  }) : super(key: key);

  @override
  _RecordingScreenState createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final PerformanceService _performanceService = PerformanceService();
  Timer? _analysisTimer;
  bool _isAnalyzing = false;
  Map<String, dynamic> _currentMetrics = {};
  List<String> _detectedAthletes = [];
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  List<PoseLandmark> _currentPose = [];
  Map<String, List<double>> _metricHistory = {};
  bool _showPoseOverlay = true;
  bool _showMetricsOverlay = true;
  String _currentFeedback = '';
  Color _feedbackColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
    _startDurationTimer();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration += Duration(seconds: 1);
      });
    });
  }

  void _startAnalysis() {
    _analysisTimer = Timer.periodic(Duration(milliseconds: 100), (_) async {
      if (!_isAnalyzing) {
        _isAnalyzing = true;
        try {
          final image = await widget.controller.takePicture();
          
          // Process frame for performance analysis
          final results = await _performanceService.processFrameWithAthleteIdentification(
            InputImage.fromFilePath(image.path),
            'current_session_id', // Replace with actual session ID
          );

          setState(() {
            _currentMetrics = results['metrics'] ?? {};
            _detectedAthletes = results['detected_athletes'] ?? [];
          });
        } catch (e) {
          print('Error analyzing frame: $e');
        } finally {
          _isAnalyzing = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            Container(
              height: double.infinity,
              child: CameraPreview(widget.controller),
            ),

            // Pose Overlay
            if (_showPoseOverlay && _currentPose.isNotEmpty)
              CustomPaint(
                painter: PoseOverlayPainter(
                  pose: _currentPose,
                  sportType: widget.recordingMode == 'team' ? 'basketball' : 'athletics',
                ),
              ),

            // Recording Info Overlay
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildRecordingInfo(),
            ),

            // Real-time Feedback
            if (_currentFeedback.isNotEmpty)
              Positioned(
                top: 70,
                left: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _feedbackColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _currentFeedback,
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Metrics Overlay
            if (_showMetricsOverlay && widget.isMainRecorder)
              Positioned(
                right: 16,
                top: 100,
                child: _buildEnhancedMetricsOverlay(),
              ),

            // Athletes Detection Overlay
            if (widget.recordingMode == 'team')
              Positioned(
                left: 16,
                top: 100,
                child: _buildAthletesOverlay(),
              ),

            // Recording Controls
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _buildAnalysisControls(),
                  SizedBox(height: 16),
                  _buildRecordingControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingInfo() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Recording Duration
          Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
              SizedBox(width: 8),
              Text(
                '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),

          // Recording Mode & Position
          Text(
            '${widget.recordingMode.toUpperCase()} | ${widget.cameraPosition}',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMetricsOverlay() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Live Metrics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.recordingMode == 'team' ? 'TEAM' : 'INDIVIDUAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ..._buildSportSpecificMetrics(),
        ],
      ),
    );
  }

  List<Widget> _buildSportSpecificMetrics() {
    if (widget.recordingMode == 'team') {
      return [
        _buildMetricTile('Team Spacing', _currentMetrics['spacing'] ?? 0, 'meters'),
        _buildMetricTile('Movement Speed', _currentMetrics['speed'] ?? 0, 'm/s'),
        _buildMetricTile('Formation', _currentMetrics['formation'] ?? 0, '%'),
      ];
    } else {
      if (_currentMetrics.isEmpty) return [];
      
      return _currentMetrics.entries.map((entry) {
        return _buildMetricTile(
          entry.key,
          entry.value,
          _getMetricUnit(entry.key),
        );
      }).toList();
    }
  }

  Widget _buildMetricTile(String name, double value, String unit) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
            style: TextStyle(color: Colors.white70),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(width: 4),
              Text(unit,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 8),
              _buildMetricTrend(name),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTrend(String metricName) {
    final history = _metricHistory[metricName] ?? [];
    if (history.length < 2) return Container();

    final lastValue = history.last;
    final previousValue = history[history.length - 2];
    final improvement = lastValue - previousValue;

    return Icon(
      improvement > 0 ? Icons.trending_up : Icons.trending_down,
      color: improvement > 0 ? Colors.green : Colors.red,
      size: 16,
    );
  }

  String _getMetricUnit(String metricName) {
    final units = {
      'speed': 'm/s',
      'angle': '°',
      'power': 'watts',
      'height': 'cm',
      'accuracy': '%',
    };
    return units[metricName.toLowerCase()] ?? '';
  }

  Widget _buildAnalysisControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnalysisToggle(
          icon: Icons.accessibility,
          label: 'Pose',
          value: _showPoseOverlay,
          onChanged: (value) => setState(() => _showPoseOverlay = value),
        ),
        SizedBox(width: 16),
        _buildAnalysisToggle(
          icon: Icons.analytics,
          label: 'Metrics',
          value: _showMetricsOverlay,
          onChanged: (value) => setState(() => _showMetricsOverlay = value),
        ),
      ],
    );
  }

  Widget _buildAnalysisToggle({
    required IconData icon,
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildAthletesOverlay() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detected Athletes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ..._detectedAthletes.map((athlete) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(athlete,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop Recording Button
          FloatingActionButton(
            onPressed: _stopRecording,
            backgroundColor: Colors.red,
            child: Icon(Icons.stop),
          ),

          // Pause/Resume Button
          FloatingActionButton(
            onPressed: _pauseResumeRecording,
            backgroundColor: Colors.white,
            child: Icon(
              widget.controller.value.isRecordingPaused
                  ? Icons.play_arrow
                  : Icons.pause,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRecording() async {
    try {
      final videoFile = await widget.controller.stopVideoRecording();
      
      // Process the recorded video
      // Navigate to summary screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MatchSummaryScreen(
            sessionId: 'current_session_id', // Replace with actual session ID
            teamId: 'team_id', // Replace with actual team ID
            sportType: widget.recordingMode == 'team' ? 'basketball' : 'athletics',
          ),
        ),
      );
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _pauseResumeRecording() async {
    try {
      if (widget.controller.value.isRecordingPaused) {
        await widget.controller.resumeVideoRecording();
        _startDurationTimer();
      } else {
        await widget.controller.pauseVideoRecording();
        _durationTimer?.cancel();
      }
      setState(() {});
    } catch (e) {
      print('Error pausing/resuming recording: $e');
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}

class PoseOverlayPainter extends CustomPainter {
  final List<PoseLandmark> pose;
  final String sportType;

  PoseOverlayPainter({required this.pose, required this.sportType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    // Draw connections between landmarks
    _drawPoseConnections(canvas, paint);

    // Draw landmarks
    paint.style = PaintingStyle.fill;
    for (var landmark in pose) {
      canvas.drawCircle(
        Offset(landmark.x, landmark.y),
        3.0,
        paint,
      );
    }

    // Draw sport-specific overlays
    if (sportType == 'basketball') {
      _drawBasketballOverlay(canvas, paint);
    } else if (sportType == 'athletics') {
      _drawAthleticsOverlay(canvas, paint);
    }
  }

  void _drawPoseConnections(Canvas canvas, Paint paint) {
    // Define connections between landmarks
    final connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      // ... add more connections
    ];

    for (var connection in connections) {
      final start = _getLandmark(connection[0]);
      final end = _getLandmark(connection[1]);
      if (start != null && end != null) {
        canvas.drawLine(
          Offset(start.x, start.y),
          Offset(end.x, end.y),
          paint,
        );
      }
    }
  }

  PoseLandmark? _getLandmark(PoseLandmarkType type) {
    return pose.firstWhere(
      (landmark) => landmark.type == type,
      orElse: () => null,
    );
  }

  void _drawBasketballOverlay(Canvas canvas, Paint paint) {
    // Add basketball-specific visual guides
    // Example: shooting form analysis lines
  }

  void _drawAthleticsOverlay(Canvas canvas, Paint paint) {
    // Add athletics-specific visual guides
    // Example: stride length indicators
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 