import 'package:flutter/material.dart';
import 'package:admin/services/user_service.dart';

class UserStatsCards extends StatelessWidget {
  const UserStatsCards({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: UserService().getUserStatistics(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return GridView.count(
          crossAxisCount: 5,
          crossAxisSpacing: 16,
          shrinkWrap: true,
          children: [
            _StatCard(
              title: 'Total Users',
              count: stats['total'] ?? 0,
              color: Colors.blue,
              icon: Icons.people,
            ),
            _StatCard(
              title: 'Admins',
              count: stats['admin'] ?? 0,
              color: Colors.red,
              icon: Icons.admin_panel_settings,
            ),
            _StatCard(
              title: 'Coaches',
              count: stats['coach'] ?? 0,
              color: Colors.green,
              icon: Icons.sports,
            ),
            _StatCard(
              title: 'Athletes',
              count: stats['athlete'] ?? 0,
              color: Colors.orange,
              icon: Icons.fitness_center,
            ),
            _StatCard(
              title: 'Organizations',
              count: stats['organization'] ?? 0,
              color: Colors.purple,
              icon: Icons.business,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
} 