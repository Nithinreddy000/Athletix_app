import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../responsive.dart';
import 'financial/financial_management_dashboard.dart';
import 'financial/budget_analysis_dashboard.dart';
import '../shared/announcements_screen.dart';

class OrganisationDashboardScreen extends StatefulWidget {
  const OrganisationDashboardScreen({Key? key}) : super(key: key);

  @override
  _OrganisationDashboardScreenState createState() => _OrganisationDashboardScreenState();
}

class _OrganisationDashboardScreenState extends State<OrganisationDashboardScreen> {
  final Color darkColor = Color(0xFF1E1E2D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Organisation Dashboard'),
        backgroundColor: darkColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrganisationProfile(),
            SizedBox(height: defaultPadding * 2),
            Text(
              'Management Options',
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
              crossAxisCount: Responsive.isMobile(context) ? 1 : 3,
              crossAxisSpacing: defaultPadding,
              mainAxisSpacing: defaultPadding,
              children: [
                _buildDashboardCard(
                  title: 'Financial Management',
                  icon: Icons.account_balance_wallet,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FinancialManagementDashboard(),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Budget Analysis',
                  icon: Icons.bar_chart,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BudgetAnalysisDashboard(),
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
                        builder: (context) => SharedAnnouncementsScreen(userRole: 'Organisations'),
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
              child: SharedAnnouncementsScreen(userRole: 'Organisations'),
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
                size: 48,
                color: Colors.blue,
              ),
              SizedBox(height: defaultPadding),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
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
  
  Widget _buildOrganisationProfile() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.business, size: 40, color: Colors.white),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organisation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Welcome to your dashboard',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 