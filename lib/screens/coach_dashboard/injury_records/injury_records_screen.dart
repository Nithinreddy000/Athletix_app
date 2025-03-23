import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../services/medical_report_service.dart';
import '../../../services/athlete_service.dart';
import '../../../services/mesh_data_service.dart';
import '../../../services/ai_service.dart';
import '../../../widgets/model_viewer_plus_widget.dart';
import '../../../../screens/enhanced_injury_visualization_screen.dart';
import 'widgets/enhanced_model_viewer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../utils/dialog_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../config.dart';

class InjuryRecordsScreen extends StatefulWidget {
  final String? initialAthleteId;
  final bool useEnhancedVisualization;
  
  const InjuryRecordsScreen({
    Key? key,
    this.initialAthleteId,
    this.useEnhancedVisualization = false,
  }) : super(key: key);

  @override
  _InjuryRecordsScreenState createState() => _InjuryRecordsScreenState();
}

class _InjuryRecordsScreenState extends State<InjuryRecordsScreen> {
  final MedicalReportService _reportService = MedicalReportService();
  final AthleteService _athleteService = AthleteService();
  final MeshDataService _meshDataService = MeshDataService();
  final AIService _aiService = AIService();
  
  // Add Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Add darkColor variable
  final Color darkColor = Color(0xFF1E1E2D);
  
  List<Map<String, dynamic>> _athletes = [];
  Map<String, dynamic>? _selectedAthlete;
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _selectedReport;
  String? _selectedInjury;
  bool _isLoading = true;
  bool _isModelLoaded = false;
  final GlobalKey<ModelViewerPlusState> _viewerKey = GlobalKey<ModelViewerPlusState>();
  bool _isModelLoadingFailed = false;
  int _modelLoadingAttempts = 0;
  final int _maxModelLoadingAttempts = 3;
  Timer? _modelLoadingTimer;
  bool _isPreloadingModel = false;

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  @override
  void dispose() {
    _modelLoadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAthletes() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      // Get the current user (coach)
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No current user found');
        setState(() => _isLoading = false);
        return;
      }
      
      print('Loading athletes for coach ID: ${currentUser.uid}');
      
      // Get athletes under this coach
      final athletes = await _athleteService.getAthletesByCoach(currentUser.uid);
      
      if (!mounted) return;
      setState(() {
        _athletes = athletes;
        if (athletes.isNotEmpty) {
          // If initialAthleteId is provided, find that athlete
          if (widget.initialAthleteId != null) {
            _selectedAthlete = athletes.firstWhere(
              (a) => a['id'] == widget.initialAthleteId,
              orElse: () => athletes.first
            );
          } else {
            _selectedAthlete = athletes.first;
          }
        }
      });
      
