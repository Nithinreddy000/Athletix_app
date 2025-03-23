import 'package:flutter/material.dart';
import '../../../services/medical_report_service.dart';
import '../../../services/athlete_service.dart';
import 'injury_visualization_screen.dart';
import 'injury_records_screen.dart';
import '../../../../screens/enhanced_injury_visualization_screen.dart';
import '../../../constants.dart';

class AthletesInjuryRecordsScreen extends StatefulWidget {
  const AthletesInjuryRecordsScreen({Key? key}) : super(key: key);

  @override
  _AthletesInjuryRecordsScreenState createState() => _AthletesInjuryRecordsScreenState();
}

class _AthletesInjuryRecordsScreenState extends State<AthletesInjuryRecordsScreen> {
  final MedicalReportService _reportService = MedicalReportService();
  final AthleteService _athleteService = AthleteService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _athletesData = [];

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    try {
      setState(() => _isLoading = true);
      
      // Get all athletes
      final athletes = await _athleteService.getAthletes();
      
      // For each athlete, get their medical reports
      final athletesWithReports = await Future.wait(
        athletes.map((athlete) async {
          final reports = await _reportService.getMedicalReports(athlete['id']);
          final recentInjury = reports.isNotEmpty 
            ? _getMostRecentInjury(reports.first)
            : null;
            
          return {
            ...athlete,
            'recordCount': reports.length,
            'recentInjury': recentInjury,
          };
        })
      );
      
      setState(() {
        _athletesData = athletesWithReports;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading athletes: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _getMostRecentInjury(Map<String, dynamic> report) {
    final injuries = (report['injury_data'] as List?) ?? [];
    return injuries.isNotEmpty ? injuries.first : null;
  }

  Widget _buildAthleteCard(Map<String, dynamic> athlete) {
    final recentInjury = athlete['recentInjury'];
    final recordCount = athlete['recordCount'];
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => InjuryRecordsScreen(
                initialAthleteId: athlete['id'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: athlete['photoUrl'] != null
                              ? NetworkImage(athlete['photoUrl'])
                              : null,
                          child: athlete['photoUrl'] == null
                              ? Text(athlete['name'][0])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                athlete['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${recordCount} medical record(s)',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recordCount > 0)
                    IconButton(
                      icon: const Icon(Icons.hd),
                      tooltip: 'Open Enhanced HD Visualization',
                      onPressed: () => _openEnhancedVisualization(athlete),
                    ),
                ],
              ),
              if (recentInjury != null) ...[
                const Divider(),
                Text(
                  'Recent Injury:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${recentInjury['bodyPart']} - ${recentInjury['status']}',
                  style: TextStyle(
                    color: _getStatusColor(recentInjury['status']),
                  ),
                ),
                Text(
                  'Severity: ${recentInjury['severity']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'past':
        return Colors.orange;
      case 'recovered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _openEnhancedVisualization(Map<String, dynamic> athlete) async {
    try {
      setState(() => _isLoading = true);
      
      // Get the most recent report for this athlete
      final reports = await _reportService.getMedicalReports(athlete['id']);
      
      setState(() => _isLoading = false);
      
      if (reports.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No medical reports available for this athlete')),
        );
        return;
      }
      
      // Instead of navigating to EnhancedInjuryVisualizationScreen, navigate to InjuryRecordsScreen
      // with the initialAthleteId parameter
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InjuryRecordsScreen(
            initialAthleteId: athlete['id'],
            useEnhancedVisualization: true, // Add a flag to indicate enhanced visualization
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading visualization: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Athletes Injury Records'),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _athletesData.isEmpty
          ? const Center(child: Text('No athletes found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _athletesData.length,
              itemBuilder: (context, index) => _buildAthleteCard(_athletesData[index]),
            ),
    );
  }
} 