import 'package:flutter/material.dart';
import '../../../services/injury_analysis_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'injury_details_page.dart';

class InjuryAnalysisWidget extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const InjuryAnalysisWidget({
    Key? key,
    required this.athleteId,
    required this.athleteName,
  }) : super(key: key);

  @override
  _InjuryAnalysisWidgetState createState() => _InjuryAnalysisWidgetState();
}

class _InjuryAnalysisWidgetState extends State<InjuryAnalysisWidget> with SingleTickerProviderStateMixin {
  final InjuryAnalysisService _injuryAnalysisService = InjuryAnalysisService();
  bool _isLoading = true;
  Map<String, dynamic> _riskAnalysis = {};
  Map<String, dynamic> _interactionsAnalysis = {};
  String _selectedTab = 'Risk Analysis';
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadAnalysisData();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysisData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Show loading state for at least 1.5 seconds to indicate processing
      final startTime = DateTime.now();
      
      // Load both analyses in parallel
      final riskAnalysisFuture = _injuryAnalysisService.analyzeInjuryRisk(widget.athleteId);
      final interactionsAnalysisFuture = _injuryAnalysisService.analyzeInjuryInteractions(widget.athleteId);
      
      // Wait for both to complete
      final results = await Future.wait([riskAnalysisFuture, interactionsAnalysisFuture]);
      
      // Ensure minimum loading time for better UX
      final elapsedTime = DateTime.now().difference(startTime);
      if (elapsedTime < Duration(milliseconds: 1500)) {
        await Future.delayed(Duration(milliseconds: 1500) - elapsedTime);
      }
      
      setState(() {
        _riskAnalysis = results[0];
        _interactionsAnalysis = results[1];
        _isLoading = false;
      });
      
      _animationController.forward();
      
