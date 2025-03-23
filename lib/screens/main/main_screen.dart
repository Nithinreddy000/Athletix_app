import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import '../../controllers/menu_app_controller.dart';
import '../../responsive.dart';
import '../../constants.dart';
import '../admin_dashboard/dashboard/dashboard_screen.dart';
import '../admin_dashboard/match_management/match_management_screen.dart';
import '../admin_dashboard/user/user_management_screen.dart';
import '../admin_dashboard/announcements/announcements_screen.dart';
import '../organisation_dashboard/organisation_dashboard_screen.dart';
import '../organisation_dashboard/financial/financial_management_dashboard.dart' as org_financial;
import '../organisation_dashboard/financial/budget_analysis_dashboard.dart' as org_budget;
import '../coach_dashboard/team_overview/team_overview.dart';
import '../coach_dashboard/performance_insights/performance_insights.dart' as coach_insights;
import '../coach_dashboard/training_planner/training_planner.dart';
import '../coach_dashboard/injury_records/injury_records_screen.dart' as coach_injury;
import '../medical_dashboard/medical_dashboard_screen.dart';
import '../medical_dashboard/injury_records/injury_records_screen.dart' as medical_injury;
import '../medical_dashboard/rehabilitation/rehabilitation_screen.dart';
import '../medical_dashboard/athlete_records/athlete_medical_records_screen.dart';
import '../athlete_dashboard/athlete_dashboard_screen.dart';
import '../athlete_dashboard/performance_insights/performance_insights.dart' as athlete_insights;
import '../athlete_dashboard/injury_records/injury_records_screen.dart' as athlete_injury;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:async';
import '../auth/login_screen.dart';
import '../../services/session_service.dart';
import '../../utils/dialog_helper.dart';
import '../shared/announcements_screen.dart';

// Import dart:html only for web
import 'web_utils.dart' if (dart.library.html) 'dart:html' as html;

class MainScreen extends StatefulWidget {
  final String? initialTab;
  final String? initialAthleteId;
  
