import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class InjuryData {
  final String id;
  final String bodyPart;
  final String side;
  final String injuryType;
  final String severity;
  final String status;
  final String description;
  final String colorCode;
  final Map<String, double> coordinates;
  final int recoveryProgress;
  final DateTime? lastUpdated;

  InjuryData({
    String? id,
    required this.bodyPart,
    required this.side,
    required this.injuryType,
    required this.severity,
    required this.status,
    required this.description,
    required this.colorCode,
    required this.coordinates,
    this.recoveryProgress = 0,
    this.lastUpdated,
  }) : id = id ?? UniqueKey().toString();

  factory InjuryData.fromJson(Map<String, dynamic> json) {
    // Handle bilateral injuries
    var coords = json['coordinates'];
    if (coords is List) {
      // For bilateral injuries, use the right side coordinates
      coords = coords[0];
    }

    return InjuryData(
      id: json['id'] ?? UniqueKey().toString(),
      bodyPart: json['bodyPart'] ?? '',
      side: json['side'] ?? 'center',
      injuryType: json['injuryType'] ?? '',
      severity: json['severity'] ?? '',
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      colorCode: json['colorCode'] ?? '#808080',
      coordinates: Map<String, double>.from(coords ?? {}),
      recoveryProgress: json['recoveryProgress'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? (json['lastUpdated'] is DateTime
              ? json['lastUpdated']
              : DateTime.parse(json['lastUpdated'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bodyPart': bodyPart,
        'side': side,
        'injuryType': injuryType,
        'severity': severity,
        'status': status,
        'description': description,
        'colorCode': colorCode,
        'coordinates': coordinates,
        'recoveryProgress': recoveryProgress,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  // Create a copy of the injury for the opposite side
  InjuryData createOppositeSide() {
    if (side != 'left' && side != 'right') return this;

    var newCoords = Map<String, double>.from(coordinates);
    newCoords['x'] = -coordinates['x']!;

    return InjuryData(
      bodyPart: bodyPart,
      side: side == 'left' ? 'right' : 'left',
      injuryType: injuryType,
      severity: severity,
      status: status,
      description: description,
      colorCode: colorCode,
      coordinates: newCoords,
      recoveryProgress: recoveryProgress,
      lastUpdated: lastUpdated,
    );
  }
}

class InjuryModelViewer extends ConsumerStatefulWidget {
  final List<InjuryData> injuries;
  final Function(InjuryData) onInjurySelected;

  const InjuryModelViewer({
    Key? key,
    required this.injuries,
    required this.onInjurySelected,
  }) : super(key: key);

  @override
  ConsumerState<InjuryModelViewer> createState() => _InjuryModelViewerState();
}

class _InjuryModelViewerState extends ConsumerState<InjuryModelViewer> {
  WebViewController? _controller;
  bool _isModelLoaded = false;
  bool _autoRotate = true;
  double _cameraOrbitSpeed = 30;

  List<InjuryData> get _processedInjuries {
    List<InjuryData> processed = [];
    for (var injury in widget.injuries) {
      processed.add(injury);
      if (injury.side == 'bilateral') {
        processed.add(injury.createOppositeSide());
      }
    }
    return processed;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModelViewer(
          src: 'assets/models/athlete.glb',
          alt: "A 3D athlete model",
          ar: true,
          autoRotate: _autoRotate,
          cameraControls: true,
          disableZoom: false,
          autoRotateDelay: 0,
          rotationPerSecond: "${_cameraOrbitSpeed}deg",
          fieldOfView: "45deg",
          minCameraOrbit: "auto auto 10%",
          maxCameraOrbit: "auto auto 100%",
          interpolationDecay: 200,
          backgroundColor: const Color.fromARGB(0, 255, 255, 255),
          relatedJs: const ['assets/js/model_viewer_interface.js'],
          onWebViewCreated: (controller) {
            _controller = controller;
            _setupJavaScriptChannels();
          },
          onModelLoaded: () {
            setState(() => _isModelLoaded = true);
            _updateInjuryMarkers();
          },
        ),
        if (!_isModelLoaded)
          const Center(
            child: CircularProgressIndicator(),
          ),
        Positioned(
          top: 16,
          right: 16,
          child: _buildControls(),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Auto-rotate'),
              Switch(
                value: _autoRotate,
                onChanged: (value) {
                  setState(() {
                    _autoRotate = value;
                  });
                },
              ),
            ],
          ),
          if (_autoRotate) ...[
            const Text('Rotation Speed'),
            Slider(
              value: _cameraOrbitSpeed,
              min: 10,
              max: 60,
              divisions: 5,
              label: '${_cameraOrbitSpeed.round()}°/s',
              onChanged: (value) {
                setState(() {
                  _cameraOrbitSpeed = value;
                });
                _controller?.runJavaScript(
                  'document.querySelector("model-viewer").setAttribute("rotation-per-second", "${value}deg")',
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller?.runJavaScript(
                'document.querySelector("model-viewer").cameraOrbit = "0deg 75deg 105%"',
              );
            },
            tooltip: 'Reset camera position',
          ),
        ],
      ),
    );
  }

  void _setupJavaScriptChannels() {
    if (_controller == null) return;

    _controller!.addJavaScriptChannel(
      'InjuryChannel',
      onMessageReceived: (message) {
        final injury = InjuryData.fromJson(jsonDecode(message.message));
        widget.onInjurySelected(injury);
      },
    );
  }

  void _updateInjuryMarkers() async {
    if (_controller == null || !_isModelLoaded) return;

    // Remove existing markers
    await _controller!.runJavaScript(
      'if (window.injuryMarkerManager) window.injuryMarkerManager.removeAllMarkers();',
    );

    // Add new markers for all injuries including bilateral ones
    for (var injury in _processedInjuries) {
      final injuryJson = jsonEncode(injury.toJson());
      await _controller!.runJavaScript(
        'if (window.injuryMarkerManager) window.injuryMarkerManager.addMarker($injuryJson);',
      );
    }
  }

  @override
  void didUpdateWidget(InjuryModelViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.injuries != oldWidget.injuries) {
      _updateInjuryMarkers();
    }
  }
} 