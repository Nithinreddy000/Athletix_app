import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../constants.dart';
import '../../../models/injury_record.dart';
import '../../../services/medical_report_service.dart';
import '../../../../screens/enhanced_injury_visualization_screen.dart';

class InjuryVisualizationScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const InjuryVisualizationScreen({
    Key? key,
    required this.athleteId,
    required this.athleteName,
  }) : super(key: key);

  @override
  _InjuryVisualizationScreenState createState() => _InjuryVisualizationScreenState();
}

class _InjuryVisualizationScreenState extends State<InjuryVisualizationScreen> {
  final MedicalReportService _reportService = MedicalReportService();
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _selectedReport;
  String? _selectedInjury;
  bool _isLoading = true;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      setState(() => _isLoading = true);
      final reports = await _reportService.getMedicalReports(widget.athleteId);
      setState(() {
        _reports = reports;
        if (reports.isNotEmpty) {
          _selectedReport = reports.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reports: $e');
      setState(() => _isLoading = false);
    }
  }

  void _focusOnInjury(String bodyPart) {
    setState(() => _selectedInjury = bodyPart);
    
    // Call JavaScript function to focus on mesh
    if (_webViewController != null) {
      final meshName = _getMeshNameForBodyPart(bodyPart);
      _webViewController!.evaluateJavascript(
        "focusOnMesh('$meshName');"
      );
    }
  }

  String _getMeshNameForBodyPart(String bodyPart) {
    // Get the actual mesh name from the injury data
    final injuries = (_selectedReport!['injury_data'] as List?) ?? [];
    final injury = injuries.firstWhere(
      (i) => i['bodyPart'] == bodyPart,
      orElse: () => null
    );
    
    if (injury != null && injury['meshName'] != null) {
      return injury['meshName'];
    }
    
    // Fallback: return the body part name as is
    return bodyPart;
  }

  Widget _buildModelViewer() {
    if (_selectedReport == null) {
      return const Center(child: Text('No reports available'));
    }

    final modelUrl = _selectedReport!['model_url'] as String;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: ModelViewer(
        src: modelUrl,
        alt: "3D Injury Visualization",
        autoRotate: false,
        cameraControls: true,
        disableZoom: false,
        ar: false,
        backgroundColor: const Color.fromARGB(0, 0, 0, 0),
        relatedJs: '''
          const model = document.querySelector('model-viewer');
          
          // Store original material states
          let originalMaterials = new Map();
          let originalVisibility = new Map();
          
          model.addEventListener('load', () => {
            // Store original states when model loads
            const meshes = model.model.meshes;
            meshes.forEach(mesh => {
              originalMaterials.set(mesh.name, mesh.material);
              originalVisibility.set(mesh.name, mesh.visible);
            });
          });
          
          function resetView() {
            const meshes = model.model.meshes;
            meshes.forEach(mesh => {
              mesh.material = originalMaterials.get(mesh.name);
              mesh.visible = originalVisibility.get(mesh.name);
            });
            model.cameraOrbit = "0deg 75deg 105%";
            model.fieldOfView = "45deg";
          }
          
          function focusOnMesh(meshName) {
            const meshes = model.model.meshes;
            const targetMesh = meshes.find(m => m.name === meshName);
            
            if (!targetMesh) return;
            
            // Reset view first
            resetView();
            
            // Hide outer meshes that might obstruct view
            meshes.forEach(mesh => {
              if (mesh.name !== meshName) {
                // Check if mesh is in front of target mesh
                const distance = mesh.position.z - targetMesh.position.z;
                if (distance < 0) {
                  mesh.visible = false;
                }
              }
            });
            
            // Highlight target mesh
            targetMesh.material.opacity = 1.0;
            targetMesh.material.metalness = 0.3;
            targetMesh.material.roughness = 0.4;
            
            // Focus camera on mesh
            const box = targetMesh.boundingBox;
            const center = box.getCenter();
            const size = box.getSize();
            const maxDim = Math.max(size.x, size.y, size.z);
            const fov = model.fieldOfView;
            
            // Calculate ideal camera position
            const orbit = `${center.x}deg ${center.y}deg ${maxDim * 2}%`;
            model.cameraOrbit = orbit;
            model.fieldOfView = "30deg";
          }
        ''',
        onWebViewCreated: (controller) {
          // Store controller for later use
          _webViewController = controller;
        },
      ),
    );
  }

  Widget _buildInjuryList() {
    if (_selectedReport == null) return const SizedBox();
    
    final injuries = (_selectedReport!['injury_data'] as List?) ?? [];
    
    return Container(
      width: 300,
      child: Card(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: injuries.length,
          itemBuilder: (context, index) {
            final injury = injuries[index];
            final bodyPart = injury['bodyPart'];
            final status = injury['status'];
            final severity = injury['severity'];
            
            return ListTile(
              title: Text(bodyPart),
              subtitle: Text('$status - $severity'),
              trailing: IconButton(
                icon: const Icon(Icons.center_focus_strong),
                onPressed: () => _focusOnInjury(bodyPart),
                tooltip: 'Focus on injury',
              ),
              tileColor: _selectedInjury == bodyPart 
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildReportSelector() {
    return DropdownButton<Map<String, dynamic>>(
      value: _selectedReport,
      hint: const Text('Select Report'),
      items: _reports.map((report) {
        final date = DateTime.parse(report['timestamp'].toString());
        return DropdownMenuItem(
          value: report,
          child: Text('Report from ${date.toString().split(' ')[0]}'),
        );
      }).toList(),
      onChanged: (report) {
        setState(() {
          _selectedReport = report;
          _selectedInjury = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.athleteName} - Injury Visualization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.hd),
            onPressed: _selectedReport != null ? () => _openEnhancedVisualization() : null,
            tooltip: 'Open Enhanced HD Visualization',
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildReportSelector(),
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildModelViewer(),
              ),
              _buildInjuryList(),
            ],
          ),
    );
  }
  
  void _openEnhancedVisualization() {
    if (_selectedReport == null) return;
    
    final modelUrl = _selectedReport!['model_url'] as String;
    final injuries = (_selectedReport!['injury_data'] as List?)?.map((injury) => injury as Map<String, dynamic>).toList() ?? [];
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedInjuryVisualizationScreen(
          modelUrl: modelUrl,
          injuries: injuries,
          title: '${widget.athleteName} - Enhanced Visualization',
        ),
      ),
    );
  }
} 