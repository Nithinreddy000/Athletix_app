import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../services/performance_service.dart';
import '../../../models/performance_models.dart';
import 'recording_screen.dart';

class RecordingSetupScreen extends StatefulWidget {
  @override
  _RecordingSetupScreenState createState() => _RecordingSetupScreenState();
}

class _RecordingSetupScreenState extends State<RecordingSetupScreen> {
  String _selectedMode = 'single';
  String _selectedSport = 'basketball'; // Default sport
  bool _isMainRecorder = true;
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  String? _selectedPosition = 'front';
  bool _showAdvancedSettings = false;

  // Sport-specific recording templates
  final Map<String, Map<String, dynamic>> _sportTemplates = {
    'basketball': {
      'positions': ['court_side', 'baseline', 'overhead'],
      'guidelines': [
        'Position camera at court sideline for team plays',
        'Use baseline view for shooting analysis',
        'Ensure full court visibility for team mode',
        'Keep camera stable during fast breaks',
      ],
      'metrics': ['shooting_form', 'player_spacing', 'defensive_stance'],
    },
    'athletics': {
      'positions': ['side_view', 'front', 'finish_line'],
      'guidelines': [
        'Capture full running/jumping motion',
        'Position perpendicular to track for sprints',
        'Focus on take-off and landing for jumps',
        'Keep athlete centered in frame',
      ],
      'metrics': ['stride_length', 'take_off_angle', 'landing_position'],
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras[0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recording Setup'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sport Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Sport',
                      style: Theme.of(context).textTheme.headline6),
                    SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'basketball',
                          label: Text('Basketball'),
                          icon: Icon(Icons.sports_basketball),
                        ),
                        ButtonSegment(
                          value: 'athletics',
                          label: Text('Athletics'),
                          icon: Icon(Icons.directions_run),
                        ),
                      ],
                      selected: {_selectedSport},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          _selectedSport = selection.first;
                          _selectedPosition = _sportTemplates[_selectedSport]!['positions'][0];
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Recording Mode Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recording Mode',
                      style: Theme.of(context).textTheme.headline6),
                    SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'single',
                          label: Text('Single Player'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: 'team',
                          label: Text('Team'),
                          icon: Icon(Icons.group),
                        ),
                      ],
                      selected: {_selectedMode},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() => _selectedMode = selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Camera Setup
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Camera Setup',
                      style: Theme.of(context).textTheme.headline6),
                    SizedBox(height: 16),
                    
                    // Main/Secondary Selection
                    SwitchListTile(
                      title: Text('Main Recorder'),
                      subtitle: Text(_isMainRecorder 
                        ? 'This device will be the primary camera'
                        : 'This device will provide additional angles'),
                      value: _isMainRecorder,
                      onChanged: (value) {
                        setState(() => _isMainRecorder = value);
                      },
                    ),

                    // Camera Position Selection
                    if (!_isMainRecorder) ...[
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Camera Position',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedPosition,
                        items: _sportTemplates[_selectedSport]!['positions']
                          .map<DropdownMenuItem<String>>((String position) {
                            return DropdownMenuItem(
                              value: position,
                              child: Text(position.replaceAll('_', ' ').toUpperCase()),
                            );
                          }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedPosition = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Camera Preview
            if (_controller != null && _controller!.value.isInitialized)
              Container(
                height: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CameraPreview(_controller!),
                ),
              ),

            SizedBox(height: 16),

            // Sport-Specific Guidelines
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recording Guidelines',
                          style: Theme.of(context).textTheme.headline6),
                        Chip(
                          label: Text(_selectedSport.toUpperCase()),
                          backgroundColor: Theme.of(context).primaryColorLight,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    // Sport-specific guidelines
                    ..._sportTemplates[_selectedSport]!['guidelines'].map((guideline) {
                      return ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text(guideline),
                      );
                    }).toList(),
                    
                    Divider(),
                    
                    // General guidelines
                    ListTile(
                      leading: Icon(Icons.phone_android),
                      title: Text('Device Stability'),
                      subtitle: Text('Use tripod or stable surface'),
                    ),
                    ListTile(
                      leading: Icon(Icons.visibility),
                      title: Text('Field of View'),
                      subtitle: Text('Ensure complete motion capture'),
                    ),
                    ListTile(
                      leading: Icon(Icons.light_mode),
                      title: Text('Lighting'),
                      subtitle: Text('Uniform, well-lit environment'),
                    ),
                    ListTile(
                      leading: Icon(Icons.battery_charging_full),
                      title: Text('Device Preparation'),
                      subtitle: Text('Ensure full battery and storage space'),
                    ),
                  ],
                ),
              ),
            ),

            // Advanced Settings
            if (_showAdvancedSettings) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Advanced Settings',
                        style: Theme.of(context).textTheme.headline6),
                      SizedBox(height: 16),
                      
                      // Resolution Selection
                      DropdownButtonFormField<ResolutionPreset>(
                        decoration: InputDecoration(
                          labelText: 'Recording Quality',
                          border: OutlineInputBorder(),
                        ),
                        value: ResolutionPreset.high,
                        items: ResolutionPreset.values.map((preset) {
                          return DropdownMenuItem(
                            value: preset,
                            child: Text(preset.toString().split('.').last.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          // Update camera resolution
                        },
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Frame Rate Selection
                      DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'Frame Rate',
                          border: OutlineInputBorder(),
                        ),
                        value: 30,
                        items: [30, 60].map((fps) {
                          return DropdownMenuItem(
                            value: fps,
                            child: Text('$fps FPS'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          // Update frame rate
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: Icon(Icons.videocam),
                  label: Text('Start Recording'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    // Implement recording start logic
    if (_controller != null && !_controller!.value.isRecordingVideo) {
      try {
        await _controller!.startVideoRecording();
        // Navigate to recording screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecordingScreen(
              controller: _controller!,
              isMainRecorder: _isMainRecorder,
              recordingMode: _selectedMode,
              cameraPosition: _selectedPosition!,
            ),
          ),
        );
      } catch (e) {
        print('Error starting recording: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
} 