      print('Loaded risk analysis: ${_riskAnalysis.keys}');
      print('Loaded interactions analysis: ${_interactionsAnalysis.keys}');
    } catch (e) {
      print('Error loading injury analysis data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load analysis data. Please try again.';
      });
    }
  }

  void _navigateToDetailsPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => InjuryDetailsPage(
          athleteId: widget.athleteId,
          athleteName: widget.athleteName,
          riskAnalysis: _riskAnalysis,
          interactionsAnalysis: _interactionsAnalysis,
          initialTab: _selectedTab,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(minHeight: 600),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade900,
              Colors.grey.shade800,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adjust padding based on available width
            final horizontalPadding = constraints.maxWidth < 350 ? 8.0 : 16.0;
            final verticalPadding = constraints.maxWidth < 350 ? 8.0 : 16.0;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and refresh button
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, verticalPadding, horizontalPadding, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Injury Analysis: ${widget.athleteName}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth < 350 ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.white70, size: 20),
                        onPressed: _loadAnalysisData,
                        tooltip: 'Refresh analysis',
                        constraints: BoxConstraints.tightFor(width: 32, height: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                
                // Tab selection
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black26,
                    ),
                    padding: EdgeInsets.all(6),
                    child: Row(
                      children: [
                        _buildTabButton('Risk Analysis'),
                        const SizedBox(width: 12),
                        _buildTabButton('Injury Interactions'),
                      ],
                    ),
                  ),
                ),
                
                // Content based on selected tab
                if (_isLoading)
                  _buildLoadingState()
                else if (_errorMessage.isNotEmpty)
                  _buildErrorState()
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 12,
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: _selectedTab == 'Risk Analysis'
                                ? _buildCompactRiskAnalysisContent()
                                : _buildCompactInteractionsContent(),
                            ),
                          ),
                          // More details button inside the content container
                          Padding(
                            padding: EdgeInsets.only(
                              left: horizontalPadding,
                              right: horizontalPadding,
                              bottom: 16,
                              top: 8,
                            ),
                            child: _buildGlowButton(
                              onPressed: _navigateToDetailsPage,
                              icon: Icons.open_in_new,
                              label: 'More Details',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildGlowButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Flexible(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Analyzing injury data...',
                style: TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Flexible(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade300, size: 28),
              SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadAnalysisData,
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Try Again', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabName) {
    final isSelected = _selectedTab == tabName;
    
    return Expanded(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: isSelected ? LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withBlue(
                (Theme.of(context).primaryColor.blue + 40).clamp(0, 255)
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: -2,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedTab = tabName;
                _animationController.reset();
                _animationController.forward();
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  tabName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    letterSpacing: 0.5,
                    shadows: isSelected ? [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ] : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRiskAnalysisContent() {
    if (_riskAnalysis.isEmpty) {
      return _buildEmptyState('No risk analysis data available');
    }

    final riskLevel = _riskAnalysis['risk_level'] as String? ?? 'unknown';
    final riskFactors = _riskAnalysis['risk_factors'] as List<dynamic>? ?? [];
    final bodyPartAssessment = _riskAnalysis['body_part_assessment'] as Map<String, dynamic>? ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust padding based on available width
        final contentPadding = constraints.maxWidth < 300 ? 8.0 : 12.0;
        final verticalSpacing = constraints.maxWidth < 300 ? 8.0 : 10.0;
        
        return Container(
          padding: EdgeInsets.all(contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Risk level indicator
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: constraints.maxWidth < 300 ? 6.0 : 8.0, 
                  horizontal: constraints.maxWidth < 300 ? 8.0 : 12.0,
                ),
                decoration: BoxDecoration(
                  color: _getRiskLevelColor(riskLevel).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getRiskLevelColor(riskLevel).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _getRiskLevelColor(riskLevel),
                      size: constraints.maxWidth < 300 ? 16 : 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Risk Level: ${riskLevel.toUpperCase()}',
                      style: TextStyle(
                        color: _getRiskLevelColor(riskLevel),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth < 300 ? 14 : 16,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: verticalSpacing),
              
              // Summary stats - make responsive with LayoutBuilder
              // If width is too narrow, stack vertically
              if (constraints.maxWidth < 300)
                Column(
                  children: [
                    _buildStatItem(
                      'Risk Factors',
                      '${riskFactors.length}',
                      Icons.warning_amber_rounded,
                      Colors.amber,
                      isSmallScreen: true,
                    ),
                    SizedBox(height: 8),
                    _buildStatItem(
                      'Affected Areas',
                      '${bodyPartAssessment.length}',
                      Icons.accessibility_new,
                      Colors.blue,
                      isSmallScreen: true,
                    ),
                  ],
                )
              else
                // Otherwise use row layout
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Risk Factors',
                        '${riskFactors.length}',
                        Icons.warning_amber_rounded,
                        Colors.amber,
                        isSmallScreen: false,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Affected Areas',
                        '${bodyPartAssessment.length}',
                        Icons.accessibility_new,
                        Colors.blue,
                        isSmallScreen: false,
                      ),
                    ),
                  ],
                ),
              
              // Warning strip
              Container(
                margin: EdgeInsets.only(top: verticalSpacing * 1.5),
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: 8.0, 
                  horizontal: 12.0
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap "More Details" for complete analysis',
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCompactInteractionsContent() {
    if (_interactionsAnalysis.isEmpty) {
      return _buildEmptyState('No injury interaction data available');
    }

    final activeInjuries = _interactionsAnalysis['active_injuries'] as List<dynamic>? ?? [];
    final interactions = _interactionsAnalysis['interactions'] as List<dynamic>? ?? [];
    final analysis = _interactionsAnalysis['analysis'] as String? ?? 'No analysis available';

    // Determine severity color
    Color severityColor = Colors.blue;
    if (analysis.toLowerCase().contains('significant') || 
        interactions.any((i) => (i['impact_level'] as String? ?? '').toLowerCase() == 'high')) {
      severityColor = Colors.red;
    } else if (analysis.toLowerCase().contains('should be monitored') || 
               interactions.any((i) => (i['impact_level'] as String? ?? '').toLowerCase() == 'medium')) {
      severityColor = Colors.orange;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust padding based on available width
        final contentPadding = constraints.maxWidth < 300 ? 8.0 : 12.0;
        final verticalSpacing = constraints.maxWidth < 300 ? 8.0 : 10.0;
        
        return Container(
          padding: EdgeInsets.all(contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Analysis summary
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: constraints.maxWidth < 300 ? 6.0 : 8.0, 
                  horizontal: constraints.maxWidth < 300 ? 8.0 : 12.0
                ),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: severityColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      color: severityColor,
                      size: constraints.maxWidth < 300 ? 16 : 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Interactions: ${interactions.length}',
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.bold,
                          fontSize: constraints.maxWidth < 300 ? 14 : 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: verticalSpacing),
              
              // Summary stats
              if (constraints.maxWidth < 300)
                Column(
                  children: [
                    _buildStatItem(
                      'Active Injuries',
                      '${activeInjuries.length}',
                      Icons.healing,
                      Colors.red,
                      isSmallScreen: true,
                    ),
                    SizedBox(height: 8),
                    _buildStatItem(
                      'Interactions',
                      '${interactions.length}',
                      Icons.compare_arrows,
                      severityColor,
                      isSmallScreen: true,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Active Injuries',
                        '${activeInjuries.length}',
                        Icons.healing,
                        Colors.red,
                        isSmallScreen: false,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Interactions',
                        '${interactions.length}',
                        Icons.compare_arrows,
                        severityColor,
                        isSmallScreen: false,
                      ),
                    ),
                  ],
                ),
              
              // Warning strip
              Container(
                margin: EdgeInsets.only(top: verticalSpacing * 1.5),
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: 8.0, 
                  horizontal: 12.0
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap "More Details" for complete analysis',
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, {bool isSmallScreen = false}) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isSmallScreen ? 12 : 14),
              SizedBox(width: isSmallScreen ? 4 : 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 10 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white54,
              size: 28,
            ),
            SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskLevelColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }
} 