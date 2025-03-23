import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import 'components/coach_header.dart';
import 'team_overview/team_overview.dart';
import 'performance_insights/performance_insights.dart';
import 'performance_insights/processed_video_display.dart';
import 'injury_updates/injury_updates.dart';
import 'training_planner/training_planner.dart';
import 'notifications/notifications_panel.dart';
import 'previous_sessions/previous_sessions_screen.dart';
import '../shared/announcements_screen.dart';

class CoachDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Coach Dashboard'),
        backgroundColor: Color(0xFF1E1E2D),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoachHeader(),
            SizedBox(height: defaultPadding * 2),
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: defaultPadding),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
              crossAxisSpacing: defaultPadding,
              mainAxisSpacing: defaultPadding,
              children: [
                _buildDashboardCard(
                  title: 'Team Overview',
                  icon: Icons.people,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamOverview(),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Performance Insights',
                  icon: Icons.insights,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PerformanceInsights(),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Training Planner',
                  icon: Icons.calendar_today,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrainingPlanner(),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Previous Sessions',
                  icon: Icons.history,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PreviousSessionsScreen(),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Injury Records',
                  icon: Icons.healing,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => injury_updates.InjuryUpdates(),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Announcements',
                  icon: Icons.announcement,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SharedAnnouncementsScreen(userRole: 'Coaches'),
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: defaultPadding * 2),
            Text(
              'Recent Announcements',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: defaultPadding),
            Container(
              height: 300,
              child: SharedAnnouncementsScreen(userRole: 'Coaches'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: secondaryColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: Colors.blue,
              ),
              SizedBox(height: defaultPadding),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
