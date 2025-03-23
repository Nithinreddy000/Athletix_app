import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../../../services/user_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Responsive(
        mobile: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: ClipRect(
                      child: Column(
                        children: [
                          StatsGrid(userService: _userService),
                          const SizedBox(height: defaultPadding),
                          RecentAthletes(),
                          const SizedBox(height: defaultPadding),
                          UpcomingEvents(),
                          const SizedBox(height: defaultPadding),
                          Announcements(),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        tablet: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        StatsGrid(userService: _userService),
                        const SizedBox(height: defaultPadding),
                        RecentAthletes(),
                        const SizedBox(height: defaultPadding),
                        UpcomingEvents(),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        desktop: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                      child: Column(
                        children: [
                        StatsGrid(userService: _userService),
                          const SizedBox(height: defaultPadding),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                          RecentAthletes(),
                                  const SizedBox(height: defaultPadding),
                                  UpcomingEvents(),
                        ],
                    ),
                  ),
                  const SizedBox(width: defaultPadding),
                  Expanded(
                              flex: 1,
                              child: Announcements(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class StatsGrid extends StatelessWidget {
  final UserService userService;

  const StatsGrid({Key? key, required this.userService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: userService.getUserStatistics(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Text('Error: ${userSnapshot.error}');
        }

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final userStats = userSnapshot.data ?? {
          'total': 0,
          'athlete': 0,
          'coach': 0,
        };

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .where('date', isGreaterThan: DateTime.now())
              .snapshots(),
          builder: (context, eventSnapshot) {
            if (eventSnapshot.hasError) {
              return Text('Error: ${eventSnapshot.error}');
            }

            if (eventSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final activeEvents = eventSnapshot.data?.docs.length ?? 0;

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
            crossAxisSpacing: defaultPadding,
            mainAxisSpacing: defaultPadding,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) {
            List<Map<String, dynamic>> stats = [
              {
                'title': 'Total Athletes',
                    'count': '${userStats['athlete'] ?? 0}',
                'icon': Icons.people,
                'color': Colors.blue,
              },
              {
                'title': 'Active Events',
                    'count': '$activeEvents',
                'icon': Icons.calendar_today,
                'color': Colors.green,
              },
              {
                'title': 'Coaches',
                    'count': '${userStats['coach'] ?? 0}',
                'icon': Icons.sports,
                'color': Colors.orange,
              },
              {
                'title': 'Teams',
                    'count': '${(userStats['coach'] ?? 0) + (userStats['athlete'] ?? 0) ~/ 4}',
                'icon': Icons.group_work,
                'color': Colors.purple,
              },
            ];

return Container(
                  padding: EdgeInsets.all(defaultPadding),
  decoration: BoxDecoration(
    color: secondaryColor,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
                          Text(
              stats[index]['title'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
                          Container(
                            padding: EdgeInsets.all(defaultPadding * 0.5),
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: stats[index]['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
            stats[index]['icon'],
            color: stats[index]['color'],
                              size: 20,
                            ),
                          ),
        ],
      ),
      Text(
        stats[index]['count'],
                        style: Theme.of(context).textTheme.titleLarge,
            ),
    ],
  ),
);
          },
            );
          }
        );
      },
    );
  }
}

class RecentAthletes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Athletes",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: defaultPadding),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'athlete')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Center(child: Text('No athletes found')),
                );
              }

              return Column(
                children: [
                  // Header row
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white24,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                        children: [
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              "Name",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              "Sport",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              "Jersey Number",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Data rows
                  ...List.generate(
                    snapshot.data!.docs.length,
                    (index) {
                      final athlete = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white10,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundImage: athlete['photoURL'] != null && athlete['photoURL'].toString().isNotEmpty
                                          ? NetworkImage(athlete['photoURL'])
                                          : null,
                                      child: athlete['photoURL'] == null || athlete['photoURL'].toString().isEmpty
                                          ? Icon(Icons.person, size: 15)
                                          : null,
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: defaultPadding / 2),
                                        child: Text(
                                          athlete['name'] ?? 'Unknown',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Text(
                                  athlete['sportsType'] ?? 'Not specified',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Text(
                                  athlete['jerseyNumber']?.toString() ?? 'N/A',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class UpcomingEvents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Matches",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .where('status', isEqualTo: 'completed')
                .orderBy('date', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_soccer_outlined, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No completed matches found'),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: List.generate(
                  snapshot.data!.docs.length,
                  (index) {
                    final match = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final matchDate = (match['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final formattedDate = DateFormat('MMM d, yyyy').format(matchDate);
                    final sport = match['sport'] ?? 'Unknown';
                    final type = match['type'] ?? '';
                    final status = match['status'] ?? 'scheduled';
                    
                    // Get summary results if available
                    List<dynamic> results = [];
                    if (match['summary'] != null && match['summary']['results'] != null) {
                      results = match['summary']['results'] as List<dynamic>;
                    }
                    
                    return MatchCard(
                      sport: sport,
                      type: type,
                      date: formattedDate,
                      status: status,
                      results: results,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final String sport;
  final String type;
  final String date;
  final String status;
  final List<dynamic> results;

  const MatchCard({
    Key? key,
    required this.sport,
    required this.type,
    required this.date,
    required this.status,
    required this.results,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: EdgeInsets.only(top: defaultPadding),
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _getSportIcon(sport),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "$sport ${type.isNotEmpty ? '- $type' : ''}",
            style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16),
              SizedBox(width: 5),
              Text(date),
            ],
          ),
          if (results.isNotEmpty) ...[
            SizedBox(height: 8),
            Divider(color: Colors.white10),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Results:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  "Time (seconds)",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...results.take(3).map((result) {
              final athlete = result['athlete'] ?? 'Unknown';
              final place = result['place']?.toString() ?? '';
              final time = result['time'] ?? '';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getPlaceColor(place).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          place.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getPlaceColor(place),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        athlete,
                        style: TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "$time s",
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
  
  Widget _getSportIcon(String sport) {
    IconData iconData;
    switch (sport.toLowerCase()) {
      case 'running':
        iconData = Icons.directions_run;
        break;
      case 'swimming':
        iconData = Icons.pool;
        break;
      case 'football':
      case 'soccer':
        iconData = Icons.sports_soccer;
        break;
      case 'basketball':
        iconData = Icons.sports_basketball;
        break;
      case 'tennis':
        iconData = Icons.sports_tennis;
        break;
      default:
        iconData = Icons.sports;
    }
    
    return Icon(iconData, size: 20);
  }
  
  Color _getPlaceColor(dynamic place) {
    if (place == 1 || place == '1') {
      return Colors.amber;
    } else if (place == 2 || place == '2') {
      return Colors.grey.shade400;
    } else if (place == 3 || place == '3') {
      return Colors.brown.shade300;
    } else {
      return Colors.blue;
    }
  }
}

class Announcements extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Announcements",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: defaultPadding),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.announcement_outlined, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No announcements'),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: List.generate(
                  snapshot.data!.docs.length,
                  (index) {
                    final announcement = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final createdAt = announcement['createdAt'] as Timestamp?;
                    final formattedDate = createdAt != null 
                        ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
                        : 'Date unknown';
                    
                    return AnnouncementCard(
                      title: announcement['title'] ?? 'Untitled Announcement',
                      content: announcement['content'] ?? 'No content',
                      date: formattedDate,
                      priority: announcement['priority'] ?? 'medium',
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final String title;
  final String content;
  final String date;
  final String priority;

  const AnnouncementCard({
    Key? key,
    required this.title,
    required this.content,
    required this.date,
    required this.priority,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    return Container(
      margin: EdgeInsets.only(bottom: defaultPadding),
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12),
              SizedBox(width: 4),
              Text(
                date,
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
