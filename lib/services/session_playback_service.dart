import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionPlaybackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _playbackTimer;
  List<Map<String, dynamic>> _sessionFrames = [];
  int _currentFrameIndex = 0;
  double _playbackSpeed = 1.0;
  bool _isPlaying = false;

  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  Future<void> loadSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('training_sessions')
          .doc(sessionId)
          .get();

      if (!doc.exists) {
        throw Exception('Session not found');
      }

      _sessionFrames = List<Map<String, dynamic>>.from(doc.get('frames') ?? []);
      _currentFrameIndex = 0;
    } catch (e) {
      print('Error loading session: $e');
      rethrow;
    }
  }

  void play({double speed = 1.0}) {
    if (_sessionFrames.isEmpty) return;

    _playbackSpeed = speed;
    _isPlaying = true;

    // Calculate frame interval based on speed
    final interval = (1000 / (30 * speed)).round(); // Assuming 30fps base rate

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: interval),
      (timer) {
        if (_currentFrameIndex >= _sessionFrames.length) {
          timer.cancel();
          _isPlaying = false;
          return;
        }

        _statsController.add(_sessionFrames[_currentFrameIndex]);
        _currentFrameIndex++;
      },
    );
  }

  void pause() {
    _playbackTimer?.cancel();
    _isPlaying = false;
  }

  void seek(Duration position) {
    final targetFrame = (position.inMilliseconds / (1000 / 30)).round();
    if (targetFrame >= 0 && targetFrame < _sessionFrames.length) {
      _currentFrameIndex = targetFrame;
      if (_isPlaying) {
        pause();
        play(speed: _playbackSpeed);
      }
    }
  }

  void setSpeed(double speed) {
    if (_isPlaying) {
      pause();
      play(speed: speed);
    } else {
      _playbackSpeed = speed;
    }
  }

  void dispose() {
    _playbackTimer?.cancel();
    _statsController.close();
  }
} 