import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../services/performance_service.dart';
import '../../../services/performance_sync_service.dart';
import '../../../services/session_playback_service.dart';
import '../../../models/performance_models.dart';
import '../../../models/motion_data.dart';
import '../../../constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'dart:collection';
import 'dart:typed_data';
import 'video_upload_screen.dart';
import 'video_player_with_controls.dart';

class PerformanceAnalysisScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;
  final String? sportType;
  final String? sessionId;

  const PerformanceAnalysisScreen({
    Key? key,
    required this.athleteId,
    required this.athleteName,
    this.sportType,
    this.sessionId,
  }) : super(key: key);

  @override
  _PerformanceAnalysisScreenState createState() => _PerformanceAnalysisScreenState();
}

class _PerformanceAnalysisScreenState extends State<PerformanceAnalysisScreen> with SingleTickerProviderStateMixin {
  final PerformanceService _performanceService = PerformanceService();
  final PerformanceSyncService _syncService = PerformanceSyncService();
  final SessionPlaybackService _playbackService = SessionPlaybackService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Add pose detector
  late final mlkit.PoseDetector _poseDetector;
  
  // Date range for historical data
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Performance data
  Map<String, dynamic>? _trends;
  List<PerformanceData>? _performanceData;
  List<QueryDocumentSnapshot> _previousSessions = [];
  Map<String, dynamic> _athleteStats = {};
  List<Map<String, dynamic>> _currentSessionData = [];
  
  // Session state
  bool _isLiveSession = false;
  bool _isPlayingSession = false;
  String? _currentSessionId;
  double _playbackSpeed = 1.0;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  
  // Recording state
  bool _isLoading = true;
  ModelViewer? _modelViewer;
  final Queue<MotionData> _motionBuffer = Queue<MotionData>();
  static const int _bufferSize = 5;
  MotionData? _currentMotion;
  
  // Tab controller
  late TabController _tabController;

  // Add new fields for enhanced analysis
  Map<String, double> _currentScores = {
    'posture': 0.0,
    'symmetry': 0.0,
    'smoothness': 0.0,
    'range_of_motion': 0.0,
  };
  List<String> _currentRecommendations = [];
  bool _showOverlay = true;
  
  // Add new fields for session management
  String? _trainingArea;
  bool _multipleAthletesDetected = false;
  String? _selectedAthleteId;
  
  Size? _imageSize;

