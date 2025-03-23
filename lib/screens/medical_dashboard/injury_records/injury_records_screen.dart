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
import '../medical_dashboard_screen.dart';
import '../../../utils/dialog_helper.dart';
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
  
  List<Map<String, dynamic>> _athletes = [];
  Map<String, dynamic>? _selectedAthlete;
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _selectedReport;
  String? _selectedInjury;
  bool _isLoading = true;
  bool _isModelLoaded = false;
  final GlobalKey<ModelViewerPlusState> _viewerKey = GlobalKey<ModelViewerPlusState>();

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final athletes = await _athleteService.getAthletes();
      
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
          _selectedReport = reports.first;
          print('Selected report: ${_selectedReport!['id']}');
          
          // Log model URL for debugging
          final modelUrl = _selectedReport!['model_url'];
          print('Model URL for selected report: $modelUrl');
          
          // Automatically analyze any injuries with 0% recovery progress
          _autoAnalyzeInjuries(_selectedReport!);
        } else {
          _selectedReport = null;
          print('No reports available for this athlete');
        }
        _isModelLoaded = false;
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
      
      // Instead of constructing a specific path, use the path provided by the backend
      // but with proper formatting
      modelUrl = '${Config.apiBaseUrl}$modelUrl';
    }

    print('Loading model from URL: $modelUrl');
    print('Original model URL from report: ${_selectedReport!['model_url']}');

    // If we're loading a custom painted model, prepare a fallback to the standard model
    final bool isPaintedModel = modelUrl.contains('painted_model');
    final String fallbackModelUrl = isPaintedModel 
        ? '${Config.apiBaseUrl}/model/models/z-anatomy/Muscular.glb'
        : '';

    // If useEnhancedVisualization is true, use the enhanced model viewer
    if (widget.useEnhancedVisualization) {
      final injuries = (_selectedReport!['injury_data'] as List?)?.map((injury) => injury as Map<String, dynamic>).toList() ?? [];
      
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: EnhancedModelViewer(
          key: ValueKey(modelUrl), // Add key to force rebuild when URL changes
          modelUrl: modelUrl,
          fallbackModelUrl: fallbackModelUrl, // Add fallback URL
          injuries: injuries,
          onInjurySelected: (injury) {
            if (!mounted) return;
            setState(() => _selectedInjury = injury['bodyPart']);
          },
        ),
      );
    }

    // Otherwise, use the regular model viewer
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Stack(
        children: [
          ModelViewerPlus(
            key: _viewerKey,
            modelUrl: modelUrl,
            onModelLoaded: (success) {
              if (!mounted) return;
              setState(() => _isModelLoaded = success);
              if (!success) {
                print('Failed to load model: $modelUrl');
              } else {
                print('Model loaded successfully: $modelUrl');
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
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Model...\n${modelUrl.split('/').last}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
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

  Widget _buildAthleteSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButton<Map<String, dynamic>>(
        value: _selectedAthlete,
        hint: const Text('Select Athlete'),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        dropdownColor: secondaryColor,
        underline: const SizedBox(), // Remove underline
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: _athletes.map((athlete) {
          return DropdownMenuItem(
            value: athlete,
            child: Text(athlete['name']),
          );
        }).toList(),
        onChanged: _onAthleteSelected,
      ),
    );
  }

  Widget _buildReportSelector() {
    if (_reports.isEmpty) {
      return const Text('No reports available', style: TextStyle(color: Colors.white70));
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButton<Map<String, dynamic>>(
        value: _selectedReport,
        hint: const Text('Select Report'),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        dropdownColor: secondaryColor,
        underline: const SizedBox(), // Remove underline
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: _reports.map((report) {
          final date = (report['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final status = report['status'] ?? 'pending';
          return DropdownMenuItem(
            value: report,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: status == 'recovered' ? Colors.green :
                         status == 'active' ? Colors.red :
                         Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('Report from ${DateFormat('yyyy-MM-dd').format(date)}'),
              ],
            ),
          );
        }).toList(),
        onChanged: (report) {
          if (report != null) {
            setState(() {
              _selectedReport = report;
              _selectedInjury = null;
              _isModelLoaded = false;
            });
            
            // Auto-analyze injuries in the newly selected report
            Future.microtask(() => _autoAnalyzeInjuries(_selectedReport!));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor, // Set background color to match dashboard
      appBar: AppBar(
        title: const Text('3D Visualization'),
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 0, // Remove shadow for a sleeker look
        automaticallyImplyLeading: false, // Disable the automatic back button
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildAthleteSelector(),
          ),
          if (_selectedAthlete != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildReportSelector(),
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Container(
            padding: const EdgeInsets.all(defaultPadding),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildModelViewer(),
                ),
                _buildInjuryList(),
              ],
            ),
          ),
    );
  }

  void _showPaintedModel(String fileName) {
    String modelUrl = '';
    
    if (fileName.isNotEmpty) {
      modelUrl = '${Config.apiBaseUrl}/model/models/z-anatomy/output/$fileName';
    } else {
      // Fallback to default model if no painted model is available
      modelUrl = '${Config.apiBaseUrl}/model/models/z-anatomy/Muscular.glb';
    }
    
    // ... existing code ...
  }
} 