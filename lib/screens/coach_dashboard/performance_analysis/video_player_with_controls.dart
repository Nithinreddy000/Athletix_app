import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';                    // Dart APIs
import 'package:media_kit_video/media_kit_video.dart';        // Video widgets
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'dart:math';
import 'package:video_player/video_player.dart';
import 'dart:math' as math;

class VideoPlayerWithControls extends StatefulWidget {
  final String videoUrl;
  final List<Map<String, dynamic>>? poseData;

  const VideoPlayerWithControls({
    Key? key,
    required this.videoUrl,
    this.poseData,
  }) : super(key: key);

  @override
  _VideoPlayerWithControlsState createState() => _VideoPlayerWithControlsState();
}

class _VideoPlayerWithControlsState extends State<VideoPlayerWithControls> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late final Player _player;
  late final VideoController _controller;
  bool _isDrawingMode = false;
  bool _showPoseDetection = true;
  List<DrawingPath> _paths = [];
  DrawingPath? _currentPath;
  Color _currentColor = Colors.red;
  double _currentStrokeWidth = 3.0;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  Size _videoSize = const Size(1920, 1080);
  Offset? _lastPosition;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Add ValueNotifier for playing state
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isDrawingModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Color> _currentColorNotifier = ValueNotifier<Color>(Colors.red);
  final ValueNotifier<double> _strokeWidthNotifier = ValueNotifier<double>(3.0);
  final ValueNotifier<bool> _showPoseDetectionNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<List<DrawingPath>> _pathsNotifier = ValueNotifier<List<DrawingPath>>([]);
  final ValueNotifier<DrawingPath?> _currentPathNotifier = ValueNotifier<DrawingPath?>(null);
  final ValueNotifier<Offset?> _lastPositionNotifier = ValueNotifier<Offset?>(null);

  // Add a key for maintaining widget state
  final GlobalKey<_VideoPlayerWithControlsState> _playerKey = GlobalKey();
  
  // Create a shared state class
  final _sharedState = ValueNotifier<VideoPlayerSharedState>(
    VideoPlayerSharedState(
      paths: [],
      isDrawingMode: false,
      currentColor: Colors.red,
      strokeWidth: 3.0,
      showPoseDetection: true,
    ),
  );

  // Add these properties to the class
  Offset? _previewPosition;
  bool _isHovering = false;

  // Add new ValueNotifiers for video state
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isHoveringNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Offset?> _previewPositionNotifier = ValueNotifier<Offset?>(null);

  late VideoPlayerController _videoController;
  bool _showPose = true;
  bool _showAthletes = true;
  int _currentFrame = 0;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
    
    // Initialize state from shared state
    _pathsNotifier.value = _sharedState.value.paths;
    _isDrawingModeNotifier.value = _sharedState.value.isDrawingMode;
    _currentColorNotifier.value = _sharedState.value.currentColor;
    _strokeWidthNotifier.value = _sharedState.value.strokeWidth;
    _showPoseDetectionNotifier.value = _sharedState.value.showPoseDetection;
    
    // Add listeners to update shared state
    _pathsNotifier.addListener(_updateSharedState);
    _isDrawingModeNotifier.addListener(_updateSharedState);
    _currentColorNotifier.addListener(_updateSharedState);
    _strokeWidthNotifier.addListener(_updateSharedState);
    _showPoseDetectionNotifier.addListener(_updateSharedState);

    _initializeVideoPlayer();
  }

  void _updateSharedState() {
    _sharedState.value = VideoPlayerSharedState(
      paths: _pathsNotifier.value,
      isDrawingMode: _isDrawingModeNotifier.value,
      currentColor: _currentColorNotifier.value,
      strokeWidth: _strokeWidthNotifier.value,
      showPoseDetection: _showPoseDetectionNotifier.value,
    );
  }

  @override
  void dispose() {
    // Ensure proper cleanup
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _pathsNotifier.removeListener(_updateSharedState);
    _isDrawingModeNotifier.removeListener(_updateSharedState);
    _currentColorNotifier.removeListener(_updateSharedState);
    _strokeWidthNotifier.removeListener(_updateSharedState);
    _showPoseDetectionNotifier.removeListener(_updateSharedState);
    _sharedState.dispose();
    _isPlayingNotifier.dispose();
    _currentPathNotifier.dispose();
    _lastPositionNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _progressNotifier.dispose();
    _isHoveringNotifier.dispose();
    _previewPositionNotifier.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ensure all paths are using normalized coordinates
        final currentPaths = _pathsNotifier.value.map((path) {
          if (!path.isNormalized) {
            final videoRect = _getVideoRect(MediaQuery.of(context).size);
            return DrawingPath(
              color: path.color,
              strokeWidth: path.strokeWidth,
              points: path.points.map((point) => Offset(
                (point.dx - videoRect.left) / videoRect.width,
                (point.dy - videoRect.top) / videoRect.height,
              )).toList(),
              isNormalized: true,
            );
          }
          return path;
        }).toList();
        
        _pathsNotifier.value = currentPaths;
        _updateSharedState(); // Update shared state
      });
    }
  }

  void _initializePlayer() {
    _player = Player();
    _controller = VideoController(_player);
    
    _player.open(Media(widget.videoUrl), play: false);
    
    // Listen to player state changes
    _player.stream.playing.listen((playing) {
      if (mounted) {
        _isPlayingNotifier.value = playing;
      }
    });

    // Listen to position changes
    _player.stream.position.listen((position) {
      if (mounted) {
        _positionNotifier.value = position;
        final duration = _durationNotifier.value;
        if (duration.inMilliseconds > 0) {
          _progressNotifier.value = position.inMilliseconds / duration.inMilliseconds;
        }
      }
    });

    // Listen to duration changes
    _player.stream.duration.listen((duration) {
      if (mounted) {
        _durationNotifier.value = duration;
      }
    });
    
    // Listen to video dimensions
    _player.stream.width.listen((width) {
      if (mounted && width != null) {
        final height = _player.state.height ?? 1080;
    setState(() {
          _videoSize = Size(width.toDouble(), height.toDouble());
        });
      }
    });

    // Listen to video ready state
    _player.stream.videoParams.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // Listen to completion
    _player.stream.completed.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onDrawingModeChanged() {
    if (!_isDrawingModeNotifier.value) {
      _currentPathNotifier.value = null;
      _lastPositionNotifier.value = null;
    }
  }

  void _onColorChanged() {
    setState(() {
      _currentColor = _currentColorNotifier.value;
    });
  }

  Future<void> _toggleFullScreen() async {
    if (_isFullscreen) {
      // Save current state before exiting fullscreen
      final currentState = _sharedState.value;
      
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
    );
    
    if (mounted) {
    setState(() {
          _isFullscreen = false;
          // Restore state
          _pathsNotifier.value = currentState.paths;
          _isDrawingModeNotifier.value = currentState.isDrawingMode;
          _currentColorNotifier.value = currentState.currentColor;
          _strokeWidthNotifier.value = currentState.strokeWidth;
          _showPoseDetectionNotifier.value = currentState.showPoseDetection;
        });
        
        // Ensure video controller is properly reattached
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
    setState(() {
              _controller = VideoController(_player);
            });
          }
        });
        
        Navigator.of(context).pop();
      }
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      
      if (mounted) {
        setState(() => _isFullscreen = true);
        
        // Create a new route with preserved state
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: ValueListenableBuilder<VideoPlayerSharedState>(
                  valueListenable: _sharedState,
                  builder: (context, sharedState, _) {
                    return WillPopScope(
                      onWillPop: () async {
                        await _toggleFullScreen();
                        return false;
                      },
                      child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                          child: RepaintBoundary(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = Size(constraints.maxWidth, constraints.maxHeight);
                                return Stack(
                  children: [
                                    _buildContent(),
                                    _buildOverlays(context, size),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            opaque: true,
            maintainState: true,
            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
              return child;
            },
          ),
        );
      }
    }
  }

  void _handleDrawingGesture(Offset position, Size size) {
    if (!_isDrawingModeNotifier.value) return;

    final Rect videoRect = _getVideoRect(size);
    if (!videoRect.contains(position)) return;

    // Normalize coordinates relative to video rect
    final double normalizedX = (position.dx - videoRect.left) / videoRect.width;
    final double normalizedY = (position.dy - videoRect.top) / videoRect.height;
    final Offset normalizedPosition = Offset(normalizedX, normalizedY);

    if (_currentPathNotifier.value == null || 
        _lastPositionNotifier.value == null ||
        _getDistance(_lastPositionNotifier.value!, normalizedPosition) > 0.01) { // Reduced threshold for smoother lines
      // Start new path with improved stroke settings
      final newPath = DrawingPath(
        color: _currentColorNotifier.value.withOpacity(0.8), // Slightly transparent for better visibility
        strokeWidth: _strokeWidthNotifier.value * (videoRect.width / size.width) * 0.8, // Adjusted for better scaling
        points: [normalizedPosition],
        isNormalized: true,
      );
      _currentPathNotifier.value = newPath;
      final currentPaths = List<DrawingPath>.from(_pathsNotifier.value);
      currentPaths.add(newPath);
      _pathsNotifier.value = currentPaths;
      _updateSharedState();
    } else {
      // Improved interpolation for smoother lines
      _interpolatePoints(
        _lastPositionNotifier.value!,
        normalizedPosition,
        videoRect,
      );
    }
    _lastPositionNotifier.value = normalizedPosition;
  }

  double _getDistance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return sqrt(dx * dx + dy * dy);
  }

  void _interpolatePoints(Offset lastPoint, Offset currentPoint, Rect videoRect) {
    final currentPath = _currentPathNotifier.value;
    if (currentPath == null) return;

    final dx = currentPoint.dx - lastPoint.dx;
    final dy = currentPoint.dy - lastPoint.dy;
    final distance = sqrt(dx * dx + dy * dy);

    final List<Offset> newPoints = List.from(currentPath.points);

    if (distance > 0.002) { // Reduced threshold for more points
      final steps = (distance / 0.002).floor();
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        // Cubic interpolation for smoother curves
        final interpolatedX = _cubicInterpolate(lastPoint.dx, currentPoint.dx, t);
        final interpolatedY = _cubicInterpolate(lastPoint.dy, currentPoint.dy, t);
        newPoints.add(Offset(interpolatedX, interpolatedY));
      }
    } else {
      newPoints.add(currentPoint);
    }

    _currentPathNotifier.value = DrawingPath(
      color: currentPath.color,
      strokeWidth: currentPath.strokeWidth,
      points: newPoints,
      isNormalized: true,
    );

    final currentPaths = List<DrawingPath>.from(_pathsNotifier.value);
    currentPaths[currentPaths.length - 1] = _currentPathNotifier.value!;
    _pathsNotifier.value = currentPaths;
    _updateSharedState();
  }

  double _cubicInterpolate(double start, double end, double t) {
    // Cubic interpolation for smoother curves
    final t2 = t * t;
    final t3 = t2 * t;
    return start * (1 - 3 * t2 + 2 * t3) + end * (3 * t2 - 2 * t3);
  }

  Rect _getVideoRect(Size containerSize) {
    double width, height, left, top;
    
    final double containerAspectRatio = containerSize.width / containerSize.height;
    final double videoAspectRatio = _videoSize.width / _videoSize.height;
    
    if (containerAspectRatio > videoAspectRatio) {
      height = containerSize.height;
      width = height * videoAspectRatio;
      top = 0;
      left = (containerSize.width - width) / 2;
    } else {
      width = containerSize.width;
      height = width / videoAspectRatio;
      left = 0;
      top = (containerSize.height - height) / 2;
    }
    
    return Rect.fromLTWH(left, top, width, height);
  }

  Widget _buildContent() {
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoSize.width / _videoSize.height,
          child: Video(
            controller: _controller,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlays(BuildContext context, Size size) {
    return SizedBox.expand(
      child: Material(
        type: MaterialType.transparency,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isDrawingModeNotifier,
          builder: (context, isDrawingMode, _) {
            return ValueListenableBuilder<List<DrawingPath>>(
              valueListenable: _pathsNotifier,
              builder: (context, paths, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video tap handler
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          if (!isDrawingMode) {
                            if (_isPlayingNotifier.value) {
                              _player.pause();
                            } else {
                              _player.play();
                            }
                          }
                        },
                      ),
                    ),
                    // Drawing layers
                    if (paths.isNotEmpty)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: size,
                            painter: DrawingPainter(
                              paths: paths,
                              videoRect: _getVideoRect(size),
                            ),
                            isComplex: true,
                            willChange: true,
                          ),
                        ),
                      ),
                    // Drawing interaction layer
                    if (isDrawingMode)
                      Positioned.fill(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.precise,
                      child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) {
                              _currentPathNotifier.value = null;
                              _handleDrawingGesture(details.localPosition, size);
                            },
                            onPanUpdate: (details) {
                              _handleDrawingGesture(details.localPosition, size);
                            },
                            onPanEnd: (details) {
                              _currentPathNotifier.value = null;
                              _lastPositionNotifier.value = null;
                            },
                          ),
                        ),
                      ),
                    // Controls
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                        child: _buildDrawingToolbar(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildVideoControls(),
                    ),
                  ],
                );
              },
            );
          },
            ),
          ),
        );
  }

  Widget _buildDrawingToolbar() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isDrawingModeNotifier,
          builder: (context, isDrawingMode, _) {
            return ValueListenableBuilder<Color>(
              valueListenable: _currentColorNotifier,
              builder: (context, currentColor, _) {
                return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: isDrawingMode ? currentColor : Colors.white,
                      ),
                      onPressed: () {
                        _isDrawingModeNotifier.value = !isDrawingMode;
                      },
                      tooltip: 'Toggle Drawing Mode',
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: Colors.black87,
                        ),
                      ),
                      child: PopupMenuButton<Color>(
                        icon: Icon(Icons.color_lens, color: currentColor),
                        tooltip: 'Select Color',
                        itemBuilder: (_) => [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.white,
            ].map((color) => PopupMenuItem(
              value: color,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                              border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            )).toList(),
            onSelected: (color) {
                          _currentColorNotifier.value = color;
                        },
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _strokeWidthNotifier,
                        builder: (context, strokeWidth, _) {
                          return SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: currentColor,
                              thumbColor: currentColor,
              ),
              child: Slider(
                              value: strokeWidth,
                min: 1,
                max: 10,
                onChanged: (value) {
                                _strokeWidthNotifier.value = value;
                },
              ),
                          );
                },
            ),
          ),
          IconButton(
                      icon: const Icon(Icons.undo, color: Colors.white),
                      onPressed: _undoLastStroke,
                      tooltip: 'Undo Last Stroke',
          ),
          IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: _clearDrawing,
                      tooltip: 'Clear All',
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _showPoseDetectionNotifier,
                      builder: (context, showPoseDetection, _) {
                        return IconButton(
                          icon: Icon(
                            showPoseDetection ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
                          ),
                          onPressed: () {
                            _showPoseDetectionNotifier.value = !showPoseDetection;
                          },
                          tooltip: 'Toggle Pose Detection',
                        );
                      },
          ),
          IconButton(
                      icon: Icon(
                        _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
                      ),
                      onPressed: _toggleFullScreen,
                      tooltip: 'Toggle Fullscreen',
                    ),
                  ],
        );
      },
            );
          },
        ),
        ),
      );
    }

  Widget _buildVideoControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          color: Colors.black.withOpacity(0.5),
        child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
              ValueListenableBuilder<Duration>(
                valueListenable: _positionNotifier,
                builder: (context, position, _) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: _durationNotifier,
                    builder: (context, duration, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProgressBarLayers(position, duration),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _buildControlButtons(position, duration),
                          ),
                        ],
                      );
                    },
                  );
                },
            ),
          ],
        ),
        );
      },
      );
    }

  Widget _buildProgressBarLayers(Duration position, Duration duration) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ValueListenableBuilder<bool>(
          valueListenable: _isHoveringNotifier,
          builder: (context, isHovering, _) {
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => _isHoveringNotifier.value = true,
              onExit: (_) => _isHoveringNotifier.value = false,
              child: GestureDetector(
                onHorizontalDragStart: (details) {
                  if (!mounted) return;
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final Offset localPosition = box.globalToLocal(details.globalPosition);
                  _updateSeekPosition(localPosition.dx, constraints.maxWidth);
                },
                onHorizontalDragUpdate: (details) {
                  if (!mounted) return;
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final Offset localPosition = box.globalToLocal(details.globalPosition);
                  _updateSeekPosition(localPosition.dx, constraints.maxWidth);
                },
                onTapDown: (details) {
                  if (!mounted) return;
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final Offset localPosition = box.globalToLocal(details.globalPosition);
                  _updateSeekPosition(localPosition.dx, constraints.maxWidth);
                },
                child: Container(
                  height: 40,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Stack(
            children: [
                      // Background Track
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      // Playback Progress
                      ValueListenableBuilder<double>(
                        valueListenable: _progressNotifier,
                        builder: (context, progress, _) {
                          return FractionallySizedBox(
                            widthFactor: progress,
                child: Stack(
                              clipBehavior: Clip.none,
                  children: [
                                Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isHovering)
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: Container(
                                      width: 15,
                                      height: 15,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Hover Preview
                      ValueListenableBuilder<Offset?>(
                        valueListenable: _previewPositionNotifier,
                        builder: (context, previewPosition, _) {
                          if (!isHovering || previewPosition == null) return SizedBox.shrink();
                          return Positioned(
                            left: _clampPosition(previewPosition.dx - 40, constraints.maxWidth - 80),
                            top: -30,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ValueListenableBuilder<Duration>(
                                valueListenable: _durationNotifier,
                                builder: (context, duration, _) {
                                  return Text(
                                    _formatDuration(Duration(milliseconds: 
                                      _calculatePreviewPosition(previewPosition.dx, constraints.maxWidth, duration)
                                    )),
                                    style: TextStyle(
                        color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                      ),
                                  );
                                },
                    ),
                ),
                          );
                        },
              ),
            ],
                  ),
                ),
          ),
            );
          },
        );
      },
    );
  }

  void _updateSeekPosition(double dx, double maxWidth) {
    final duration = _durationNotifier.value;
    final double percent = dx / maxWidth;
    final newPosition = (duration.inMilliseconds * percent).round();
    _player.seek(Duration(milliseconds: newPosition));
    _previewPositionNotifier.value = Offset(dx, 0);
  }

  Widget _buildControlButtons(Duration position, Duration duration) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Row(
          mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                final currentPosition = _positionNotifier.value.inSeconds;
                _player.seek(Duration(seconds: currentPosition - 10));
              },
              tooltip: 'Backward 10s',
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isPlayingNotifier,
              builder: (context, isPlaying, _) {
                return IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                    size: 32,
              ),
                onPressed: () {
                    if (isPlaying) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                  tooltip: isPlaying ? 'Pause' : 'Play',
                );
                },
              ),
              IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                final currentPosition = _positionNotifier.value.inSeconds;
                _player.seek(Duration(seconds: currentPosition + 10));
              },
              tooltip: 'Forward 10s',
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: _positionNotifier,
              builder: (context, position, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: _durationNotifier,
                  builder: (context, duration, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          ' / ',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Length: ${_formatDuration(duration)}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            SizedBox(width: 16),
              IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleFullScreen,
              tooltip: 'Toggle Fullscreen',
            ),
          ],
        ),
      ],
    );
  }

  double _clampPosition(double position, double maxWidth) {
    return position.clamp(0, maxWidth);
  }

  int _calculatePreviewPosition(double x, double maxWidth, Duration duration) {
    final double percent = (x.clamp(0, maxWidth - 32)) / (maxWidth - 32);
    return (duration.inMilliseconds * percent).round();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  void _clearDrawing() {
    _pathsNotifier.value = [];
    _currentPathNotifier.value = null;
    _lastPositionNotifier.value = null;
  }

  void _undoLastStroke() {
    if (_pathsNotifier.value.isNotEmpty) {
      final currentPaths = List<DrawingPath>.from(_pathsNotifier.value);
      currentPaths.removeLast();
      _pathsNotifier.value = currentPaths;
    }
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        // Add listener for frame updates
        _videoController.addListener(_onVideoPositionChanged);
      });
  }

  void _onVideoPositionChanged() {
    if (!_videoController.value.isInitialized) return;
    
    // Calculate current frame based on video position and FPS
    final position = _videoController.value.position;
    final fps = _videoController.value.duration.inMilliseconds > 0
        ? _videoController.value.duration.inSeconds * 1000 / widget.poseData!.length
        : 30.0;
    
    final frame = (position.inMilliseconds / fps).floor();
    if (frame != _currentFrame) {
                  setState(() {
        _currentFrame = frame.clamp(0, widget.poseData!.length - 1);
      });
    }
  }

  Widget _buildPoseOverlay() {
    if (!_showPose || widget.poseData == null || _currentFrame >= widget.poseData!.length) {
      return Container();
    }

    final frameData = widget.poseData![_currentFrame];
    final landmarks = frameData['landmarks'] as List?;
    final connections = frameData['connections'] as List?;

    return CustomPaint(
      size: Size.infinite,
      painter: PosePainter(
        landmarks: landmarks?.cast<Map<String, dynamic>>() ?? [],
        connections: connections?.cast<List<int>>() ?? [],
        videoSize: _videoController.value.size,
        color: Colors.green,
      ),
    );
  }

  Widget _buildAthleteOverlay() {
    if (!_showAthletes || widget.poseData == null || _currentFrame >= widget.poseData!.length) {
      return Container();
    }

    final frameData = widget.poseData![_currentFrame];
    final athletes = Map<String, dynamic>.from(frameData)
      ..removeWhere((key, value) => ['landmarks', 'connections', 'metrics'].contains(key));

    return CustomPaint(
      size: Size.infinite,
      painter: AthletePainter(
        athletes: athletes,
        videoSize: _videoController.value.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Container(
          width: size.width,
          height: size.height,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildContent(),
              _buildOverlays(context, size),
              _buildPoseOverlay(),
              _buildAthleteOverlay(),
            ],
          ),
        );
      },
    );
  }
}

