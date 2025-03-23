import 'package:flutter/material.dart';

class InjurySummaryPanel extends StatelessWidget {
  const InjurySummaryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: 5, // TODO: Replace with actual data
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: const Icon(Icons.person),
            ),
            title: const Text('John Doe'), // TODO: Replace with actual data
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ankle Sprain - Level 2',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text('Reported: Jan 15, 2024'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () {
                // TODO: Navigate to detailed view
              },
            ),
            onTap: () {
              // TODO: Navigate to detailed view
            },
          );
        },
      ),
    );
  }
} 