  const MainScreen({
    Key? key,
    this.initialTab,
    this.initialAthleteId,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Widget? _currentScreen;
  String _currentTitle = "Dashboard";
  bool _isPopupOpen = false;
  bool _isLoading = true;
  File? _imageFile;
  Uint8List? _webImage;
  bool _shouldRemovePhoto = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final role = userDoc.data()?['role']?.toString().toLowerCase() ?? '';
        setState(() {
          switch (role) {
            case 'admin':
              _currentScreen = DashboardScreen();
              _currentTitle = "Admin Dashboard";
              break;
            case 'coach':
              _currentScreen = TeamOverview();
              _currentTitle = "Team Overview";
              
              // Check if we need to navigate to a specific tab
              if (widget.initialTab == 'injury_records') {
                _currentScreen = coach_injury.InjuryRecordsScreen(
                  initialAthleteId: widget.initialAthleteId,
                );
                _currentTitle = "Injury Records";
              }
              break;
            case 'medical':
              // Check if we need to navigate to a specific tab
              if (widget.initialTab == 'injury_records') {
                _currentScreen = medical_injury.InjuryRecordsScreen(
                  initialAthleteId: widget.initialAthleteId,
                );
                _currentTitle = "Injury Records";
              } else {
                _currentScreen = MedicalDashboardScreen();
                _currentTitle = "Medical Dashboard";
              }
              break;
            case 'organization':
              // Initialize with Financial Management instead of Dashboard
              _currentScreen = org_financial.FinancialManagementDashboard();
              _currentTitle = "Financial Management";
              break;
            case 'athlete':
              // Use the athlete dashboard's Performance Insights screen for athlete role
              if (widget.initialTab == 'injury_records') {
                _currentScreen = athlete_injury.InjuryRecordsScreen();
                _currentTitle = "Injury Records";
              } else {
                _currentScreen = athlete_insights.PerformanceInsights();
                _currentTitle = "Performance Insights";
              }
              break;
            default:
              // For roles without implemented screens, show a placeholder
              _currentScreen = Center(
                child: Text(
                  "Dashboard for $role role is under development",
                  style: TextStyle(fontSize: 20, color: Colors.white70),
                ),
              );
              _currentTitle = "${role.toUpperCase()} Dashboard";
          }
          _isLoading = false;
        });
      }
    }
  }

  void _navigateTo(Widget screen, String title) {
    setState(() {
      _currentScreen = screen;
      _currentTitle = title;
      _isPopupOpen = false;
    });
  }

  void _togglePopup() {
    setState(() {
      _isPopupOpen = !_isPopupOpen;
    });
  }

  void _closePopup() {
    setState(() {
      _isPopupOpen = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final menuController = context.read<MenuAppController>();
    menuController.updateScreenSize(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final menuController = context.watch<MenuAppController>();
    // Update screen size on every build to handle window resizing
    menuController.updateScreenSize(context);
    bool _isExpanded = Responsive.isMobile(context) ? false : true;

    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
        key: menuController.scaffoldKey,
        drawer: Responsive.isMobile(context)
            ? Drawer(
                child: SideMenu(
                  isExpanded: _isExpanded,
                  onNavigate: _navigateTo,
                ),
              )
            : null,
        body: SafeArea(
          child: Responsive(
            mobile: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isExpanded ? Icons.menu_open : Icons.menu,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _togglePopup();
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _currentTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          ProfileCard(),
                        ],
                      ),
                    ),
                    Expanded(child: _currentScreen!),
                  ],
                ),
                if (_isPopupOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closePopup,
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                if (_isPopupOpen)
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    width: 250,
                    child: SideMenu(
                      isExpanded: true,
                      onNavigate: _navigateTo,
                    ),
                  ),
              ],
            ),
            tablet: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: menuController.isDrawerOpen ? 250 : 70,
                  child: SideMenu(
                    isExpanded: menuController.isDrawerOpen,
                    onNavigate: _navigateTo,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                menuController.isDrawerOpen ? Icons.menu_open : Icons.menu,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                menuController.controlMenu();
                              },
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _currentTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            Expanded(child: SearchField()),
                            ProfileCard(),
                          ],
                        ),
                      ),
                      Expanded(child: _currentScreen!),
                    ],
                  ),
                ),
              ],
            ),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: menuController.isDrawerOpen ? 70 : 250,
                  child: SideMenu(
                    isExpanded: !menuController.isDrawerOpen,
                    onNavigate: _navigateTo,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                menuController.isDrawerOpen ? Icons.menu : Icons.menu_open,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                menuController.controlMenu();
                              },
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _currentTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            Expanded(child: SearchField()),
                            ProfileCard(),
                          ],
                        ),
                      ),
                      Expanded(child: _currentScreen!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SideMenu extends StatefulWidget {
  final bool isExpanded;
  final Function(Widget, String) onNavigate;

  const SideMenu({
    Key? key,
    required this.isExpanded,
    required this.onNavigate,
  }) : super(key: key);

  @override
  _SideMenuState createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _isPopupOpen = false;
  String? userRole;
  bool _isLoading = true;
  StreamSubscription? _notificationSubscription;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('status', isEqualTo: 'unread')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotifications = snapshot.docs.length;
          });
        }
      });
    }
  }

  Future<void> _loadUserRole() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            userRole = userDoc['role'] as String?;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user role: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: secondaryColor,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      color: secondaryColor,
      child: ListView(
        children: [
          DrawerHeader(
            child: widget.isExpanded
                ? Image.asset("assets/images/logo.png")
                : const Icon(Icons.dashboard, size: 32, color: Colors.white),
          ),
          if (userRole?.toLowerCase() == 'medical') ...[
            DrawerListTile(
              title: "Medical Dashboard",
              icon: Icons.dashboard_customize,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(MedicalDashboardScreen(), "Medical Dashboard");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Injury Records",
              icon: Icons.medical_services,
              badge: null,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(medical_injury.InjuryRecordsScreen(), "Injury Records");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Athlete Medical Records",
              icon: Icons.person_outline,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(AthleteMedicalRecordsScreen(), "Athlete Medical Records");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Rehabilitation",
              icon: Icons.fitness_center,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.construction, size: 64, color: Colors.amber),
                        SizedBox(height: 16),
                        Text(
                          "Rehabilitation",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "This feature is under development",
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Will be available in future releases",
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  "Rehabilitation"
                );
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Announcements",
              icon: Icons.announcement,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(SharedAnnouncementsScreen(userRole: 'Medical'), "Announcements");
                _closePopup();
              },
            ),
          ] else if (userRole?.toLowerCase() == 'admin') ...[
            DrawerListTile(
              title: "Dashboard",
              icon: Icons.dashboard,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(DashboardScreen(), "Dashboard");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "User Management",
              icon: Icons.people,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(UserManagementScreen(), "User Management");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Announcements",
              icon: Icons.campaign,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(AnnouncementsScreen(), "Announcements");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Match Management",
              icon: Icons.sports_score,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(MatchManagementScreen(), "Match Management");
                _closePopup();
              },
            ),
          ] else if (userRole?.toLowerCase() == 'coach') ...[
            DrawerListTile(
              title: "Team Overview",
              icon: Icons.people,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(TeamOverview(), "Team Overview");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Performance Insights",
              icon: Icons.insights,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(coach_insights.PerformanceInsights(), "Performance Insights");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Training Planner",
              icon: Icons.calendar_today,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.construction, size: 64, color: Colors.amber),
                        SizedBox(height: 16),
                        Text(
                          "Training Planner",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "This feature is under development",
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Will be available in future releases",
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  "Training Planner"
                );
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Injury Records",
              icon: Icons.healing,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(
                  coach_injury.InjuryRecordsScreen(),
                  "Injury Records"
                );
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Announcements",
              icon: Icons.announcement,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(SharedAnnouncementsScreen(userRole: 'Coaches'), "Announcements");
                _closePopup();
              },
            ),
          ] else if (userRole?.toLowerCase() == 'organization') ...[
            DrawerListTile(
              title: "Financial Management",
              icon: Icons.attach_money,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(org_financial.FinancialManagementDashboard(), "Financial Management");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Budget Analysis",
              icon: Icons.analytics,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(org_budget.BudgetAnalysisDashboard(), "Budget Analysis");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Announcements",
              icon: Icons.announcement,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(SharedAnnouncementsScreen(userRole: 'Organisations'), "Announcements");
                _closePopup();
              },
            ),
          ] else if (userRole?.toLowerCase() == 'athlete') ...[
            DrawerListTile(
              title: "Performance Insights",
              icon: Icons.insights,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(athlete_insights.PerformanceInsights(), "Performance Insights");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Injury Records",
              icon: Icons.healing,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(athlete_injury.InjuryRecordsScreen(), "Injury Records");
                _closePopup();
              },
            ),
            DrawerListTile(
              title: "Announcements",
              icon: Icons.announcement,
              isExpanded: widget.isExpanded,
              onTap: () {
                widget.onNavigate(SharedAnnouncementsScreen(userRole: 'Athlete'), "Announcements");
                _closePopup();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _closePopup() {
    setState(() {
      _isPopupOpen = false;
    });
  }
}

class DrawerListTile extends StatelessWidget {
  const DrawerListTile({
    Key? key,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.isExpanded,
    this.badge,
  }) : super(key: key);

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isExpanded;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      horizontalTitleGap: 16.0,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon, 
          color: Colors.white70,
          size: 20,
        ),
      ),
      title: isExpanded
          ? Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            )
          : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16 : 8,
        vertical: 8,
      ),
      dense: !isExpanded,
      visualDensity: isExpanded ? VisualDensity.comfortable : VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      hoverColor: Colors.white.withOpacity(0.1),
    );
  }
}

class SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: "Search",
        fillColor: secondaryColor,
        filled: true,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

class ProfileCard extends StatefulWidget {
  const ProfileCard({Key? key}) : super(key: key);

  @override
  _ProfileCardState createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  String _userName = "Admin";
  String _userEmail = "";
  String _userPhone = "";
  Uint8List? _profileImage;
  bool _isLoading = false;
  bool _shouldRemovePhoto = false;
  File? _imageFile;
  Uint8List? _webImage;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists && mounted) {
          setState(() {
            _userName = userData.data()?['name'] ?? user.displayName ?? 'Admin';
            _userEmail = userData.data()?['email'] ?? user.email ?? '';
            _userPhone = userData.data()?['phone'] ?? '';
            
            if (userData.data()?['profileImage'] != null) {
              var imageData = userData.data()?['profileImage'];
              if (imageData is List<dynamic>) {
                _profileImage = Uint8List.fromList(imageData.cast<int>());
              } else {
                _profileImage = null;
              }
            } else {
              _profileImage = null;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Prepare update data
      Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Handle profile image
      if (_shouldRemovePhoto) {
        updateData['profileImage'] = FieldValue.delete();
      } else if (_webImage != null) {
        updateData['profileImage'] = _webImage!.toList();
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      // Update Firebase Auth profile
      await user.updateProfile(displayName: _nameController.text);
      if (_emailController.text != user.email) {
        await user.updateEmail(_emailController.text);
      }

      // Reload user profile
      await _loadUserProfile();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: secondaryColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 24,
          color: Colors.white70,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (kIsWeb) {
        if (source == ImageSource.camera) {
          await _captureImageWeb();
        } else {
          final ImagePicker picker = ImagePicker();
          XFile? image = await picker.pickImage(source: source);
          if (image != null) {
            var f = await image.readAsBytes();
            setState(() {
              _webImage = f;
              _imageFile = null;
              _shouldRemovePhoto = false;
            });
          }
        }
      } else {
        final ImagePicker picker = ImagePicker();
        XFile? image = await picker.pickImage(source: source);
        if (image != null) {
          setState(() {
            _imageFile = File(image.path);
            _webImage = null;
            _shouldRemovePhoto = false;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _captureImageWeb() async {
    if (!kIsWeb) return;

    try {
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': { 'ideal': 1920 },
          'height': { 'ideal': 1080 }
        }
      });

      if (mediaStream == null) {
        throw Exception('Failed to get media stream');
      }

      final videoElement = html.VideoElement()
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000000';

      videoElement.srcObject = mediaStream;

      // Show the camera UI using Flutter widgets
      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (BuildContext context) {
          return OrientationBuilder(
            builder: (context, orientation) {
              return Material(
                type: MaterialType.transparency,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      // Video preview
                      Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: HtmlElementView(
                            viewType: 'video-${DateTime.now().millisecondsSinceEpoch}',
                            onPlatformViewCreated: (_) {
                              html.document.body?.append(videoElement);
                            },
                          ),
                        ),
                      ),

                      // 3D Model Overlay (placeholder for now)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            // This will be replaced with the 3D model
                          ),
                        ),
                      ),

                      // Top controls
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 16,
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white, size: 28),
                                onPressed: () {
                                  for (var track in mediaStream.getTracks()) {
                                    track.stop();
                                  }
                                  videoElement.remove();
                                  Navigator.of(context).pop();
                                },
                              ),
                              Text(
                                'Recording Performance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                                onPressed: () {
                                  // TODO: Implement camera flip
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom controls
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Recording timer
                              Text(
                                '00:00',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              // Controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Stats button
                                  FloatingActionButton(
                                    heroTag: 'stats',
                                    mini: true,
                                    backgroundColor: Colors.white24,
                                    child: Icon(Icons.analytics, color: Colors.white),
                                    onPressed: () {
                                      // TODO: Show real-time stats
                                    },
                                  ),
                                  // Record button
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.red, width: 4),
                                    ),
                                    child: FloatingActionButton(
                                      heroTag: 'record',
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.fiber_manual_record, color: Colors.white, size: 40),
                                      onPressed: () {
                                        // TODO: Start/Stop recording
                                      },
                                    ),
                                  ),
                                  // 3D Model toggle
                                  FloatingActionButton(
                                    heroTag: '3d_model',
                                    mini: true,
                                    backgroundColor: Colors.white24,
                                    child: Icon(Icons.view_in_ar, color: Colors.white),
                                    onPressed: () {
                                      // TODO: Toggle 3D model visibility
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error accessing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildProfileImage() {
    if (_isLoading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    
    if (_profileImage != null) {
      return ClipOval(
        child: Image.memory(
          _profileImage!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar();
          },
        ),
      );
    }
    
    return _buildDefaultAvatar();
  }

  void _showEditProfileDialog(BuildContext context) {
    _nameController.text = _userName;
    _emailController.text = _userEmail;
    _phoneController.text = _userPhone;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: secondaryColor,
          title: Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white),
          ),
          content: Container(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                          image: (_webImage != null)
                              ? DecorationImage(
                                  image: MemoryImage(_webImage!),
                                  fit: BoxFit.cover,
                                )
                              : (_profileImage != null && !_shouldRemovePhoto)
                                  ? DecorationImage(
                                      image: MemoryImage(_profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: (_webImage == null && (_profileImage == null || _shouldRemovePhoto))
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white70,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.camera_alt, color: Colors.white),
                            onSelected: (String value) async {
                              if (value == 'camera') {
                                await _pickImage(ImageSource.camera);
                              } else if (value == 'gallery') {
                                await _pickImage(ImageSource.gallery);
                              } else if (value == 'remove') {
                                setState(() {
                                  _shouldRemovePhoto = true;
                                  _webImage = null;
                                  _imageFile = null;
                                });
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem(
                                value: 'camera',
                                child: ListTile(
                                  leading: Icon(Icons.camera_alt),
                                  title: Text('Take Photo'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'gallery',
                                child: ListTile(
                                  leading: Icon(Icons.photo_library),
                                  title: Text('Choose from Gallery'),
                                ),
                              ),
                              if (_profileImage != null || _webImage != null)
                                PopupMenuItem(
                                  value: 'remove',
                                  child: ListTile(
                                    leading: Icon(Icons.delete, color: Colors.red),
                                    title: Text('Remove Photo', style: TextStyle(color: Colors.red)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: defaultPadding),
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.white70),
                    ),
                  ),
                  SizedBox(height: defaultPadding),
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
                    ),
                  ),
                  SizedBox(height: defaultPadding),
                  TextFormField(
                    controller: _phoneController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.phone_outlined, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _shouldRemovePhoto = false;
                  _webImage = null;
                  _imageFile = null;
                });
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: defaultPadding),
      padding: EdgeInsets.symmetric(
        horizontal: defaultPadding,
        vertical: defaultPadding / 2,
      ),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 50),
        child: Row(
          children: [
            _buildProfileImage(),
            if (!Responsive.isMobile(context))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding / 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_userName),
                    Text(
                      _userEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          ],
        ),
        onSelected: (String value) {
          switch (value) {
            case 'edit_profile':
              _showEditProfileDialog(context);
              break;
            case 'change_password':
              _showChangePasswordDialog(context);
              break;
            case 'logout':
              _handleLogout(context);
              break;
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'edit_profile',
            child: ListTile(
              leading: Icon(Icons.person_outline, color: Colors.white70),
              title: Text('Edit Profile'),
              subtitle: Text(
                _userPhone,
                style: TextStyle(fontSize: 12),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem<String>(
            value: 'change_password',
            child: ListTile(
              leading: Icon(Icons.lock_outline, color: Colors.white70),
              title: Text('Change Password'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade300),
              title: Text('Logout'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        builder: (context) => ChangePasswordDialog(),
      );
    });
  }

  void _handleLogout(BuildContext context) {
    Future.delayed(Duration.zero, () {
      DialogHelper.showConfirmationDialog(
        context: context,
        title: 'Logout',
        message: 'Are you sure you want to logout?',
        confirmText: 'Logout',
        cancelText: 'Cancel',
        confirmColor: Colors.red,
      ).then((confirmed) async {
        if (confirmed == true) {
          try {
            // Sign out from Firebase
            await FirebaseAuth.instance.signOut();
            // Get the session service
            final sessionService = context.read<SessionService>();
            // Clear the session
            await sessionService.clearSession();
            // Navigate to login screen
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            }
          } catch (e) {
            print('Error during logout: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to logout: $e')),
            );
          }
        }
      });
    });
  }
}

class ChangePasswordDialog extends StatefulWidget {
  @override
  _ChangePasswordDialogState createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Get user credentials
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      // Reauthenticate user
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(_newPasswordController.text);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password changed successfully')),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'New password is too weak';
          break;
        case 'requires-recent-login':
          message = 'Please log in again before changing your password';
          break;
        default:
          message = 'Failed to change password: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change password: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.orange),
          SizedBox(width: 10),
          Text('Change Password'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_showCurrentPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                ),
              ),
              obscureText: !_showCurrentPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                return null;
              },
            ),
            SizedBox(height: defaultPadding),
            TextFormField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
              obscureText: !_showNewPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a new password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            SizedBox(height: defaultPadding),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
              obscureText: !_showConfirmPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your new password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('Change Password'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
