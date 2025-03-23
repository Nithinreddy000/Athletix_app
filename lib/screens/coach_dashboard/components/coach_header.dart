import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoachHeader extends StatefulWidget {
  @override
  _CoachHeaderState createState() => _CoachHeaderState();
}

class _CoachHeaderState extends State<CoachHeader> {
  String coachName = '';
  String teamName = '';

  @override
  void initState() {
    super.initState();
    _loadCoachInfo();
  }

  Future<void> _loadCoachInfo() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final DocumentSnapshot coachDoc = await FirebaseFirestore.instance
            .collection('coaches')
            .doc(currentUser.uid)
            .get();

        if (coachDoc.exists) {
          setState(() {
            coachName = coachDoc['name'] ?? '';
            teamName = coachDoc['teamName'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading coach info: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!Responsive.isMobile(context))
          Text(
            "Coach Dashboard",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        if (!Responsive.isMobile(context))
          Spacer(flex: Responsive.isDesktop(context) ? 2 : 1),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (!Responsive.isMobile(context)) ...[
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Icon(Icons.sports, color: Colors.white),
                  ),
                  SizedBox(width: defaultPadding),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      coachName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      teamName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
                if (!Responsive.isMobile(context))
                  Spacer(flex: Responsive.isDesktop(context) ? 2 : 1),
                _buildQuickActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionButton(
          icon: Icons.notifications_outlined,
          label: "Notifications",
          onPressed: () {
            // Handle notifications
          },
        ),
        SizedBox(width: defaultPadding),
        _buildActionButton(
          icon: Icons.add_circle_outline,
          label: "New Training",
          onPressed: () {
            // Handle new training creation
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}