  String? _videoUrl;
  List<Map<String, dynamic>>? _poseData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializePoseDetector();
    _loadData();
    if (widget.sessionId != null) {
      _currentSessionId = widget.sessionId;
      _loadSessionData();
    }
    _setupLiveUpdates();
    _loadPreviousSessions();
    _setupPlaybackListeners();
  }

  Future<void> _loadSessionData() async {
    try {
      setState(() => _isLoading = true);

      // Load current session data if sessionId is provided
      if (widget.sessionId != null) {
        final doc = await _firestore
            .collection('athletePerformanceAnalysis')
            .doc(widget.sessionId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _videoUrl = data['videoUrl'] as String?;
            // Extract pose data if available
            if (data['poseData'] != null) {
              _poseData = List<Map<String, dynamic>>.from(data['poseData']);
            }
          });
        }
      }

      // Load previous sessions
      final sessionsQuery = await _firestore
          .collection('athletePerformanceAnalysis')
          .where('athleteId', isEqualTo: widget.athleteId)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      setState(() {
        _previousSessions = sessionsQuery.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading session data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _poseDetector.close();
    super.dispose();
  }

  Future<void> _initializePoseDetector() async {
    final options = mlkit.PoseDetectorOptions(
      mode: mlkit.PoseDetectionMode.stream,
      model: mlkit.PoseDetectionModel.accurate,
    );
    _poseDetector = mlkit.PoseDetector(options: options);
  }

  MotionData _convertPoseToMotionData(mlkit.Pose pose) {
    final joints = <String, JointPosition>{};
    final positions = <Point3D>[];
    final angles = <double>[];

    pose.landmarks.forEach((type, landmark) {
      if (landmark.likelihood > 0.5) {
        final point = Point3D(
          x: landmark.x,
          y: landmark.y,
          z: landmark.z,
        );

        final jointPosition = JointPosition(
          x: landmark.x,
          y: landmark.y,
          z: landmark.z,
          confidence: landmark.likelihood,
        );

        joints[type.name] = jointPosition;
        positions.add(point);
      }
    });

    return MotionData(
      joints: joints,
      jointPositions: positions,
      jointAngles: [],
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
  }

  void _updateMetrics(MotionData motionData) {
    if (_trends == null) {
      _trends = {};
    }

    // Calculate joint confidence
    double totalConfidence = motionData.joints.values
        .map((j) => j.confidence)
        .fold(0.0, (a, b) => a + b);
    double avgConfidence = totalConfidence / motionData.joints.length;

    // Calculate speed from joint positions
    double speed = 0.0;
    if (motionData.jointPositions.isNotEmpty) {
      var speeds = <double>[];
      for (var i = 1; i < motionData.jointPositions.length; i++) {
        var prev = motionData.jointPositions[i - 1];
        var curr = motionData.jointPositions[i];
        
        var distance = math.sqrt(
          math.pow(curr.x - prev.x, 2) +
          math.pow(curr.y - prev.y, 2) +
          math.pow(curr.z - prev.z, 2)
        );
        
        speeds.add(distance / 0.033); // Assuming 30fps
      }
      
      if (speeds.isNotEmpty) {
        speed = speeds.reduce((a, b) => a + b) / speeds.length;
      }
    }

    // Get additional metrics
    final jointMetrics = _performanceService.calculateJointMetrics(motionData);

    // Update trends with new values
    setState(() {
      _trends!['confidence'] = avgConfidence;
      _trends!['speed'] = speed;
      _trends!['symmetryScore'] = jointMetrics['symmetryScore'] ?? 0.0;
      _trends!['stabilityScore'] = jointMetrics['stabilityScore'] ?? 0.0;
      _trends!['rangeOfMotionScore'] = jointMetrics['rangeOfMotionScore'] ?? 0.0;
    });
  }

  void _updateModelAnimation(MotionData motionData) {
    // Update 3D model based on motion data
    if (_modelViewer != null) {
      setState(() {
        _modelViewer = ModelViewer(
          src: 'assets/models/athlete.glb',
          alt: '3D Athlete Model',
          ar: false,
          autoRotate: false,
          cameraControls: true,
          autoPlay: true,
          cameraTarget: _getCameraTarget(motionData),
          shadowIntensity: 1,
          exposure: 1.0,
        );
      });
    }
  }

  String _getCameraTarget(MotionData motionData) {
    if (motionData.joints.containsKey('spine')) {
      final spine = motionData.joints['spine']!;
      return '${spine.x}m ${spine.y}m ${spine.z}m';
    }
    return '0m 1m 0m'; // Default camera target
  }

  String _getAnimationData(MotionData motionData) {
    // Convert joint positions to animation data
    final positions = motionData.jointPositions;
    final angles = motionData.jointAngles;
    
    // Create animation keyframes
    List<Map<String, dynamic>> keyframes = [];
    
    // Add keyframe for each joint
    motionData.joints.forEach((jointName, position) {
      keyframes.add({
        'joint': jointName,
        'position': [position.x, position.y, position.z],
        'rotation': _getJointRotation(jointName, motionData),
      });
    });
    
    return keyframes.toString();
  }

  List<double> _getJointRotation(String jointName, MotionData motionData) {
    // Get rotation angles for specific joints
    if (jointName.contains('Shoulder')) {
      int index = motionData.joints.keys.toList().indexOf(jointName);
      if (index < motionData.jointAngles.length) {
        return [0, 0, motionData.jointAngles[index]];
      }
    }
    return [0, 0, 0]; // Default rotation
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final trends = await _performanceService.calculatePerformanceTrends(
        widget.athleteId,
        _startDate,
        _endDate,
      );
      final performanceData = await _performanceService.getAthletePerformanceData(
        widget.athleteId,
        _startDate,
        _endDate,
      );
      if (!mounted) return;
      setState(() {
        _trends = trends;
        _performanceData = performanceData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading performance data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _setupPlaybackListeners() {
    _playbackService.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _athleteStats = stats;
          _currentSessionData.add({
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            ...stats,
          });
        });
      }
    });
  }

  void _setupLiveUpdates() {
    _syncService.listenToActiveSession(widget.athleteId).listen((snapshot) {
      if (!mounted) return;
      
      if (!snapshot.exists) {
        print('No active session found for athlete ${widget.athleteId}');
        setState(() {
          _isLiveSession = false;
          _athleteStats = {};
          _currentSessionData.clear();
        });
        return;
      }

      try {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) {
          print('Session document exists but has no data');
          setState(() {
            _isLiveSession = false;
            _athleteStats = {};
            _currentSessionData.clear();
          });
          return;
        }

        final stats = data['stats'] as Map<String, dynamic>?;
        if (stats == null) {
          print('Session document has no stats field');
          setState(() {
            _isLiveSession = true;
            _athleteStats = {};
          });
        } else {
          setState(() {
            _isLiveSession = true;
            _athleteStats = Map<String, dynamic>.from(stats);
            _currentSessionData.add({
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              ..._athleteStats,
            });
          });
        }
      } catch (e, stackTrace) {
        print('Error processing session data: $e\n$stackTrace');
        setState(() {
          _isLiveSession = false;
          _athleteStats = {};
          _currentSessionData.clear();
        });
      }
    }, onError: (e, stackTrace) {
      print('Error in live session stream: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLiveSession = false;
        _athleteStats = {};
        _currentSessionData.clear();
      });
    });
  }

  void _loadPreviousSessions() {
    try {
      setState(() => _isLoading = true);
      
      // Query Firestore for all completed sessions
      FirebaseFirestore.instance
          .collection('athletePerformanceAnalysis')
          .where('athleteId', isEqualTo: widget.athleteId)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          final sessions = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['metrics'] != null;
          }).toList();
          
          setState(() {
            _previousSessions = sessions;
            _isLoading = false;
          });
        }
      }, onError: (e, stackTrace) {
        print('Error loading previous sessions: $e\n$stackTrace');
        
        if (e.toString().contains('requires an index')) {
        setState(() {
          _isLoading = false;
        _previousSessions = [];
          });
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Database Setup Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text('The application requires a database index to be created. Please contact your administrator with the following information:'),
                  SizedBox(height: 8),
              Text(
                    'Collection: athletePerformanceAnalysis\nFields to index:\n- athleteId (Ascending)\n- status (Ascending)\n- timestamp (Descending)',
                    style: TextStyle(fontFamily: 'monospace'),
                ),
            ],
          ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
            ),
        ],
      ),
    );
        } else {
      setState(() {
          _isLoading = false;
            _previousSessions = [];
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading previous sessions. Please try again later.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    } catch (e, stackTrace) {
      print('Error setting up previous sessions listener: $e\n$stackTrace');
        setState(() {
        _previousSessions = [];
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading previous sessions. Please try again later.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
      ),
    );
  }
  }

  String _formatDateTime(DateTime dateTime) {
    // Format date as "Jan 15, 2024 at 2:30 PM"
    final date = "${dateTime.day} ${_getMonthName(dateTime.month)}, ${dateTime.year}";
    final time = "${dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}";
    return "$date at $time";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _getSessionTitle(Map<String, dynamic> session) {
    final sessionType = session['sessionType'] as String? ?? 'Training';
    return '${sessionType.toUpperCase()} Session';
  }

  @override
  Widget build(BuildContext context) {
    // If no sessionId is provided, directly navigate to video upload
    if (widget.sessionId == null) {
      return VideoUploadScreen(
        athleteId: widget.athleteId,
        athleteName: widget.athleteName,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Performance Analysis - ${widget.athleteName}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_videoUrl != null) ...[
                    Container(
                      height: 400,
                      child: VideoPlayerWithControls(
                        videoUrl: _videoUrl!,
                        poseData: _poseData,
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Session Details Card
                  Card(
                    margin: EdgeInsets.all(16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 8),
                          if (_trends != null) ...[
                            _buildMetricTile('Form Score', _trends!['form_score']?.toDouble() ?? 0.0),
                            _buildMetricTile('Balance', _trends!['balance']?.toDouble() ?? 0.0),
                            _buildMetricTile('Symmetry', _trends!['symmetry']?.toDouble() ?? 0.0),
                            _buildMetricTile('Smoothness', _trends!['smoothness']?.toDouble() ?? 0.0),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Previous Sessions
                  if (_previousSessions.isNotEmpty)
                    Card(
                      margin: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Previous Sessions',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _previousSessions.length,
                            itemBuilder: (context, index) {
                              final session = _previousSessions[index].data() as Map<String, dynamic>;
                              final timestamp = (session['timestamp'] as Timestamp).toDate();
                              return ListTile(
                                title: Text(_getSessionTitle(session)),
                                subtitle: Text(_formatDateTime(timestamp)),
                                trailing: Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PerformanceAnalysisScreen(
                                        athleteId: widget.athleteId,
                                        athleteName: widget.athleteName,
                                        sessionId: _previousSessions[index].id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoUploadScreen(
                athleteId: widget.athleteId,
                athleteName: widget.athleteName,
              ),
            ),
          );
        },
        label: Text('Upload New Video'),
        icon: Icon(Icons.upload),
      ),
    );
  }

  Widget _buildMetricTile(String title, double value) {
    return ListTile(
      title: Text(title),
      trailing: Text(value.toStringAsFixed(2)),
    );
  }
}

class PoseOverlayPainter extends CustomPainter {
  final MotionData? currentMotion;
  final Size? imageSize;

  PoseOverlayPainter({
    required this.currentMotion,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (currentMotion == null || imageSize == null) return;

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw joints and connections
    currentMotion!.jointPositions.forEach((position) {
      final scaledPoint = _scalePoint(
        Offset(position.dx, position.dy),
        imageSize!,
        size,
      );
      canvas.drawCircle(scaledPoint, 4, paint);
    });
  }

  Offset _scalePoint(Offset point, Size imageSize, Size canvasSize) {
    return Offset(
      point.dx * canvasSize.width / imageSize.width,
      point.dy * canvasSize.height / imageSize.height,
    );
  }

  @override
  bool shouldRepaint(PoseOverlayPainter oldDelegate) {
    return oldDelegate.currentMotion != currentMotion;
  }
}