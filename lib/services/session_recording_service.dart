import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class SessionRecordingService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final String coachId;
  final String athleteId;

  // Stream controllers for playback state
  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  final _currentFrameController = StreamController<SessionFrame>.broadcast();

  // Playback control variables
  Timer? _playbackTimer;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentFrameIndex = 0;
  List<SessionFrame> _sessionFrames = [];

  SessionRecordingService({
    required this.coachId,
    required this.athleteId,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Stream<PlaybackState> get playbackState => _playbackStateController.stream;
  Stream<SessionFrame> get currentFrame => _currentFrameController.stream;

  // Start recording a new session
  Future<String> startRecording(String sessionType) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await _firestore.collection('sessions').doc(sessionId).set({
      'coachId': coachId,
      'athleteId': athleteId,
      'sessionType': sessionType,
      'startTime': FieldValue.serverTimestamp(),
      'status': 'recording',
    });

    return sessionId;
  }

  // Add frame data during recording
  Future<void> addFrameData(String sessionId, SessionFrame frame) async {
    await _firestore.collection('sessions').doc(sessionId)
      .collection('frames').add(frame.toJson());
  }

  // End recording session
  Future<void> endRecording(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'endTime': FieldValue.serverTimestamp(),
      'status': 'completed',
    });
  }

  // Upload video file
  Future<void> uploadVideo(String sessionId, String videoPath) async {
    final videoRef = _storage.ref()
      .child('sessions/$sessionId/${path.basename(videoPath)}');
    
    await videoRef.putFile(File(videoPath));
    final videoUrl = await videoRef.getDownloadURL();

    await _firestore.collection('sessions').doc(sessionId).update({
      'videoUrl': videoUrl,
    });
  }

  // Load session for playback
  Future<void> loadSession(String sessionId) async {
    // Load session metadata
    final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
    final sessionData = sessionDoc.data()!;

    // Load all frames
    final framesQuery = await _firestore.collection('sessions')
      .doc(sessionId)
      .collection('frames')
      .orderBy('timestamp')
      .get();

    _sessionFrames = framesQuery.docs
      .map((doc) => SessionFrame.fromJson(doc.data()))
      .toList();

    _currentFrameIndex = 0;
    _isPlaying = false;
    _playbackSpeed = 1.0;

    // Notify initial state
    _updatePlaybackState();
    if (_sessionFrames.isNotEmpty) {
      _currentFrameController.add(_sessionFrames[0]);
    }
  }

  // Playback controls
  void play() {
    if (_sessionFrames.isEmpty) return;
    
    _isPlaying = true;
    _updatePlaybackState();
    
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: (33 ~/ _playbackSpeed)), // ~30fps
      (_) => _nextFrame(),
    );
  }

  void pause() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _updatePlaybackState();
  }

  void seek(double position) {
    if (_sessionFrames.isEmpty) return;
    
    _currentFrameIndex = (position * (_sessionFrames.length - 1)).round();
    _currentFrameIndex = _currentFrameIndex.clamp(0, _sessionFrames.length - 1);
    
    _currentFrameController.add(_sessionFrames[_currentFrameIndex]);
    _updatePlaybackState();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlaying) {
      play(); // Restart playback with new speed
    }
    _updatePlaybackState();
  }

  // Frame navigation
  void _nextFrame() {
    if (_currentFrameIndex < _sessionFrames.length - 1) {
      _currentFrameIndex++;
      _currentFrameController.add(_sessionFrames[_currentFrameIndex]);
      _updatePlaybackState();
    } else {
      pause(); // Stop at end
    }
  }

  void previousFrame() {
    if (_currentFrameIndex > 0) {
      _currentFrameIndex--;
      _currentFrameController.add(_sessionFrames[_currentFrameIndex]);
      _updatePlaybackState();
    }
  }

  void nextFrame() {
    if (_currentFrameIndex < _sessionFrames.length - 1) {
      _currentFrameIndex++;
      _currentFrameController.add(_sessionFrames[_currentFrameIndex]);
      _updatePlaybackState();
    }
  }

  // Get list of recorded sessions
  Stream<List<RecordedSession>> getRecordedSessions() {
    return _firestore.collection('sessions')
      .where('coachId', isEqualTo: coachId)
      .where('status', isEqualTo: 'completed')
      .orderBy('startTime', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => RecordedSession.fromJson({...doc.data(), 'id': doc.id}))
        .toList());
  }

  void _updatePlaybackState() {
    _playbackStateController.add(
      PlaybackState(
        isPlaying: _isPlaying,
        currentPosition: _currentFrameIndex / (_sessionFrames.length - 1),
        playbackSpeed: _playbackSpeed,
        totalFrames: _sessionFrames.length,
        currentFrameIndex: _currentFrameIndex,
      ),
    );
  }

  void dispose() {
    _playbackTimer?.cancel();
    _playbackStateController.close();
    _currentFrameController.close();
  }
}

class SessionFrame {
  final int timestamp;
  final Map<String, Map<String, double>> joints;
  final Map<String, double> metrics;

  SessionFrame({
    required this.timestamp,
    required this.joints,
    required this.metrics,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'joints': joints,
    'metrics': metrics,
  };

  factory SessionFrame.fromJson(Map<String, dynamic> json) => SessionFrame(
    timestamp: json['timestamp'] as int,
    joints: Map<String, Map<String, double>>.from(json['joints']),
    metrics: Map<String, double>.from(json['metrics']),
  );
}

class PlaybackState {
  final bool isPlaying;
  final double currentPosition; // 0.0 to 1.0
  final double playbackSpeed;
  final int totalFrames;
  final int currentFrameIndex;

  PlaybackState({
    required this.isPlaying,
    required this.currentPosition,
    required this.playbackSpeed,
    required this.totalFrames,
    required this.currentFrameIndex,
  });
}

class RecordedSession {
  final String id;
  final String coachId;
  final String athleteId;
  final String sessionType;
  final DateTime startTime;
  final DateTime endTime;
  final String? videoUrl;

  RecordedSession({
    required this.id,
    required this.coachId,
    required this.athleteId,
    required this.sessionType,
    required this.startTime,
    required this.endTime,
    this.videoUrl,
  });

  factory RecordedSession.fromJson(Map<String, dynamic> json) => RecordedSession(
    id: json['id'] as String,
    coachId: json['coachId'] as String,
    athleteId: json['athleteId'] as String,
    sessionType: json['sessionType'] as String,
    startTime: (json['startTime'] as Timestamp).toDate(),
    endTime: (json['endTime'] as Timestamp).toDate(),
    videoUrl: json['videoUrl'] as String?,
  );
} 