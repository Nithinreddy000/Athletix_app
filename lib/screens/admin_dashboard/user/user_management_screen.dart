import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../../../services/user_service.dart';
import 'dart:typed_data';
import '../athlete_statistics/athlete_statistics_screen.dart';
import '../../coach_dashboard/performance_analysis/performance_analysis_screen.dart';
import '../../coach_dashboard/performance_analysis/video_upload_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  String _searchQuery = '';
  String _selectedRole = 'All';
  bool _isCreating = false;
  Set<String> _selectedUsers = {};
  
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _nameController;
  TextEditingController? _emailController;
  TextEditingController? _passwordController;
  String _newUserRole = 'athlete';
  String adminEmail = '';
  String adminPassword = '';
  String? _selectedCoach;
  String? _selectedSportType;
  String _jerseyNumber = '';
  List<Map<String, dynamic>> _coaches = [];
  String? _selectedOrganizationId;
  List<Map<String, dynamic>> _organizations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _newUserRole = 'athlete';
    _loadCoaches();
    _loadOrganizations();
  }

  Future<void> _loadCoaches() async {
    try {
      setState(() {
        _isCreating = true; // Show loading state
      });

      final coachesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .orderBy('name') // Sort coaches by name
          .get();
      
      final List<Map<String, dynamic>> coachesList = coachesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': (doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown',
                'email': (doc.data() as Map<String, dynamic>)['email'] ?? '',
              })
          .toList();

      print('Loaded ${coachesList.length} coaches'); // Debug log
      
      if (mounted) {
        setState(() {
          _coaches = coachesList;
          _isCreating = false;
        });
      }
    } catch (e) {
      print('Error loading coaches: $e');
      if (mounted) {
        setState(() {
          _coaches = [];
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _loadOrganizations() async {
    try {
      final organizations = await _userService.getAllOrganizations();
      if (mounted) {
        setState(() {
          _organizations = organizations;
        });
      }
    } catch (e) {
      print('Error loading organizations: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _nameController?.dispose();
    _emailController?.dispose();
    _passwordController?.dispose();
    _nameController = null;
    _emailController = null;
    _passwordController = null;
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  void _showAddUserDialog() {
    _initControllers();
    _selectedCoach = null; // Reset selected coach
    _selectedSportType = null; // Reset selected sport type
    _jerseyNumber = ''; // Reset jersey number
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: secondaryColor,
            title: Text(
              'Add New User',
              style: TextStyle(color: Colors.white),
            ),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isCreating,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      style: TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: defaultPadding),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isCreating,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      style: TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: defaultPadding),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _newUserRole,
                        dropdownColor: secondaryColor,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.badge_outlined),
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        items: ['admin', 'coach', 'athlete', 'organization', 'medical']
                            .map((role) => DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(role.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _newUserRole = value!;
                            if (value != 'athlete') {
                              _selectedCoach = null;
                              _selectedSportType = null;
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a role';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_newUserRole == 'athlete') ...[
                      const SizedBox(height: defaultPadding),
                      
                      // Organization dropdown for athletes
                      Container(
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedOrganizationId,
                          dropdownColor: secondaryColor,
                          decoration: const InputDecoration(
                            labelText: 'Organization',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            prefixIcon: Icon(Icons.business),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('None'),
                            ),
                            ..._organizations.map((org) => DropdownMenuItem<String>(
                              value: org['id'],
                              child: Text(org['name']),
                            )).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedOrganizationId = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: defaultPadding),
                      
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadCoachesData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(10.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final coaches = snapshot.data ?? [];
                          
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCoach,
                              dropdownColor: secondaryColor,
                              decoration: const InputDecoration(
                                labelText: 'Under Coach',
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.sports),
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              items: coaches.isEmpty
                                  ? [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          'No coaches available',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      )
                                    ]
                                  : coaches.map((coach) => DropdownMenuItem<String>(
                                        value: coach['id'],
                                        child: Text(
                                          '${coach['name']} (${coach['email']})',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      )).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  _selectedCoach = value;
                                });
                              },
                              validator: (value) {
                                if (_newUserRole == 'athlete' && (value == null || value.isEmpty)) {
                                  return 'Please select a coach';
                                }
                                return null;
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: defaultPadding),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedSportType,
                          dropdownColor: secondaryColor,
                          decoration: const InputDecoration(
                            labelText: 'Sport Type',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.sports_basketball),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          items: ['weightlifting', 'swimming', 'running']
                              .map((sport) => DropdownMenuItem<String>(
                                    value: sport,
                                    child: Text(sport.toUpperCase()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedSportType = value;
                            });
                          },
                          validator: (value) {
                            if (_newUserRole == 'athlete' && (value == null || value.isEmpty)) {
                              return 'Please select a sport type';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: defaultPadding),
                      TextFormField(
                        enabled: !_isCreating,
                        decoration: InputDecoration(
                          labelText: 'Jersey Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered),
                          labelStyle: TextStyle(color: Colors.white70),
                          suffixIcon: Tooltip(
                            message: 'Enter any number',
                            child: Icon(Icons.info_outline, color: Colors.white70),
                          ),
                          helperText: 'Enter jersey number',
                          helperStyle: TextStyle(color: Colors.white70),
                        ),
                        style: TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setDialogState(() {
                            _jerseyNumber = value;
                          });
                        },
                        validator: (value) {
                          if (_newUserRole == 'athlete') {
                            if (value == null || value.isEmpty) {
                              return 'Please enter jersey number';
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                              return 'Please enter a valid number';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isCreating ? null : () {
                  Navigator.pop(context);
                  _disposeControllers();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: _isCreating ? null : () async {
                  if (_formKey.currentState!.validate()) {
                    setDialogState(() => _isCreating = true);
                    try {
                      await _userService.createUser(
                        name: _nameController?.text ?? '',
                        email: _emailController?.text ?? '',
                        role: _newUserRole.toLowerCase(),
                        coachId: _newUserRole == 'athlete' ? _selectedCoach : null,
                        sportsType: _newUserRole == 'athlete' ? _selectedSportType : null,
                        jerseyNumber: _newUserRole == 'athlete' ? _jerseyNumber : null,
                        organizationId: _newUserRole == 'athlete' ? _selectedOrganizationId : null,
                      );
                      
                      if (mounted) {
                        Navigator.pop(context);
                        _disposeControllers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User created successfully. Welcome email sent!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating user: $e'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                    
                    if (mounted) {
                      setDialogState(() => _isCreating = false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create User'),
              ),
            ],
          );
        },
      ),
    ).then((_) => _disposeControllers());
  }

  Future<List<Map<String, dynamic>>> _loadCoachesData() async {
    try {
      final coachesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .orderBy('name')
          .get();
      
      return coachesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': (doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown',
                'email': (doc.data() as Map<String, dynamic>)['email'] ?? '',
              })
          .toList();
    } catch (e) {
      print('Error loading coaches: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedUsers.isNotEmpty
          ? AppBar(
              backgroundColor: secondaryColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close, color: Colors.white70),
                onPressed: () => setState(() => _selectedUsers.clear()),
              ),
              title: Text(
                '${_selectedUsers.length} Selected',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: _deleteSelectedUsers,
                  tooltip: 'Delete Selected',
                ),
              ],
            )
          : null,
      body: Responsive(
        mobile: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Users'),
                Tab(text: 'Roles'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildUsersTab(),
                  _buildRolesTab(),
                ],
              ),
            ),
          ],
        ),
        tablet: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Users'),
                Tab(text: 'Roles'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildUsersTab(),
                  _buildRolesTab(),
                ],
              ),
            ),
          ],
        ),
        desktop: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Users'),
                Tab(text: 'Roles'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildUsersTab(),
                  _buildRolesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.person_add),
        tooltip: 'Add New User',
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Statistics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding),
          UserStatisticsCards(),
          const SizedBox(height: defaultPadding * 2),
          Text(
            'Recent Users',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          _buildRecentUsers(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Responsive.isMobile(context)
              ? Column(
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: defaultPadding),
                    _buildRoleFilter(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    const SizedBox(width: defaultPadding),
                    _buildRoleFilter(),
                  ],
                ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _userService.getAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data!.docs.where((doc) {
                final userData = doc.data() as Map<String, dynamic>;
                
                final matchesSearch = _searchQuery.isEmpty ||
                    (userData['name']?.toString().toLowerCase() ?? '').contains(_searchQuery.toLowerCase()) ||
                    (userData['email']?.toString().toLowerCase() ?? '').contains(_searchQuery.toLowerCase());
                  
                var role = (userData['role'] as String?)?.toLowerCase() ?? '';
                if (userData['email'] == 'admin@ams.com') {
                  role = 'admin';
                }
                
                final matchesRole = _selectedRole == 'All' ||
                    role == _selectedRole.toLowerCase();
                  
                return matchesSearch && matchesRole;
              }).toList();

              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(defaultPadding),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userData = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  var role = (userData['role'] as String?)?.toLowerCase() ?? '';
                  if (userData['email'] == 'admin@ams.com') {
                    role = 'admin';
                  }
                  final roleColor = _getRoleColor(role);
                  final name = userData['name']?.toString() ?? 'No Name';
                  final email = userData['email']?.toString() ?? 'No Email';
                  String? organizationName;
                  
                  // Fetch organization name for athletes
                  if (role == 'athlete' && userData['organizationId'] != null) {
                    _fetchOrganizationName(userData['organizationId']).then((orgName) {
                      if (mounted) {
                        setState(() {
                          userData['organizationName'] = orgName;
                        });
                      }
                    });
                    organizationName = userData['organizationName'];
                  }
                  
                  Uint8List? profileImage;

                  // Handle profile image
                  if (userData['profileImage'] != null) {
                    var imageData = userData['profileImage'];
                    if (imageData is List<dynamic>) {
                      profileImage = Uint8List.fromList(imageData.cast<int>());
                    } else if (imageData is Uint8List) {
                      profileImage = imageData;
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: defaultPadding),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Responsive.isMobile(context)
                        ? Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.all(defaultPadding),
                                leading: role.toLowerCase() != 'admin'
                                    ? Checkbox(
                                        value: _selectedUsers.contains(userId),
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedUsers.add(userId);
                                            } else {
                                              _selectedUsers.remove(userId);
                                            }
                                          });
                                        },
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: roleColor.withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: profileImage != null
                                              ? Image.memory(
                                                  profileImage,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                                                )
                                              : Container(
                                                  color: roleColor.withOpacity(0.2),
                                                  child: Center(
                                                    child: Text(
                                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: roleColor.withOpacity(0.8),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      email,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (role == 'athlete' && userData['organizationName'] != null)
                                      Text(
                                        'Organization: ${userData['organizationName']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () => _showUserDetails(
                                  context,
                                  name,
                                  email,
                                  userData['phone']?.toString() ?? 'Not provided',
                                  role,
                                  profileImage,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: defaultPadding,
                                  right: defaultPadding,
                                  bottom: defaultPadding,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: roleColor.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          role.toUpperCase(),
                                          style: TextStyle(
                                            color: roleColor.withOpacity(0.8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    if (role.toLowerCase() != 'admin') ...[
                                      SizedBox(width: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: IconButton(
                                              icon: Icon(Icons.edit, color: Colors.blue[400], size: 18),
                                              onPressed: () => _showEditUserDialog(userId, userData),
                                              tooltip: 'Edit User',
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red[400],
                                                size: 18,
                                              ),
                                              onPressed: () => _deleteUser(userId, email),
                                              tooltip: 'Delete User',
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListTile(
                            contentPadding: const EdgeInsets.all(defaultPadding),
                            leading: role.toLowerCase() != 'admin'
                                ? Checkbox(
                                    value: _selectedUsers.contains(userId),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedUsers.add(userId);
                                        } else {
                                          _selectedUsers.remove(userId);
                                        }
                                      });
                                    },
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: roleColor.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: profileImage != null
                                          ? Image.memory(
                                              profileImage,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: roleColor.withOpacity(0.2),
                                              child: Center(
                                                child: Text(
                                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: roleColor.withOpacity(0.8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                if (role == 'athlete' && userData['organizationName'] != null)
                                  Text(
                                    'Organization: ${userData['organizationName']}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 100),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: roleColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: roleColor.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        color: roleColor.withOpacity(0.8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                if (role.toLowerCase() != 'admin') ...[
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: IconButton(
                                      icon: Icon(Icons.edit, color: Colors.blue[400], size: 18),
                                      onPressed: () => _showEditUserDialog(userId, userData),
                                      tooltip: 'Edit User',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red[400],
                                        size: 18,
                                      ),
                                      onPressed: () => _deleteUser(userId, email),
                                      tooltip: 'Delete User',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => _showUserDetails(
                              context,
                              name,
                              email,
                              userData['phone']?.toString() ?? 'Not provided',
                              role,
                              profileImage,
                            ),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF212332),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white70),
          const SizedBox(width: defaultPadding / 2),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search users...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF212332),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          dropdownColor: const Color(0xFF212332),
          style: const TextStyle(color: Colors.white),
          items: ['All', 'Admin', 'Coach', 'Athlete', 'Organization', 'Medical']
              .map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedRole = value!;
              // Clear organization selection if not an athlete
              if (_selectedRole != 'athlete') {
                _selectedOrganizationId = null;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildRolesTab() {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role Management(Under Development)',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding),
          Expanded(
            child: ListView(
              children: [
                _buildRoleCard(
                  'Admin',
                  'Full system access',
                  ['Manage users', 'Manage roles', 'View analytics'],
                  Colors.red[400]!,
                ),
                const SizedBox(height: defaultPadding),
                _buildRoleCard(
                  'Coach',
                  'Manage athletes and training',
                  ['View athletes', 'Create workouts', 'Track progress'],
                  Colors.green[400]!,
                ),
                const SizedBox(height: defaultPadding),
                _buildRoleCard(
                  'Athlete',
                  'Access training and progress',
                  ['View workouts', 'Track progress', 'Message coach'],
                  Colors.blue[400]!,
                ),
                const SizedBox(height: defaultPadding),
                _buildRoleCard(
                  'Organization',
                  'Manage organization settings',
                  ['Manage teams', 'View reports', 'Billing access'],
                  Colors.orange[400]!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, String description, List<String> permissions, Color roleColor) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF242731),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: roleColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: defaultPadding / 2),
                Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                  onPressed: () => _showEditRoleDialog(role),
                  tooltip: 'Edit Role',
                ),
              ],
            ),
            const SizedBox(height: defaultPadding / 2),
            Text(
              description,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: defaultPadding),
            const Text(
              'Permissions:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: defaultPadding / 2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permissions.map((permission) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  border: Border.all(color: roleColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  permission,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 12,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: _userService.getRecentUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        // Limit to 5 most recent users
        final users = snapshot.data!.docs.take(5).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            // Get user data
            final userData = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            var role = (userData['role'] as String?)?.toLowerCase() ?? '';
            if (userData['email'] == 'admin@ams.com') {
              role = 'admin';
            }
            final roleColor = _getRoleColor(role);
            final name = userData['name']?.toString() ?? 'No Name';
            final email = userData['email']?.toString() ?? 'No Email';
            String? organizationName;
            
            // Fetch organization name for athletes
            if (role == 'athlete' && userData['organizationId'] != null) {
              _fetchOrganizationName(userData['organizationId']).then((orgName) {
                if (mounted) {
                  setState(() {
                    userData['organizationName'] = orgName;
                  });
                }
              });
              organizationName = userData['organizationName'];
            }
            
            Uint8List? profileImage;

            // Handle profile image
            if (userData['profileImage'] != null) {
              var imageData = userData['profileImage'];
              if (imageData is List<dynamic>) {
                profileImage = Uint8List.fromList(imageData.cast<int>());
              } else if (imageData is Uint8List) {
                profileImage = imageData;
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: roleColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: profileImage != null
                        ? Image.memory(
                            profileImage,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: roleColor.withOpacity(0.2),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (role == 'athlete' && userData['organizationName'] != null)
                      Text(
                        'Organization: ${userData['organizationName']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: roleColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            color: roleColor.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (role.toLowerCase() != 'admin') ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue[400], size: 18),
                          onPressed: () => _showEditUserDialog(userId, userData),
                          tooltip: 'Edit User',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red[400],
                            size: 18,
                          ),
                          onPressed: () => _deleteUser(userId, email),
                          tooltip: 'Delete User',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () => _showUserDetails(
                  context,
                  name,
                  email,
                  userData['phone']?.toString() ?? 'Not provided',
                  role,
                  profileImage,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Get role color
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red[400]!;
      case 'coach':
        return Colors.green[400]!;
      case 'user':
      case 'athlete':
        return Colors.blue[400]!;
      case 'organization':
        return Colors.orange[400]!;
      case 'medical':
        return Colors.purple[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  void _showUserProfile(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  child: Text(
                    (user['name'] as String?)?.isNotEmpty == true 
                        ? user['name'][0].toString().toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(height: defaultPadding),
              _buildProfileField('Name', user['name']?.toString() ?? 'N/A'),
              _buildProfileField('Email', user['email']?.toString() ?? 'N/A'),
              _buildProfileField('Role', user['role']?.toString() ?? 'N/A'),
              _buildProfileField('Joined', user['createdAt']?.toDate().toString() ?? 'N/A'),
              if (user['phone'] != null) _buildProfileField('Phone', user['phone'].toString()),
              if (user['address'] != null) _buildProfileField('Address', user['address'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditUserDialog(user['id'], user);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
          const Divider(),
        ],
      ),
    );
  }

  void _showEditUserDialog(String userId, Map<String, dynamic> userData) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isMobile = Responsive.isMobile(context);
    final double padding = screenSize.width < 380 ? 8.0 : (isMobile ? defaultPadding / 2 : defaultPadding);
    final double fontSize = screenSize.width < 380 ? 12.0 : (isMobile ? 14.0 : 16.0);
    final double iconSize = screenSize.width < 380 ? 16.0 : (isMobile ? 20.0 : 24.0);

    // Make sure we have the complete user data
    print('Showing edit dialog for user: $userId');
    print('User data: $userData');
    
    // Ensure organizationId is included in userData if it exists
    if (userData['organizationId'] != null) {
      print('User has organizationId: ${userData['organizationId']}');
    } else {
      print('User does not have an organizationId');
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
        child: Container(
          width: screenSize.width * 0.95,
          constraints: BoxConstraints(maxHeight: screenSize.height * 0.8),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: EditUserForm(userId: userId, userData: userData),
        ),
      ),
    );
  }

  void _deleteUser(String uid, String email) async {
    try {
      // Show confirmation dialog first
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: secondaryColor,
          title: Text(
            'Delete User',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete user: $email?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[300],
              ),
              child: Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: secondaryColor,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Deleting user: $email',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Please wait...',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        // Delete user in background
        await _userService.deleteUser(uid);

        // Close loading dialog
        if (context.mounted) Navigator.of(context).pop();

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Refresh the user list
        if (mounted) setState(() {});
      }
    } catch (e) {
      // Close loading dialog if it's showing
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showEditRoleDialog(String role) {
    final _permissionsController = TextEditingController();
    final _descriptionController = TextEditingController();
    
    // Pre-fill the current permissions and description
    Map<String, bool> permissions = {
      'Manage users': role == 'Admin',
      'Manage roles': role == 'Admin',
      'View analytics': true,
      'Create workouts': role == 'Coach',
      'Track progress': true,
      'Message users': true,
      'View reports': role == 'Admin' || role == 'Coach',
      'Billing access': role == 'Admin' || role == 'Organization',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $role Role'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Role Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: defaultPadding),
              const Text(
                'Permissions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: defaultPadding / 2),
              ...permissions.entries.map((entry) => CheckboxListTile(
                title: Text(entry.key),
                value: entry.value,
                onChanged: (bool? value) {
                  setState(() {
                    permissions[entry.key] = value ?? false;
                  });
                },
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Get the selected permissions
                final selectedPermissions = permissions.entries
                    .where((entry) => entry.value)
                    .map((entry) => entry.key)
                    .toList();

                // Update the role permissions
                await _userService.updateRolePermissions(
                  role.toLowerCase(),
                  selectedPermissions,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$role role updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating role: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Uint8List? profileImage) {
    if (profileImage != null) {
      return ClipOval(
        child: Image.memory(
          profileImage,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
        ),
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: secondaryColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        color: Colors.white70,
        size: 30,
      ),
    );
  }

  void _showUserDetails(
    BuildContext context,
    String name,
    String email,
    String phone,
    String role,
    Uint8List? profileImage,
  ) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isMobile = Responsive.isMobile(context);
    final bool isSmallMobile = screenSize.width < 380;
    final double dialogWidth = isMobile ? screenSize.width * 0.95 : 400;
    final double maxHeight = screenSize.height * 0.8;
    final double padding = isSmallMobile ? 8.0 : (isMobile ? defaultPadding / 2 : defaultPadding);
    final double fontSize = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final double iconSize = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 24.0);
    final double avatarSize = isSmallMobile ? 60.0 : (isMobile ? 80.0 : 100.0);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 8 : 16, vertical: 24),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, color: Colors.white70, size: iconSize),
                            SizedBox(width: padding),
                            Flexible(
                              child: Text(
                                'Profile Details',
                                style: TextStyle(
                                  fontSize: fontSize + 2,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white70, size: iconSize),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Profile Image
                Container(
                  padding: EdgeInsets.all(padding),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: profileImage != null
                          ? Image.memory(
                              profileImage,
                              width: avatarSize,
                              height: avatarSize,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: secondaryColor,
                              child: Icon(
                                Icons.person,
                                size: avatarSize * 0.5,
                                color: Colors.white70,
                              ),
                            ),
                    ),
                  ),
                ),
                // User Info
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    children: [
                      _buildDetailItem(
                        Icons.person_outline,
                        'Name',
                        name,
                        fontSize,
                        iconSize,
                        padding,
                      ),
                      SizedBox(height: padding / 2),
                      _buildDetailItem(
                        Icons.email_outlined,
                        'Email',
                        email,
                        fontSize,
                        iconSize,
                        padding,
                      ),
                      SizedBox(height: padding / 2),
                      _buildDetailItem(
                        Icons.phone_outlined,
                        'Phone',
                        phone,
                        fontSize,
                        iconSize,
                        padding,
                      ),
                      SizedBox(height: padding / 2),
                      _buildDetailItem(
                        Icons.badge_outlined,
                        'Role',
                        role.toUpperCase(),
                        fontSize,
                        iconSize,
                        padding,
                      ),
                    ],
                  ),
                ),
                if (role.toLowerCase() == 'athlete') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.analytics),
                          label: Text('Manage Statistics'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AthleteStatisticsScreen(
                                  userId: email,
                                ),
                              ),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.sports),
                          label: Text('Upload Video'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoUploadScreen(
                                  athleteId: email,
                                  athleteName: name,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value,
    double fontSize,
    double iconSize,
    double padding,
  ) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(padding / 2),
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70, size: iconSize),
          ),
          SizedBox(width: padding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: fontSize - 2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedUsers() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: secondaryColor,
          title: Text(
            'Delete Selected Users',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete ${_selectedUsers.length} selected users?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[300],
              ),
              child: Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: secondaryColor,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Deleting ${_selectedUsers.length} users',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Please wait...',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        try {
          // Delete users in background
          await _userService.deleteMultipleUsers(_selectedUsers.toList());

          // Close loading dialog
          if (context.mounted) Navigator.of(context).pop();

          // Clear selection and show success message
          setState(() => _selectedUsers.clear());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Users deleted successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          // Close loading dialog
          if (context.mounted) Navigator.of(context).pop();

          // Show error message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error in delete operation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fetch organization name by ID
  Future<String> _fetchOrganizationName(String organizationId) async {
    try {
      final doc = await _userService.getUserById(organizationId);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? 'Unknown Organization';
      }
      return 'Unknown Organization';
    } catch (e) {
      print('Error fetching organization: $e');
      return 'Unknown Organization';
    }
  }
}

class UserStatisticsCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: UserService().getUserStatistics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final stats = snapshot.data!;
        return Responsive.isMobile(context)
            ? Wrap(
                spacing: defaultPadding,
                runSpacing: defaultPadding,
                children: _buildStatCards(context, stats),
              )
            : Row(
                children: _buildStatCards(context, stats)
                    .map((card) => Expanded(child: card))
                    .toList(),
              );
      },
    );
  }

  List<Widget> _buildStatCards(BuildContext context, Map<String, int> stats) {
    return [
      _buildStatCard(
        context,
        'Total Users',
        stats['total'].toString(),
        Icons.people,
        Colors.blue,
      ),
      _buildStatCard(
        context,
        'Admins',
        stats['admin'].toString(),
        Icons.admin_panel_settings,
        Colors.red,
      ),
      _buildStatCard(
        context,
        'Coaches',
        stats['coach'].toString(),
        Icons.sports,
        Colors.green,
      ),
      _buildStatCard(
        context,
        'Athletes',
        stats['athlete'].toString(),
        Icons.fitness_center,
        Colors.orange,
      ),
      _buildStatCard(
        context,
        'Organizations',
        stats['organization'].toString(),
        Icons.business,
        Colors.purple,
      ),
      _buildStatCard(
        context,
        'Medical',
        (stats['medical'] ?? 0).toString(),
        Icons.medical_services,
        Colors.teal,
      ),
    ];
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: defaultPadding / 2),
                Text(title),
              ],
            ),
            const SizedBox(height: defaultPadding),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddUserForm extends StatefulWidget {
  @override
  _AddUserFormState createState() => _AddUserFormState();
}

class _AddUserFormState extends State<AddUserForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  String _newUserRole = 'athlete';
  String? _selectedCoach;
  String? _selectedSportType;
  String _jerseyNumber = '';
  bool _isCreating = false;
  String? _selectedOrganizationId;
  List<Map<String, dynamic>> _organizations = [];
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    try {
      final organizations = await _userService.getAllOrganizations();
      if (mounted) {
        setState(() {
          _organizations = organizations;
        });
      }
    } catch (e) {
      print('Error loading organizations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: defaultPadding),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: defaultPadding),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonFormField<String>(
              value: _newUserRole,
              dropdownColor: secondaryColor,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.badge_outlined),
                labelStyle: TextStyle(color: Colors.white70),
              ),
              items: ['admin', 'coach', 'athlete', 'organization', 'medical']
                  .map((role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(role.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _newUserRole = value!;
                  // Clear organization selection if not an athlete
                  if (_newUserRole != 'athlete') {
                    _selectedOrganizationId = null;
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a role';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: defaultPadding * 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isCreating ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: defaultPadding),
              ElevatedButton(
                onPressed: _isCreating ? null : _createUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create User'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _createUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);
      try {
        await _userService.createUser(
          name: _nameController.text,
          email: _emailController.text,
          role: _newUserRole,
          coachId: _newUserRole == 'athlete' ? _selectedCoach : null,
          sportsType: _newUserRole == 'athlete' ? _selectedSportType : null,
          jerseyNumber: _newUserRole == 'athlete' ? _jerseyNumber : null,
          organizationId: _newUserRole == 'athlete' ? _selectedOrganizationId : null,
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User created successfully. Welcome email sent!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating user: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class EditUserForm extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const EditUserForm({
    Key? key,
    required this.userId,
    required this.userData,
  }) : super(key: key);

  @override
  _EditUserFormState createState() => _EditUserFormState();
}

class _EditUserFormState extends State<EditUserForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final UserService _userService = UserService();
  late String _selectedRole;
  bool _isUpdating = false;
  String? _selectedOrganizationId;
  List<Map<String, dynamic>> _organizations = [];
  bool _isLoadingOrganizations = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _emailController = TextEditingController(text: widget.userData['email']);
    _selectedRole = widget.userData['role'] ?? 'athlete';
    _selectedOrganizationId = widget.userData['organizationId'];
    
    // Debug log
    print('Initializing EditUserForm with:');
    print('- Name: ${widget.userData['name']}');
    print('- Email: ${widget.userData['email']}');
    print('- Role: $_selectedRole');
    print('- Organization ID: $_selectedOrganizationId');
    
    _loadOrganizations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    try {
      setState(() {
        _isLoadingOrganizations = true;
      });
      
      final organizations = await _userService.getAllOrganizations();
      
      if (mounted) {
        setState(() {
          _organizations = organizations;
          _isLoadingOrganizations = false;
          
          // Check if the selected organization exists in the loaded organizations
          if (_selectedOrganizationId != null) {
            bool organizationExists = _organizations.any((org) => org['id'] == _selectedOrganizationId);
            if (!organizationExists) {
              // If the organization doesn't exist in the list, set it to null
              print('Organization ID $_selectedOrganizationId not found in list, setting to null');
              _selectedOrganizationId = null;
            } else {
              print('Organization ID $_selectedOrganizationId found in list, keeping it');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOrganizations = false;
        });
      }
      print('Error loading organizations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isMobile = Responsive.isMobile(context);
    final double padding = screenSize.width < 380 ? 8.0 : (isMobile ? defaultPadding / 2 : defaultPadding);
    final double fontSize = screenSize.width < 380 ? 12.0 : (isMobile ? 14.0 : 16.0);
    final double iconSize = screenSize.width < 380 ? 16.0 : (isMobile ? 20.0 : 24.0);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white70, size: iconSize),
                        SizedBox(width: padding),
                        Flexible(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: fontSize + 2,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white70, size: iconSize),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            SizedBox(height: padding),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    fontSize: fontSize,
                    iconSize: iconSize,
                    padding: padding,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: padding),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    fontSize: fontSize,
                    iconSize: iconSize,
                    padding: padding,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: padding),
                  _buildRoleDropdown(fontSize, iconSize, padding),
                  SizedBox(height: padding),
                  
                  // Show organization dropdown only for athletes
                  if (_selectedRole == 'athlete') ...[
                    _buildOrganizationDropdown(fontSize, iconSize, padding),
                    SizedBox(height: padding),
                  ],

                  // Action Buttons
                  Container(
                    height: 45,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isUpdating ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding * 1.5,
                              vertical: padding,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: fontSize,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        SizedBox(width: padding),
                        ElevatedButton(
                          onPressed: _isUpdating ? null : _updateUser,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding * 1.5,
                              vertical: padding,
                            ),
                            backgroundColor: Colors.blue,
                          ),
                          child: _isUpdating
                              ? SizedBox(
                                  width: iconSize,
                                  height: iconSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Update',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double fontSize,
    required double iconSize,
    required double padding,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white70,
            fontSize: fontSize - 2,
          ),
          prefixIcon: Icon(icon, color: Colors.white70, size: iconSize),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(padding),
          errorStyle: TextStyle(fontSize: fontSize - 2),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(double fontSize, double iconSize, double padding) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding),
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        dropdownColor: secondaryColor,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
        ),
        decoration: InputDecoration(
          labelText: 'Role',
          labelStyle: TextStyle(
            color: Colors.white70,
            fontSize: fontSize - 2,
          ),
          prefixIcon: Icon(Icons.badge_outlined, color: Colors.white70, size: iconSize),
          border: InputBorder.none,
        ),
        items: ['admin', 'coach', 'athlete', 'organization', 'medical']
            .map((role) => DropdownMenuItem<String>(
                  value: role,
                  child: Text(role.toUpperCase()),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedRole = value!;
            // Clear organization selection if not an athlete
            if (_selectedRole != 'athlete') {
              _selectedOrganizationId = null;
            }
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a role';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildOrganizationDropdown(double fontSize, double iconSize, double padding) {
    // Debug log
    print('Building organization dropdown with selected ID: $_selectedOrganizationId');
    print('Available organizations: ${_organizations.map((org) => '${org['id']}: ${org['name']}').join(', ')}');
    
    // If still loading organizations, show a loading indicator
    if (_isLoadingOrganizations) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: padding),
        decoration: BoxDecoration(
          color: secondaryColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
                SizedBox(width: 10),
                Text('Loading organizations...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }
    
    // Check if the selected organization exists in the list
    bool organizationExists = _organizations.any((org) => org['id'] == _selectedOrganizationId);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding),
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonFormField<String?>(
        value: organizationExists ? _selectedOrganizationId : null,
        dropdownColor: secondaryColor,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
        ),
        decoration: InputDecoration(
          labelText: 'Organization',
          labelStyle: TextStyle(
            color: Colors.white70,
            fontSize: fontSize - 2,
          ),
          prefixIcon: Icon(Icons.business, color: Colors.white70, size: iconSize),
          border: InputBorder.none,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('None'),
          ),
          ..._organizations.map((org) => DropdownMenuItem<String?>(
            value: org['id'],
            child: Text(org['name']),
          )).toList(),
        ],
        onChanged: (value) {
          print('Organization dropdown changed to: $value');
          setState(() {
            _selectedOrganizationId = value;
          });
        },
        validator: (value) {
          // Organization is optional
          return null;
        },
      ),
    );
  }

  void _updateUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUpdating = true);
      try {
        // Check if email is being changed
        bool isEmailChanged = _emailController.text != widget.userData['email'];
        
        // Create a map of fields to update
        Map<String, dynamic> updateData = {
          'name': _nameController.text,
          'role': _selectedRole,
        };
        
        // Only include organizationId for athletes
        if (_selectedRole == 'athlete') {
          // Always include organizationId in the update, even if it's null
          // This ensures it gets removed if set to null
          updateData['organizationId'] = _selectedOrganizationId;
          print('Updating athlete with organizationId: $_selectedOrganizationId');
        } else if (widget.userData['organizationId'] != null) {
          // If user was an athlete before and had an organizationId, but now is not an athlete,
          // explicitly set organizationId to null to remove it
          updateData['organizationId'] = null;
          print('Removing organizationId as user is no longer an athlete');
        }
        
        // Update user in Firestore without changing email
        await _userService.updateUserFields(
          widget.userId,
          updateData,
        );
        
        // If email is changed, show a special message
        if (isEmailChanged) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email changes require verification. Please contact admin to change email.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        print('Error updating user: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUpdating = false);
        }
      }
    }
  }
}