      // Load reports for the selected athlete
      if (_selectedAthlete != null) {
        await _loadReports();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading athletes: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReports() async {
    if (_selectedAthlete == null) return;
    
    try {
      final athleteId = _selectedAthlete!['id'];
      print('Loading reports for athlete: ${_selectedAthlete!['name']} (ID: $athleteId)');
      
      if (!mounted) return;
      setState(() => _isLoading = true);
      final reports = await _reportService.getMedicalReports(athleteId);
      
      print('Loaded ${reports.length} reports for athlete $athleteId');
      
      if (!mounted) return;
      setState(() {
        _reports = reports;
        if (reports.isNotEmpty) {
          // Sort reports by date (newest first)
          _reports.sort((a, b) {
            final aDate = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bDate = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bDate.compareTo(aDate); // Newest first
          });
          
          // Automatically select the most recent report
          _selectedReport = _reports.first;
          print('Auto-selected most recent report: ${_selectedReport!['id']}');
          
          // Log model URL for debugging
          final modelUrl = _selectedReport!['model_url'];
          print('Model URL for selected report: $modelUrl');
          
          // Start preloading the model
          _preloadModel(modelUrl as String?);
          
          // Automatically analyze any injuries with 0% recovery progress
          _autoAnalyzeInjuries(_selectedReport!);
        } else {
          _selectedReport = null;
          print('No reports available for this athlete');
        }
        _isModelLoaded = false;
        _isModelLoadingFailed = false;
        _modelLoadingAttempts = 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reports: $e');
      if (!mounted) return;
      setState(() {
        _selectedReport = null;
        _isModelLoaded = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _autoAnalyzeInjuries(Map<String, dynamic> report) async {
    if (report == null) return;
    
    final reportId = report['id'];
    final List? injuryData = report['injury_data'] as List?;
    
    if (injuryData == null || injuryData.isEmpty) return;
    
    // Check if any injuries need analysis
    bool needsAnalysis = false;
    for (var injury in injuryData) {
      if (injury is Map<String, dynamic> && 
          (injury['recoveryProgress'] == null || injury['recoveryProgress'] == 0)) {
        needsAnalysis = true;
        break;
      }
    }
    
    // If no injuries need analysis, return early
    if (!needsAnalysis) return;
    
    // Show a subtle loading indicator that doesn't interfere with the model
    if (mounted) {
      // Use a more visible loading indicator at the top of the screen
      // This avoids interaction issues with the model
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Analyzing injuries with AI...'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blueGrey[800],
          behavior: SnackBarBehavior.floating, // Make it float to avoid model interference
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 20,
            right: 20,
          ),
        ),
      );
    }
    
    bool hasUpdates = false;
    final List<Map<String, dynamic>> updatedInjuries = [];
    
    // Process each injury
    for (var i = 0; i < injuryData.length; i++) {
      final injury = injuryData[i] as Map<String, dynamic>;
      
      // Only analyze injuries with no recovery progress
      if (injury['recoveryProgress'] == null || injury['recoveryProgress'] == 0) {
        try {
          final bodyPart = injury['bodyPart'] ?? 'Unknown';
          final side = injury['side'] ?? '';
          final severity = injury['severity'] ?? 'moderate';
          final description = injury['description'] ?? 'No description available';
          
          print('Auto-analyzing injury: $bodyPart ${side.isNotEmpty ? "($side)" : ""} - $severity');
          
          // Call the AI service to analyze the injury
          final result = await _aiService.analyzeInjury(
            reportId: reportId,
            description: description,
            bodyPart: bodyPart,
            severity: severity,
            side: side,
          );
          
          // Create updated injury with analysis results
          final updatedInjury = Map<String, dynamic>.from(injury);
          updatedInjury['recoveryProgress'] = result['recovery_progress'];
          updatedInjury['estimatedRecoveryTime'] = result['estimated_recovery_time'];
          updatedInjury['recommendedTreatment'] = result['recommended_treatment'];
          updatedInjury['lastUpdated'] = DateTime.now().toIso8601String();
          
          updatedInjuries.add(updatedInjury);
          hasUpdates = true;
          
          print('Updated injury: $bodyPart with recovery progress: ${result['recovery_progress']}%');
        } catch (e) {
          print('Error analyzing injury: $e');
          updatedInjuries.add(injury);
        }
      } else {
        updatedInjuries.add(injury);
      }
    }
    
    // Update the Firestore document if we have any updates
    if (hasUpdates) {
      try {
        final docRef = FirebaseFirestore.instance.collection('medical_reports').doc(reportId);
        await docRef.update({'injury_data': updatedInjuries});
        print('Updated report with AI analysis results');
        
        // Force reload the data to refresh the UI
        final updatedReports = await _reportService.getMedicalReports(_selectedAthlete?['id'] ?? '');
        final updatedReport = updatedReports.firstWhere(
          (r) => r['id'] == reportId,
          orElse: () => report
        );
        
        // Update the local report data and notify the UI
        if (mounted) {
          setState(() {
            _selectedReport = updatedReport;
            _reports = updatedReports;
          });
          
          // Show a success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analysis complete! Recovery progress updated.'),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error updating report: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating injury data: $e'),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      print('No updates needed for injuries');
    }
  }

  void _onAthleteSelected(Map<String, dynamic>? athlete) {
    if (athlete != null && athlete != _selectedAthlete) {
      print('Athlete selected: ${athlete['name']} (ID: ${athlete['id']})');
      
      if (!mounted) return;
      setState(() {
        _selectedAthlete = athlete;
        _selectedReport = null;
        _selectedInjury = null;
        _isModelLoaded = false;
        _reports = []; // Clear reports to avoid showing old reports during loading
      });
      
      _loadReports();
    }
  }

  void _focusOnInjury(Map<String, dynamic> injury) async {
    if (!_isModelLoaded) {
      print('Cannot focus on injury: Model not loaded yet');
      return;
    }

    if (!mounted) return;
    setState(() => _selectedInjury = injury['bodyPart']);
    
    try {
      final bodyPart = injury['bodyPart'];
      final status = injury['status'];
      final severity = injury['severity'];
      
      print('Focusing on injury: $bodyPart (status: $status, severity: $severity)');
      
      // Use the ModelViewerPlus instance to focus on the injury
      _viewerKey.currentState?.focusOnInjury(
        bodyPart,
        status: status,
        severity: severity,
      );
    } catch (e) {
      print('Error focusing on injury: $e');
    }
  }

  Future<void> _analyzeInjury({
    required String bodyPart,
    required String description,
    required String severity,
    String? injuryType,
  }) async {
    if (_selectedReport == null) return;
    
    final reportId = _selectedReport!['id'];
    
    // Show loading indicator
    DialogHelper.showLoadingDialog(
      context: context,
      message: 'Analyzing injury with AI...'
    );
    
    try {
      // Call the AI service to analyze the injury
      final result = await _aiService.analyzeInjury(
        reportId: reportId,
        description: description,
        bodyPart: bodyPart,
        severity: severity,
        side: injuryType,
      );
      
      // Remove loading dialog
      Navigator.of(context).pop();
      
      // Reload reports to reflect the updated recovery progress
      await _loadReports();
      
      // Show success dialog with the analysis results
      DialogHelper.showCustomDialog(
        context: context,
        dialog: AlertDialog(
          backgroundColor: secondaryColor,
          title: const Text('AI Analysis Complete', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recovery Progress:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${result['recovery_progress']}%', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const Text('Estimated Recovery Time:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(result['estimated_recovery_time'], style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const Text('Recommended Treatment:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(result['recommended_treatment'], style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      // Remove loading dialog
      Navigator.of(context).pop();
      
      // Show error dialog
      DialogHelper.showErrorDialog(
        context: context,
        title: 'Analysis Error',
        message: 'Failed to analyze injury: $e',
      );
    }
  }

  Future<void> _preloadModel(String? modelUrl) async {
    if (modelUrl == null || modelUrl.isEmpty) return;
    
    setState(() {
      _isPreloadingModel = true;
    });
    
    // Fix path separators - ensure forward slashes for web URLs
    modelUrl = modelUrl.replaceAll('\\', '/');
    
    if (!modelUrl.startsWith('http')) {
      // Make sure the URL starts with a slash if it doesn't have one
      if (!modelUrl.startsWith('/')) {
        modelUrl = '/$modelUrl';
      }
      
      // Use a direct URL to the model file
      final fileName = modelUrl.split('/').last;
      modelUrl = '${Config.apiBaseUrl}/model/models/z-anatomy/output/$fileName';
    }
    
    print('Preloading model from URL: $modelUrl');
    
    try {
      // Make a HEAD request to warm up the server and check if the model exists
      final response = await http.head(Uri.parse(modelUrl));
      if (response.statusCode == 200) {
        print('Model file exists and is ready to be loaded');
      } else {
        print('Warning: Model file may not exist. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error preloading model: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPreloadingModel = false;
        });
      }
    }
  }

  void _startModelLoadingTimer() {
    // Cancel any existing timer
    _modelLoadingTimer?.cancel();
    
    // Start a new timer for 120 seconds (increased from default)
    _modelLoadingTimer = Timer(Duration(seconds: 120), () {
      if (!mounted) return;
      if (!_isModelLoaded) {
        setState(() {
          _isModelLoadingFailed = true;
          _modelLoadingAttempts++;
        });
        print('Model loading timed out after 120 seconds. Attempt: $_modelLoadingAttempts');
      }
    });
  }
  
  void _retryModelLoading() {
    if (!mounted) return;
    setState(() {
      _isModelLoaded = false;
      _isModelLoadingFailed = false;
      _modelLoadingAttempts++;
    });
    
    // Start the timer again
    _startModelLoadingTimer();
    
    // Force rebuild the model viewer
    setState(() {});
  }

  Widget _buildModelViewer() {
    if (_selectedReport == null) {
      return const Center(
        child: Text(
          'No reports available for this athlete',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    String? modelUrl = _selectedReport!['model_url'] as String?;
    if (modelUrl == null || modelUrl.isEmpty) {
      return const Center(
        child: Text(
          'No 3D model available for this report',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // Fix path separators - ensure forward slashes for web URLs
    modelUrl = modelUrl.replaceAll('\\', '/');
    
    if (!modelUrl.startsWith('http')) {
      // Make sure the URL starts with a slash if it doesn't have one
      if (!modelUrl.startsWith('/')) {
        modelUrl = '/$modelUrl';
      }
      
      // Use a direct URL to the model file
      final fileName = modelUrl.split('/').last;
      modelUrl = '${Config.apiBaseUrl}/model/models/z-anatomy/output/$fileName';
    }

    print('Loading model from URL: $modelUrl');
    print('Original model URL from report: ${_selectedReport!['model_url']}');

    // If useEnhancedVisualization is true, use the enhanced model viewer
    if (widget.useEnhancedVisualization) {
      final injuries = (_selectedReport!['injury_data'] as List?)?.map((injury) => injury as Map<String, dynamic>).toList() ?? [];
      
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: EnhancedModelViewer(
          key: ValueKey('${modelUrl}_${_modelLoadingAttempts}'), // Add key to force rebuild when URL changes or retry
          modelUrl: modelUrl,
          injuries: injuries,
          onInjurySelected: (injury) {
            if (!mounted) return;
            setState(() => _selectedInjury = injury['bodyPart']);
          },
        ),
      );
    }

    // Start the model loading timer when building the model viewer
    _startModelLoadingTimer();

    // Otherwise, use the regular model viewer with improved loading experience
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Stack(
        children: [
          ModelViewerPlus(
            key: ValueKey('${modelUrl}_${_modelLoadingAttempts}'), // Add attempt count to force rebuild on retry
            modelUrl: modelUrl,
            onModelLoaded: (success) {
              // Cancel the timer since we got a response
              _modelLoadingTimer?.cancel();
              
              if (!mounted) return;
              setState(() {
                _isModelLoaded = success;
                _isModelLoadingFailed = !success;
              });
              
              if (!success) {
                print('Failed to load model: $modelUrl');
              } else {
                print('Model loaded successfully: $modelUrl');
                // Reset attempts counter on success
                _modelLoadingAttempts = 0;
              }
            },
            autoRotate: false,
            showControls: true,
          ),
          if (!_isModelLoaded)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isModelLoadingFailed 
                          ? 'Model Loading Failed' 
                          : 'Loading 3D Model...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isModelLoadingFailed
                          ? 'Please try again or check your connection'
                          : _isPreloadingModel 
                              ? 'Preparing model data...'
                              : 'This may take a few moments',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_modelLoadingAttempts > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Attempt ${_modelLoadingAttempts + 1} of ${_maxModelLoadingAttempts}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_isModelLoadingFailed) ...[
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Retry Loading'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _modelLoadingAttempts < _maxModelLoadingAttempts
                            ? _retryModelLoading
                            : null, // Disable after max attempts
                      ),
                    ] else ...[
                      // Show a loading progress indicator with percentage
                      Column(
                        children: [
                          Text(
                            'Loading may take up to 120 seconds',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 200,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.grey[800],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_modelLoadingAttempts >= _maxModelLoadingAttempts) ...[
                    const SizedBox(height: 16),
                    Text(
                        'Maximum retry attempts reached.\nPlease try again later.',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      textAlign: TextAlign.center,
                    ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInjuryList() {
    if (_selectedReport == null) return const SizedBox();
    
    final injuries = (_selectedReport!['injury_data'] as List?) ?? [];
    
    if (injuries.isEmpty) {
      return Container(
        width: 300,
        child: Card(
          color: secondaryColor, // Match dashboard theme
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No injuries found in this report',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: 300,
      child: Card(
        color: secondaryColor, // Match dashboard theme
        elevation: 2, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: injuries.length,
          itemBuilder: (context, index) {
            final injury = injuries[index];
            final bodyPart = injury['bodyPart'];
            final status = injury['status'];
            final severity = injury['severity'];
            final description = injury['description'] ?? 'No description';
            final recoveryProgress = injury['recoveryProgress'] ?? 0;
            final injuryType = injury['side'];
            
            final Color statusColor = status == 'recovered' ? Colors.green :
                       status == 'active' ? Colors.red :
                       Colors.orange;
            
            return ExpansionTile(
              leading: Icon(
                Icons.circle,
                size: 12,
                color: statusColor,
              ),
              title: Text('$bodyPart injury', style: TextStyle(color: Colors.white)),
              subtitle: Text('$status - $severity', style: TextStyle(color: Colors.white70)),
              backgroundColor: _selectedInjury == bodyPart 
                ? secondaryColor.withOpacity(0.6)
                : null,
              collapsedBackgroundColor: secondaryColor,
              onExpansionChanged: (expanded) {
                if (expanded) {
                  _focusOnInjury(injury);
                }
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(description),
                        const SizedBox(height: 8),
                      ],
                      const Text('Recovery Progress:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        child: LinearProgressIndicator(
                          value: recoveryProgress / 100,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$recoveryProgress%'),
                      
                      // Add estimated recovery time if available
                      if (injury['estimatedRecoveryTime'] != null) ...[
                        const SizedBox(height: 8),
                        const Text('Estimated Recovery Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(injury['estimatedRecoveryTime']),
                      ],
                      
                      // Add recommended treatment if available  
                      if (injury['recommendedTreatment'] != null) ...[
                        const SizedBox(height: 8),
                        const Text('Recommended Treatment:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(injury['recommendedTreatment']),
                      ],
                      
                      // Add last updated info if available
                      if (injury['lastUpdated'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last analyzed: ${_formatDate(injury['lastUpdated'])}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Helper method to format date strings
  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Injury Records'),
        backgroundColor: darkColor,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_athletes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No athletes found under your coaching',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              'Athletes assigned to you will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
      ),
    );
  }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar
        Container(
          width: 250,
          color: darkColor,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coach View',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Team Injury Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Athlete selection
              Text(
                'Select Athlete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
      decoration: BoxDecoration(
                  color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedAthlete?['id'],
                    isExpanded: true,
                    dropdownColor: Colors.grey[800],
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    style: const TextStyle(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAthlete = _athletes.firstWhere((a) => a['id'] == value);
                          _selectedReport = null;
                          _selectedInjury = null;
                          _isModelLoaded = false;
                        });
                        _loadReports();
                      }
                    },
                    items: _athletes.map((athlete) {
                      return DropdownMenuItem<String>(
                        value: athlete['id'],
            child: Row(
              children: [
                Icon(
                              Icons.person,
                              size: 16,
                              color: athlete['recordCount'] > 0 ? Colors.orange : Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                athlete['name'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (athlete['recordCount'] > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${athlete['recordCount']}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
              ],
            ),
          );
        }).toList(),
                  ),
                ),
              ),
              
              // Report selection
              if (_reports.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Medical Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedReport?['id'],
                      isExpanded: true,
                      dropdownColor: Colors.grey[800],
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onChanged: (value) {
                        if (value != null) {
            setState(() {
                            _selectedReport = _reports.firstWhere((r) => r['id'] == value);
              _selectedInjury = null;
              _isModelLoaded = false;
            });
                        }
                      },
                      items: _reports.map((report) {
                        final date = (report['timestamp'] as Timestamp?)?.toDate();
                        final formattedDate = date != null 
                          ? DateFormat('yyyy-MM-dd').format(date)
                          : 'Unknown date';
                        
                        return DropdownMenuItem<String>(
                          value: report['id'],
                          child: Text('Report from $formattedDate'),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ] else if (_selectedAthlete != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800]!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.healing_outlined, color: Colors.grey, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'No medical reports available for ${_selectedAthlete!['name']}',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              
              // Athlete info card
              if (_selectedAthlete != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Athlete Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.sports, size: 14, color: Colors.white70),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Sport: ${_selectedAthlete!['sport']}',
                              style: TextStyle(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
            ),
        ],
      ),
                      SizedBox(height: 4),
                      Row(
              children: [
                          Icon(Icons.numbers, size: 14, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            'Jersey: ${_selectedAthlete!['jerseyNumber']}',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.healing, size: 14, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            'Records: ${_selectedAthlete!['recordCount']}',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Main content area
                Expanded(
          child: _selectedReport != null
            ? _buildReportVisualization()
            : _buildNoReportSelected(),
        ),
      ],
    );
  }

  Widget _buildNoReportSelected() {
    if (_selectedAthlete == null) {
      return Center(
        child: Text('Please select an athlete to view their injury records'),
      );
    }
    
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.healing_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No injury records for ${_selectedAthlete!['name']}',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }
    
    return Center(
      child: Text('Select a medical report to view the 3D visualization'),
    );
  }

  Widget _buildReportVisualization() {
    if (_selectedReport == null) return const SizedBox();
    
    return _buildModelViewer();
  }
} 