class DrawingPath {
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  final bool isNormalized;

  DrawingPath({
    required this.color,
    required this.strokeWidth,
    required this.points,
    this.isNormalized = false,
  });
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final Rect videoRect;

  DrawingPainter({
    required this.paths,
    required this.videoRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(videoRect);

    for (var path in paths) {
      if (path.points.length < 2) continue;
      
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final drawPath = Path();
      
      final firstPoint = path.isNormalized
          ? Offset(
              videoRect.left + path.points.first.dx * videoRect.width,
              videoRect.top + path.points.first.dy * videoRect.height,
            )
          : path.points.first;
      
      drawPath.moveTo(firstPoint.dx, firstPoint.dy);
      
      for (var i = 1; i < path.points.length; i++) {
        final point = path.isNormalized
            ? Offset(
                videoRect.left + path.points[i].dx * videoRect.width,
                videoRect.top + path.points[i].dy * videoRect.height,
              )
            : path.points[i];
        drawPath.lineTo(point.dx, point.dy);
      }
      
      canvas.drawPath(drawPath, paint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

class PosePainter extends CustomPainter {
  final List<Map<String, dynamic>> landmarks;
  final List<List<int>> connections;
  final Size videoSize;
  final Color color;

  PosePainter({
    required this.landmarks,
    required this.connections,
    required this.videoSize,
    this.color = Colors.green,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.fill;

    // Draw connections
    for (final connection in connections) {
      if (connection.length == 2) {
        final start = landmarks[connection[0]];
        final end = landmarks[connection[1]];
        
        if (start['visibility'] > 0.5 && end['visibility'] > 0.5) {
          canvas.drawLine(
            Offset(start['x'] * size.width, start['y'] * size.height),
            Offset(end['x'] * size.width, end['y'] * size.height),
            paint,
          );
        }
      }
    }

    // Draw landmarks
    for (final landmark in landmarks) {
      if (landmark['visibility'] > 0.5) {
        canvas.drawCircle(
          Offset(landmark['x'] * size.width, landmark['y'] * size.height),
          3,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}

class AthletePainter extends CustomPainter {
  final Map<String, dynamic> athletes;
  final Size videoSize;

  AthletePainter({
    required this.athletes,
    required this.videoSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    athletes.forEach((jerseyNumber, data) {
      if (data['bbox'] != null) {
        final bbox = data['bbox'] as List;
        final points = <Offset>[];
        
        // Convert normalized coordinates to actual coordinates
        for (final point in bbox) {
          points.add(Offset(
            point[0] * size.width,
            point[1] * size.height,
          ));
        }

        // Draw bounding box
        final path = Path()..addPolygon(points, true);
        canvas.drawPath(path, paint);

        // Draw athlete name
        final name = data['name'] as String;
        textPainter.text = TextSpan(
          text: name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            backgroundColor: Colors.black54,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          points.first.translate(0, -20), // Position above bounding box
        );
      }
    });
  }

  @override
  bool shouldRepaint(AthletePainter oldDelegate) => true;
}

class VideoPlayerSharedState {
  final List<DrawingPath> paths;
  final bool isDrawingMode;
  final Color currentColor;
  final double strokeWidth;
  final bool showPoseDetection;

  VideoPlayerSharedState({
    required this.paths,
    required this.isDrawingMode,
    required this.currentColor,
    required this.strokeWidth,
    required this.showPoseDetection,
  });
} 