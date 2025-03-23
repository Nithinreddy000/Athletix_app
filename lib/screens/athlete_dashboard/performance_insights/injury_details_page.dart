import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class InjuryDetailsPage extends StatefulWidget {
  final String athleteId;
  final String athleteName;
  final Map<String, dynamic> riskAnalysis;
  final Map<String, dynamic> interactionsAnalysis;
  final String initialTab;

  const InjuryDetailsPage({
    Key? key,
    required this.athleteId,
    required this.athleteName,
    required this.riskAnalysis,
    required this.interactionsAnalysis,
    required this.initialTab,
  }) : super(key: key);

  @override
  _InjuryDetailsPageState createState() => _InjuryDetailsPageState();
}

class _InjuryDetailsPageState extends State<InjuryDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.initialTab == 'Risk Analysis' ? 0 : 1,
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        title: Text(
          'Injury Analysis: ${widget.athleteName}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          labelPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          indicatorPadding: EdgeInsets.symmetric(horizontal: 16),
          tabs: [
            Tab(
              text: 'Risk Analysis',
              height: 40,
            ),
            Tab(
              text: 'Injury Interactions',
              height: 40,
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade900,
              Colors.grey.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRiskAnalysisContent(),
              _buildInteractionsContent(),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to parse a recommendation string from our structured format
  List<String> _parseRecommendation(String recommendation) {
    // Extract the content inside brackets
    final bracketPattern = RegExp(r'\[(.*?)\]');
    final match = bracketPattern.firstMatch(recommendation);
    
    if (match != null && match.group(1) != null) {
      // Split by comma but avoid splitting commas inside nested structures
      final content = match.group(1)!;
      List<String> items = [];
      
      // Simple splitting logic
      int startPos = 0;
      int depth = 0;
      
      for (int i = 0; i < content.length; i++) {
        if (content[i] == '[' || content[i] == '(') {
          depth++;
        } else if (content[i] == ']' || content[i] == ')') {
          depth--;
        } else if (content[i] == ',' && depth == 0) {
          items.add(content.substring(startPos, i).trim());
          startPos = i + 1;
        }
      }
      
      // Add the last item
      if (startPos < content.length) {
        items.add(content.substring(startPos).trim());
      }
      
      return items;
    }
    
    // If the recommendation doesn't match our pattern, return it as is
    return [recommendation];
  }

  Widget _buildRiskAnalysisContent() {
    if (widget.riskAnalysis.isEmpty) {
      return _buildEmptyState('No risk analysis data available');
    }

    final riskLevel = widget.riskAnalysis['risk_level'] as String? ?? 'unknown';
    
    // Handle risk_factors which might be a List or a Map
    List<dynamic> riskFactors = [];
    if (widget.riskAnalysis['risk_factors'] is List) {
      riskFactors = widget.riskAnalysis['risk_factors'] as List<dynamic>;
    } else if (widget.riskAnalysis['risk_factors'] is Map) {
      // If it's a map, extract values or keys depending on structure
      final factorsMap = widget.riskAnalysis['risk_factors'] as Map<dynamic, dynamic>;
      riskFactors = factorsMap.entries.map((e) => "${e.key}: ${e.value}").toList();
    }
    
    // Handle recommendations which might be a List or a Map
    List<dynamic> rawRecommendations = [];
    if (widget.riskAnalysis['recommendations'] is List) {
      rawRecommendations = widget.riskAnalysis['recommendations'] as List<dynamic>;
    } else if (widget.riskAnalysis['recommendations'] is Map) {
      final recommendationsMap = widget.riskAnalysis['recommendations'] as Map<dynamic, dynamic>;
      rawRecommendations = recommendationsMap.entries.map((e) => "${e.key}: ${e.value}").toList();
    }
    
    // Process recommendations to extract categories and items
    List<Map<String, dynamic>> recommendations = [];
    for (var rec in rawRecommendations) {
      final recStr = rec.toString();
      
      if (recStr.contains(':')) {
        // Find the first colon to split category from items
        final firstColonIndex = recStr.indexOf(':');
        final category = recStr.substring(0, firstColonIndex).trim();
        final items = _parseRecommendation(recStr.substring(firstColonIndex + 1).trim());
        
        recommendations.add({
          'category': category,
          'items': items,
        });
      } else {
        recommendations.add({
          'category': 'General Recommendations',
          'items': [recStr],
        });
      }
    }
    
    final bodyPartAssessment = widget.riskAnalysis['body_part_assessment'] as Map<String, dynamic>? ?? {};

    // Check for future injury probability
    final futureInjuryProbability = widget.riskAnalysis['future_injury_probability'] as Map<String, dynamic>? ?? {};
    final potentialInjuries = widget.riskAnalysis['potential_injuries'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall risk level
          _buildRiskLevelIndicator(riskLevel),
          const SizedBox(height: 20),
          
          // Body part breakdown
          if (bodyPartAssessment.isNotEmpty) ...[
            _buildSectionHeader('Affected Body Parts'),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: _buildBodyPartChart(bodyPartAssessment),
            ),
            const SizedBox(height: 20),
          ],
          
          // Risk factors
          if (riskFactors.isNotEmpty) ...[
            _buildSectionHeader('Risk Factors'),
            const SizedBox(height: 12),
            ...riskFactors.map((factor) => _buildInfoItem(
              factor.toString(),
              Icons.warning_amber_rounded,
              Colors.amber,
            )),
            const SizedBox(height: 20),
          ],
          
          // Future injury probability
          if (futureInjuryProbability.isNotEmpty) ...[
            _buildSectionHeader('Future Injury Probability'),
            const SizedBox(height: 12),
            _buildFutureInjuryProbability(futureInjuryProbability),
            const SizedBox(height: 20),
          ],
          
          // Potential injuries
          if (potentialInjuries.isNotEmpty) ...[
            _buildSectionHeader('Potential Injuries'),
            const SizedBox(height: 12),
            ...potentialInjuries.map((injury) => _buildPotentialInjuryCard(injury as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],
          
          // Recommendations - grouped by category
          if (recommendations.isNotEmpty) ...[
            _buildSectionHeader('Recommendations'),
            const SizedBox(height: 12),
            ...recommendations.map((rec) => _buildRecommendationCategory(
              rec['category'].toString(),
              rec['items'] as List<dynamic>,
            )),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionsContent() {
    if (widget.interactionsAnalysis.isEmpty) {
      return _buildEmptyState('No injury interaction data available');
    }

    // Extract active and past injuries
    var activeInjuries = widget.interactionsAnalysis['active_injuries'];
    var pastInjuries = widget.interactionsAnalysis['past_injuries'];
    
    // Extract interactions
    List<dynamic> interactions = [];
    if (widget.interactionsAnalysis['interactions'] is List) {
      interactions = widget.interactionsAnalysis['interactions'] as List<dynamic>;
    } else if (widget.interactionsAnalysis['interactions'] is Map) {
      // If it's a map, try to convert it to a list of maps
      final interactionsMap = widget.interactionsAnalysis['interactions'] as Map<dynamic, dynamic>;
      interactions = interactionsMap.entries.map((e) => {
        'title': e.key.toString(),
        'description': e.value is Map ? e.value['description'] ?? e.value.toString() : e.value.toString(),
        'impact': e.value is Map ? e.value['impact'] ?? 'Unknown' : 'Unknown',
        'recommendations': e.value is Map && e.value['recommendations'] != null ? e.value['recommendations'] : []
      }).toList();
    }
    
    final analysis = widget.interactionsAnalysis['analysis'] as String? ?? 'No analysis available';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active injuries section
          _buildSectionHeader('Current Injuries'),
          const SizedBox(height: 12),
          _buildInjuryList(activeInjuries, isActive: true),
          const SizedBox(height: 24),
          
          // Past injuries section
          _buildSectionHeader('Injury History'),
                    const SizedBox(height: 12),
          _buildInjuryList(pastInjuries, isActive: false),
          const SizedBox(height: 24),
          
          // Interactions section
          if (interactions.isNotEmpty) ...[
            _buildSectionHeader('Identified Interactions'),
            const SizedBox(height: 12),
            ...interactions.map((interaction) => _buildInteractionCard(interaction)),
            const SizedBox(height: 24),
          ],
          
          // Overall analysis
          _buildSectionHeader('Comprehensive Analysis'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: -3,
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: Colors.purple,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Analysis Summary',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                ),
              ),
            ],
          ),
            const SizedBox(height: 16),
                Text(
                  analysis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white54,
            size: 40,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyIndicator(String text) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white60,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.5),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInjuryList(dynamic injuries, {required bool isActive}) {
    if (injuries == null || injuries == 'none' || (injuries is List && injuries.isEmpty)) {
    return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
        ),
        child: Text(
          'No ${isActive ? 'current' : 'past'} injuries recorded.',
          style: TextStyle(
            color: Colors.white70,
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    // If it's just a string (not "none"), display it
    if (injuries is String) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
        ),
        child: Text(
          injuries,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      );
    }
    
    // Handle list of injuries
    if (injuries is List) {
      return Column(
        children: injuries.map<Widget>((injury) {
          // Try to extract structured data
          Map<String, dynamic> injuryData = {};
          
          if (injury is Map) {
            injuryData = injury as Map<String, dynamic>;
          } else if (injury is String) {
            // Try to parse if it's a string that might be formatted as key-value
            final parts = injury.split(':');
            if (parts.length > 1) {
              injuryData = {'body_part': parts[0].trim(), 'description': parts[1].trim()};
            } else {
              injuryData = {'description': injury};
            }
          }
          
          final bodyPart = injuryData['body_part'] ?? 'Unspecified';
          final description = injuryData['description'] ?? 'No details available';
          final severity = injuryData['severity'] ?? '';
          final date = injuryData['date'] ?? '';
          
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      color: isActive ? Colors.orange : Colors.blue,
                      size: 16,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        bodyPart,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (severity.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(severity).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          severity,
                          style: TextStyle(
                            color: _getSeverityColor(severity),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                if (date.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    'Date: $date',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
    
    // If it's a map, display key-value pairs
    if (injuries is Map) {
      final injuryMap = injuries as Map<dynamic, dynamic>;
      return Column(
        children: injuryMap.entries.map<Widget>((entry) {
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      color: isActive ? Colors.orange : Colors.blue,
                      size: 16,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
    
    // Fallback
    return Text(
      injuries.toString(),
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
    );
  }
  
  Color _getSeverityColor(String severity) {
    final lowercaseSeverity = severity.toLowerCase();
    if (lowercaseSeverity.contains('high') || lowercaseSeverity.contains('severe')) {
      return Colors.red;
    } else if (lowercaseSeverity.contains('medium') || lowercaseSeverity.contains('moderate')) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
  
  Widget _buildInteractionCard(dynamic interaction) {
    // Default values
    String title = 'Interaction';
    String description = 'No detailed description available.';
    String impact = 'Unknown';
    List<dynamic> recommendations = [];
    
    // Try to extract structured data
    if (interaction is Map) {
      final interactionMap = interaction as Map<dynamic, dynamic>;
      title = interactionMap['title']?.toString() ?? title;
      description = interactionMap['description']?.toString() ?? description;
      impact = interactionMap['impact']?.toString() ?? impact;
      
      if (interactionMap['recommendations'] is List) {
        recommendations = interactionMap['recommendations'] as List<dynamic>;
      } else if (interactionMap['recommendations'] != null) {
        recommendations = [interactionMap['recommendations']];
      }
    } else if (interaction is String) {
      description = interaction;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.teal.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  color: Colors.teal,
                  size: 18,
                ),
                SizedBox(width: 12),
                Expanded(
      child: Text(
                    title,
        style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (impact.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getImpactColor(impact).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      impact,
                      style: TextStyle(
                        color: _getImpactColor(impact),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                
                if (recommendations.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Recommendations:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
          fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.arrow_right,
                          color: Colors.teal,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rec.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getImpactColor(String impact) {
    final lowercaseImpact = impact.toLowerCase();
    if (lowercaseImpact.contains('high') || lowercaseImpact.contains('severe') || lowercaseImpact.contains('significant')) {
      return Colors.red;
    } else if (lowercaseImpact.contains('medium') || lowercaseImpact.contains('moderate')) {
      return Colors.orange;
    } else if (lowercaseImpact.contains('low') || lowercaseImpact.contains('minor')) {
      return Colors.green;
    } else {
      return Colors.blue;
    }
  }

  Widget _buildRiskLevelIndicator(String riskLevel) {
    Color color;
    IconData icon;
    String description;
    
    switch (riskLevel.toLowerCase()) {
      case 'high':
        color = Colors.red;
        icon = Icons.warning_rounded;
        description = 'Immediate attention required. High risk of injury progression or complications.';
        break;
      case 'medium':
        color = Colors.orange;
        icon = Icons.warning_amber_rounded;
        description = 'Monitoring required. Moderate risk of injury complications if not properly managed.';
        break;
      case 'low':
        color = Colors.green;
        icon = Icons.check_circle;
        description = 'Low risk of complications. Continue with standard recovery protocols.';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
        description = 'Risk level could not be determined with available data.';
    }
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Injury Risk',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riskLevel.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSummary(String analysis) {
    // Determine severity based on analysis text
    Color color = Colors.blue;
    IconData icon = Icons.info_outline;
    
    if (analysis.toLowerCase().contains('significant')) {
      color = Colors.red;
      icon = Icons.warning_rounded;
    } else if (analysis.toLowerCase().contains('should be monitored')) {
      color = Colors.orange;
      icon = Icons.warning_amber_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Analysis Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              analysis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyPartChart(Map<String, dynamic> bodyPartAssessment) {
    final bodyParts = bodyPartAssessment.keys.toList();
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: BouncingScrollPhysics(),
      itemCount: bodyParts.length,
      itemBuilder: (context, index) {
        final bodyPart = bodyParts[index];
        final assessmentValue = bodyPartAssessment[bodyPart];
        
        // Handle cases where assessment is just an integer score
        int recoveryProgress = 0;
        String riskLevel = 'unknown';
        
        if (assessmentValue is Map<String, dynamic>) {
          // If it's a map, extract values as before
          riskLevel = assessmentValue['risk_level'] as String? ?? 'unknown';
          recoveryProgress = assessmentValue['recovery_progress'] as int? ?? 0;
        } else if (assessmentValue is int) {
          // If it's just an integer score, determine risk level based on score
          recoveryProgress = assessmentValue;
          if (assessmentValue > 70) {
            riskLevel = 'high';
          } else if (assessmentValue > 40) {
            riskLevel = 'medium';
          } else {
            riskLevel = 'low';
          }
        }
        
        Color color;
        switch (riskLevel.toLowerCase()) {
          case 'high':
            color = Colors.red;
            break;
          case 'medium':
            color = Colors.orange;
            break;
          case 'low':
            color = Colors.green;
            break;
          default:
            color = Colors.grey;
        }
        
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black26,
                Colors.black12,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Glow effect in the background
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              bodyPart.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              riskLevel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Recovery Progress',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          // Background
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Progress
                          Container(
                            height: 8,
                            width: (160 - 24) * (recoveryProgress / 100), // Adjust for padding
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  recoveryProgress > 75 ? Colors.green : 
                                  recoveryProgress > 50 ? Colors.amber : Colors.red,
                                  recoveryProgress > 75 ? Colors.green.withGreen((Colors.green.green + 40).clamp(0, 255)) : 
                                  recoveryProgress > 50 ? Colors.amber.withRed((Colors.amber.red + 40).clamp(0, 255)) : 
                                  Colors.red.withRed((Colors.red.red + 40).clamp(0, 255)),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: (recoveryProgress > 75 ? Colors.green : 
                                         recoveryProgress > 50 ? Colors.amber : Colors.red).withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: -1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$recoveryProgress%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Icon(
                            recoveryProgress > 75 ? Icons.sentiment_very_satisfied : 
                            recoveryProgress > 50 ? Icons.sentiment_satisfied : 
                            Icons.sentiment_dissatisfied,
                            color: recoveryProgress > 75 ? Colors.green : 
                                  recoveryProgress > 50 ? Colors.amber : Colors.red,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationCategory(String category, List<dynamic> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Category header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: Colors.green,
                  size: 18,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatCategoryName(category),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Recommendation items
            Padding(
            padding: const EdgeInsets.all(16.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => _buildRecommendationItem(item.toString())).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Container(
              width: 6,
              height: 6,
                        decoration: BoxDecoration(
                color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        ),
                      ),
          SizedBox(width: 12),
                      Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatCategoryName(String category) {
    // Convert snake_case or camelCase to Title Case with spaces
    final spacedCategory = category
        .replaceAllMapped(RegExp(r'_([a-z])'), (match) => ' ${match.group(1)!.toUpperCase()}')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}');
    
    return spacedCategory.split(' ').map((word) => 
      word.length > 0 ? word[0].toUpperCase() + word.substring(1) : ''
    ).join(' ');
  }
  
  IconData _getCategoryIcon(String category) {
    if (category.contains('exercise')) {
      return Icons.fitness_center;
    } else if (category.contains('training')) {
      return Icons.directions_run;
    } else if (category.contains('recovery')) {
      return Icons.healing;
    } else if (category.contains('nutrition')) {
      return Icons.restaurant;
    } else if (category.contains('mental')) {
      return Icons.psychology;
    } else {
      return Icons.check_circle_outline;
    }
  }
  
  Widget _buildFutureInjuryProbability(Map<String, dynamic> probability) {
    final next30Days = probability['next_30_days'] as int? ?? 0;
    final next90Days = probability['next_90_days'] as int? ?? 0;
    final next6Months = probability['next_6_months'] as int? ?? 0;
    
    Color barColor(int prob) {
      if (prob > 70) return Colors.red;
      if (prob > 40) return Colors.orange;
      return Colors.green;
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
          Row(
            children: [
              Icon(Icons.assessment, color: Colors.blue, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reinjury Probability',
                              style: TextStyle(
                                color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // 30 days bar
          _buildProbabilityBar('Next 30 Days', next30Days, barColor(next30Days)),
          SizedBox(height: 12),
          
          // 90 days bar
          _buildProbabilityBar('Next 90 Days', next90Days, barColor(next90Days)),
          SizedBox(height: 12),
          
          // 6 months bar
          _buildProbabilityBar('Next 6 Months', next6Months, barColor(next6Months)),
        ],
      ),
    );
  }
  
  Widget _buildProbabilityBar(String label, int probability, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                            Text(
          '$label: $probability%',
                              style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Stack(
          children: [
            // Background
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Filled portion
                      Container(
              height: 10,
              width: (probability / 100) * (MediaQuery.of(context).size.width - 64), // Adjust for padding
                        decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: -1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPotentialInjuryCard(Map<String, dynamic> injury) {
    final bodyPart = injury['body_part'] as String? ?? '';
    final condition = injury['condition'] as String? ?? '';
    final probability = injury['probability'] as int? ?? 0;
    final preventionStrategies = injury['prevention_strategies'] as List<dynamic>? ?? [];
    
    Color cardColor;
    if (probability > 70) {
      cardColor = Colors.red;
    } else if (probability > 40) {
      cardColor = Colors.orange;
    } else {
      cardColor = Colors.blue;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                        child: Text(
                    '$condition ($bodyPart)',
                          style: TextStyle(
                      color: Colors.white,
                            fontWeight: FontWeight.bold,
                      fontSize: 13,
                          ),
                    overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardColor.withOpacity(0.3)),
                    ),
                    child: Text(
                    '$probability%',
                      style: TextStyle(
                      color: cardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Prevention strategies
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prevention Strategies:',
                  style: TextStyle(
                    color: Colors.white70,
                        fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                ...preventionStrategies.map((strategy) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check, color: cardColor, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strategy.toString(),
                          style: TextStyle(
                        color: Colors.white,
                            fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
                )),
          ],
        ),
          ),
        ],
      ),
    );
  }
} 