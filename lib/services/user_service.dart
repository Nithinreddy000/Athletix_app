import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';  // Add this import for TimeoutException
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/sport_metrics.dart';
import '../models/sport_type.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // API Base URL
  static const String _baseUrl = 'https://ams-backend-jqah.onrender.com/api';  // Production URL
  static const String _emailJsServiceId = 'service_6fqupjh';
  static const String _emailJsTemplateId = 'template_rf3fd37';
  static const String _emailJsUserId = 'VGuXR05FrNVOAU_BF';  // This is your public key

  // Generate secure password
  String _generateSecurePassword() {
    const String upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lowerCase = 'abcdefghijklmnopqrstuvwxyz';
    const String numbers = '0123456789';
    const String special = '@#\$%^&*';
    
    String chars = '';
    chars += upperCase;
    chars += lowerCase;
    chars += numbers;
    chars += special;

    return List.generate(12, (index) {
      final randomIndex = Random.secure().nextInt(chars.length);
      return chars[randomIndex];
    }).join('');
  }

  // Send welcome email
  Future<void> _sendWelcomeEmail({
    required String email,
    required String name,
    required String password,
    required String role,
  }) async {
    try {
      print('🔄 Sending welcome email to $email...');
      
      // Get role-specific template data
      final templateData = _getWelcomeTemplateData(role);
      
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',  // Add your domain in production
        },
        body: json.encode({
          'service_id': _emailJsServiceId,
          'template_id': _emailJsTemplateId,
          'user_id': _emailJsUserId,
          'accessToken': _emailJsUserId,  // Using public key as access token
          'template_params': {
            'to_email': email,
            'to_name': name,
            'user_password': password,
            'user_role': role.toUpperCase(),
            'welcome_message': templateData['message'],
            'role_description': templateData['description'],
            'next_steps': templateData['nextSteps'],
            'role_style': _getRoleStyle(role),
          },
        }),
      );

      print('📧 Email API Response Status: ${response.statusCode}');
      print('📧 Email API Response Body: ${response.body}');

      if (response.statusCode != 200) {
        print('❌ Failed to send email: ${response.body}');
        throw Exception('Failed to send welcome email: ${response.body}');
      }
      
      print('✅ Welcome email sent successfully');
    } catch (e) {
      print('❌ Error sending welcome email: $e');
      // Don't throw error as this shouldn't block user creation
    }
  }

  // Get role-specific welcome template data
  Map<String, String> _getWelcomeTemplateData(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return {
          'message': 'Welcome to the AMS Admin Team! 🌟',
          'description': 'As an Administrator, you have full access to manage the system and its users.',
          'nextSteps': '1. Log in to your account\n2. Review system settings\n3. Explore admin dashboard\n4. Set up user roles and permissions',
        };
      case 'coach':
        return {
          'message': 'Welcome to AMS, Coach! 🏆',
          'description': 'As a Coach, you\'ll be able to manage athletes and create training programs.',
          'nextSteps': '1. Log in to your account\n2. Set up your profile\n3. Start managing your athletes\n4. Create training schedules',
        };
      case 'athlete':
        return {
          'message': 'Welcome to AMS, Athlete! 💪',
          'description': 'Track your progress, view workouts, and stay connected with your coaches.',
          'nextSteps': '1. Log in to your account\n2. Complete your athlete profile\n3. View your training schedule\n4. Start tracking your progress',
        };
      case 'organization':
        return {
          'message': 'Welcome to AMS! 🏢',
          'description': 'Manage your organization\'s sports programs and athletes effectively.',
          'nextSteps': '1. Log in to your account\n2. Set up organization profile\n3. Add team members\n4. Review analytics dashboard',
        };
      case 'medical':
        return {
          'message': 'Welcome to AMS Medical Team! ⚕️',
          'description': 'Monitor athlete health and manage medical records securely.',
          'nextSteps': '1. Log in to your account\n2. Set up your medical profile\n3. Review athlete records\n4. Set up health monitoring protocols',
        };
      default:
        return {
          'message': 'Welcome to AMS! 👋',
          'description': 'We\'re excited to have you join our platform.',
          'nextSteps': '1. Log in to your account\n2. Complete your profile\n3. Explore the dashboard\n4. Get started with your activities',
        };
    }
  }

  // Get role-specific style
  String _getRoleStyle(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'background-color: #ef5350; color: white;';
      case 'coach':
        return 'background-color: #66bb6a; color: white;';
      case 'athlete':
        return 'background-color: #42a5f5; color: white;';
      case 'organization':
        return 'background-color: #ffa726; color: white;';
      case 'medical':
        return 'background-color: #ab47bc; color: white;';
      default:
        return 'background-color: #78909c; color: white;';
    }
  }

  // Get all users including admin
  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection('users').snapshots();
  }

  // Get recent users including admin
  Stream<QuerySnapshot> getRecentUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();
  }

  // Get user by ID
  Future<DocumentSnapshot> getUserById(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      print('🔄 Starting profile update process...');

      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Check permissions
      final isCurrentUserAdmin = await isUserAdmin();
      final isOwnProfile = currentUser.uid == uid;

      if (!isCurrentUserAdmin && !isOwnProfile) {
        throw Exception('You do not have permission to update this profile');
      }

      // Get current user data
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      final currentData = userDoc.data() as Map<String, dynamic>;

      // Prepare update data
      Map<String, dynamic> updateData = {};

      if (!isCurrentUserAdmin && isOwnProfile) {
        // Regular users can only update these fields
        final allowedFields = ['name', 'phone', 'address'];
        allowedFields.forEach((field) {
          if (data.containsKey(field)) {
            updateData[field] = data[field];
          }
        });

        // Preserve other fields from current data
        ['role', 'email', 'isActive', 'createdAt', 'permissions'].forEach((field) {
          if (currentData.containsKey(field)) {
            updateData[field] = currentData[field];
          }
        });
      } else if (isCurrentUserAdmin) {
        // Admins can update all fields
        updateData = Map<String, dynamic>.from(data);
      }

      // Add timestamp
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      // Update profile in Firestore
      print('📝 Updating profile in Firestore...');
      await _firestore.collection('users').doc(uid).update(updateData);
      print('✅ Updated profile in Firestore');

      // If updating name, also update in Firebase Auth
      if (updateData.containsKey('name') && isOwnProfile) {
        print('✏️ Updating display name in Firebase Auth...');
        await currentUser.updateProfile(displayName: updateData['name']);
        print('✅ Updated display name in Firebase Auth');
      }

      print('✅ Profile update completed successfully');
    } catch (e) {
      print('❌ Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Update user role
  Future<void> updateUserRole(String uid, String role) {
    return _firestore.collection('users').doc(uid).update({
      'role': role.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Store admin credentials for reauth
  Future<void> storeAdminDeleteAttempt(String adminEmail, String adminPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temp_admin_email', adminEmail);
    await prefs.setString('temp_admin_password', adminPassword);
  }

  // Clear admin credentials
  Future<void> clearAdminDeleteAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('temp_admin_email');
    await prefs.remove('temp_admin_password');
  }

  // Get admin credentials from credentials collection
  Future<Map<String, String>> getAdminCredentials() async {
    try {
      print('🔄 Getting admin credentials...');
      DocumentSnapshot credDoc = await _firestore
          .collection('user_credentials')
          .doc('admin@ams.com')
          .get();

      if (!credDoc.exists) {
        print('❌ Admin credentials not found');
        throw Exception('Admin credentials not found');
      }

      final credData = credDoc.data() as Map<String, dynamic>;
      print('✅ Got admin credentials');
      return {
        'email': credData['email'] as String,
        'password': credData['password'] as String,
      };
    } catch (e) {
      print('❌ Error getting admin credentials: $e');
      throw Exception('Failed to get admin credentials: $e');
    }
  }

  // Get user credentials
  Future<Map<String, String>?> getUserCredentials(String email) async {
    try {
      DocumentSnapshot credDoc = await _firestore
          .collection('user_credentials')
          .doc(email)
          .get();

      if (!credDoc.exists) {
        return null;
      }

      final credData = credDoc.data() as Map<String, dynamic>;
      return {
        'email': credData['email'] as String,
        'password': credData['password'] as String,
      };
    } catch (e) {
      print('Error getting user credentials: $e');
      return null;
    }
  }

  // Store user credentials
  Future<void> storeUserCredentials(String email, String password) async {
    try {
      print('🔄 Storing user credentials...');
      
      // Get current user's email
      final currentUserEmail = _auth.currentUser?.email;
      print('👤 Current user email: $currentUserEmail');

      // If not admin, get admin credentials and sign in
      if (currentUserEmail != 'admin@ams.com') {
        print('🔄 Not admin, getting admin credentials...');
        final adminCreds = await getAdminCredentials();
        
        // Store current user credentials if any
        String? previousEmail = _auth.currentUser?.email;
        String? previousPassword;
        if (previousEmail != null) {
          var prevCreds = await getUserCredentials(previousEmail);
          previousPassword = prevCreds?['password'];
        }

        // Sign in as admin
        print('👑 Signing in as admin...');
        await _auth.signInWithEmailAndPassword(
          email: adminCreds['email']!,
          password: adminCreds['password']!,
        );
        print('✅ Signed in as admin');

        // Store the credentials
        await _firestore.collection('user_credentials').doc(email).set({
          'email': email,
          'password': password,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Stored user credentials');

        // Sign back in as previous user if there was one
        if (previousEmail != null && previousPassword != null) {
          print('🔄 Signing back in as previous user...');
          await _auth.signInWithEmailAndPassword(
            email: previousEmail,
            password: previousPassword,
          );
          print('✅ Signed back in as previous user');
        }
      } else {
        // Already admin, just store the credentials
        await _firestore.collection('user_credentials').doc(email).set({
          'email': email,
          'password': password,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Stored user credentials as admin');
      }
    } catch (e) {
      print('❌ Error storing user credentials: $e');
      throw Exception('Failed to store user credentials: $e');
    }
  }

  // Delete user credentials
  Future<void> deleteUserCredentials(String email) async {
    try {
      await _firestore.collection('user_credentials').doc(email).delete();
    } catch (e) {
      print('Error deleting user credentials: $e');
    }
  }

  // Migrate existing user to credentials collection
  Future<void> migrateUserCredentials(String email, String password) async {
    try {
      // Check if credentials already exist
      DocumentSnapshot credDoc = await _firestore
          .collection('user_credentials')
          .doc(email)
          .get();

      if (!credDoc.exists) {
        // Store credentials if they don't exist
        await storeUserCredentials(email, password);
      }
    } catch (e) {
      print('Error migrating user credentials: $e');
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['role'] == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Check if user can be modified (prevent admin modification)
  Future<bool> canModifyUser(String uid) async {
    try {
      // Get the target user's data
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // If target user is admin, prevent modification
      if (userData['role'] == 'admin') {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking if user can be modified: $e');
      return false;
    }
  }

  // Create new user
  Future<void> createUser({
    required String name,
    required String email,
    required String role,
    String? coachId,
    String? sportsType,
    String? jerseyNumber,
    String? organizationId,
  }) async {
    try {
      print('🔄 Starting user creation process...');
      
      // Verify admin status
      if (!(await isUserAdmin())) {
        throw Exception('Admin privileges required to create users');
      }
      
      // Generate a secure password
      final String password = _generateSecurePassword();
      
      // Create user data
      Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Add organization ID for athletes if provided
      if (role == 'athlete' && organizationId != null) {
        userData['organizationId'] = organizationId;
      }

      // Add additional fields for athletes
      if (role == 'athlete') {
        if (coachId == null) throw Exception('Coach ID is required for athletes');
        if (sportsType == null) throw Exception('Sport type is required for athletes');
        if (jerseyNumber == null) throw Exception('Jersey number is required for athletes');

        // Verify jersey number uniqueness for the team
        final existingAthletes = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'athlete')
            .where('coachId', isEqualTo: coachId)
            .where('sportsType', isEqualTo: sportsType)
            .where('jerseyNumber', isEqualTo: jerseyNumber)
            .get();

        if (existingAthletes.docs.isNotEmpty) {
          throw Exception('Jersey number $jerseyNumber is already taken in this team');
        }

        userData.addAll({
          'coachId': coachId,
          'sportsType': sportsType,
          'jerseyNumber': jerseyNumber,
          'sportSpecificMetrics': SportMetrics.getDefaultMetrics(
            SportType.values.firstWhere(
              (e) => e.toString().split('.').last == sportsType,
            ),
          ),
        });
      }

      print('👤 Creating user in Firebase Auth...');
      
      // Make request to backend to create user
      final idToken = await _auth.currentUser?.getIdToken(true);
      if (idToken == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/createUser'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken'
        },
        body: json.encode({
          'email': email,
          'password': password,
          'displayName': name,
          'role': role,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create user in Authentication');
      }

      final responseData = json.decode(response.body);
      final String newUserId = responseData['uid'];
      
      // Create user document in Firestore
      print('📝 Creating user document in Firestore...');
      await _firestore
          .collection('users')
          .doc(newUserId)
          .set(userData);
      
      // Send welcome email
      print('📧 Sending welcome email...');
      await _sendWelcomeEmail(
        email: email,
        name: name,
        password: password,
        role: role,
      );
      
      print('✅ User creation completed successfully');
    } catch (e) {
      print('❌ Error creating user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  // Delete user with admin backend
  Future<void> deleteUser(String uid) async {
    try {
      // First check if the target user can be modified
      final canModify = await canModifyUser(uid);
      if (!canModify) {
        throw Exception('Cannot delete admin users');
      }

      print('🔄 Starting user deletion process...');
      
      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Verify admin status
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists || (userDoc.data() as Map<String, dynamic>)['role'] != 'admin') {
        // Force token refresh and try again
        await currentUser.getIdToken(true);
        await Future.delayed(const Duration(seconds: 1));
        
        // Check admin status again
        final refreshedDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (!refreshedDoc.exists || (refreshedDoc.data() as Map<String, dynamic>)['role'] != 'admin') {
          throw Exception('Unauthorized: Admin access required');
        }
      }

      // Get current user's ID token
      final idToken = await currentUser.getIdToken(true);
      
      // Make request to backend
      final response = await http.post(
        Uri.parse('$_baseUrl/deleteUser'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken'
        },
        body: json.encode({'uid': uid}),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to delete user');
      }

      print('✅ User deletion completed successfully');
    } catch (e) {
      print('❌ Error during deletion process: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get user statistics including admin
  Stream<Map<String, int>> getUserStatistics() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      Map<String, int> stats = {
        'total': 0,
        'admin': 0,
        'coach': 0,
        'athlete': 0,
        'organization': 0,
        'medical': 0,
      };
      
      for (var doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        stats['total'] = (stats['total'] ?? 0) + 1;
        
        String role = userData['role']?.toString().toLowerCase() ?? '';
        if (userData['email'] == 'admin@ams.com') {
          role = 'admin';
        }
        
        switch (role) {
          case 'admin':
            stats['admin'] = (stats['admin'] ?? 0) + 1;
            break;
          case 'coach':
            stats['coach'] = (stats['coach'] ?? 0) + 1;
            break;
          case 'athlete':
          case 'user':
            stats['athlete'] = (stats['athlete'] ?? 0) + 1;
            break;
          case 'organization':
            stats['organization'] = (stats['organization'] ?? 0) + 1;
            break;
          case 'medical':
            stats['medical'] = (stats['medical'] ?? 0) + 1;
            break;
        }
      }
      
      return stats;
    });
  }

  // Get role permissions
  Future<Map<String, List<String>>> getRolePermissions() async {
    final snapshot = await _firestore.collection('roles').get();
    
    Map<String, List<String>> permissions = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      permissions[doc.id] = List<String>.from(data['permissions'] ?? []);
    }
    
    return permissions;
  }

  // Update role permissions
  Future<void> updateRolePermissions(String role, List<String> permissions) {
    return _firestore.collection('roles').doc(role).set({
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Search users
  Future<List<DocumentSnapshot>> searchUsers(String query) {
    return _firestore
        .collection('users')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  // Update user
  Future<void> updateUser(String uid, {String? name, String? email, String? role, String? organizationId}) async {
    try {
      // Update user in Firestore
      await _firestore.collection('users').doc(uid).update({
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (role != null) 'role': role,
        if (organizationId != null) 'organizationId': organizationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user in Firebase Auth if email is provided
      if (email != null) {
        User? user = _auth.currentUser;
        if (user != null && user.uid == uid) {
          await user.updateEmail(email);
        } else {
          // For admin updating another user's email
          // This requires special handling and might not work directly
          print('Warning: Updating another user\'s email requires special handling');
        }
      }
    } catch (e) {
      print('Error updating user: $e');
      throw e;
    }
  }

  // Update user fields without changing email
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      print('🔄 Updating user fields for $uid: ${fields.toString()}');
      
      // Add updatedAt timestamp
      fields['updatedAt'] = FieldValue.serverTimestamp();
      
      // Update user in Firestore
      await _firestore.collection('users').doc(uid).update(fields);
      
      print('✅ Successfully updated user fields for $uid');
      
      // Verify the update by reading the document
      final updatedDoc = await _firestore.collection('users').doc(uid).get();
      if (updatedDoc.exists) {
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        print('📄 Updated user data: ${updatedData.toString()}');
        
        // Check if organizationId was properly updated
        if (fields.containsKey('organizationId')) {
          final updatedOrgId = updatedData['organizationId'];
          print('🏢 Updated organizationId: $updatedOrgId');
        }
      }
    } catch (e) {
      print('❌ Error updating user fields: $e');
      throw e;
    }
  }

  // Delete multiple users
  Future<void> deleteMultipleUsers(List<String> userIds) async {
    try {
      print('🔄 Starting batch deletion process for ${userIds.length} users...');
      
      // Split into smaller batches of 5 users to prevent timeout
      final int batchSize = 5;
      final List<List<String>> batches = [];
      
      for (var i = 0; i < userIds.length; i += batchSize) {
        final end = (i + batchSize < userIds.length) ? i + batchSize : userIds.length;
        batches.add(userIds.sublist(i, end));
      }

      // Get current user's ID token for authentication
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) {
        throw Exception('No authentication token available');
      }
      
      // Process each batch
      for (var batch in batches) {
        print('📦 Processing batch of ${batch.length} users...');
        
        // First get user data for each user in the batch
        final List<Map<String, dynamic>> usersData = [];
        for (String uid in batch) {
          try {
            final userData = await _firestore.collection('users').doc(uid).get();
            if (userData.exists) {
              usersData.add({
                'uid': uid,
                'email': userData.data()?['email'],
                'role': userData.data()?['role'],
              });
            }
          } catch (e) {
            print('⚠️ Error fetching user data for $uid: $e');
          }
        }

        // Delete from Firestore first (as it's reversible)
        print('🗑️ Deleting users from Firestore...');
        final WriteBatch firestoreBatch = _firestore.batch();
        for (String uid in batch) {
          firestoreBatch.delete(_firestore.collection('users').doc(uid));
        }
        await firestoreBatch.commit();
        
        // Then delete from Authentication using backend API
        print('🗑️ Deleting users from Authentication...');
        try {
          final response = await http.post(
            Uri.parse('$_baseUrl/delete-users'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode({
              'userIds': batch.map((uid) => uid).toList(),
              'emails': usersData.map((user) => user['email']).toList(),
            }),
          ).timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to delete users from authentication: ${response.body}');
          }

          print('✅ Successfully deleted batch from Authentication');
        } catch (e) {
          print('⚠️ Error deleting users from Authentication: $e');
          if (e is TimeoutException) {
            // If it's a timeout, wait and retry once
            try {
              print('🔄 Retrying batch deletion after timeout...');
              await Future.delayed(Duration(seconds: 2));
              
              final retryResponse = await http.post(
                Uri.parse('$_baseUrl/delete-users'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: json.encode({
                  'userIds': batch.map((uid) => uid).toList(),
                  'emails': usersData.map((user) => user['email']).toList(),
                }),
              ).timeout(Duration(seconds: 30));

              if (retryResponse.statusCode != 200) {
                throw Exception('Retry failed: ${retryResponse.body}');
              }
              
              print('✅ Retry successful for batch');
            } catch (retryError) {
              print('❌ Retry failed: $retryError');
              throw Exception('Failed to delete users after retry: $retryError');
            }
          } else {
            throw Exception('Failed to delete users: $e');
          }
        }
        
        // Add delay between batches
        if (batches.last != batch) {
          print('⏳ Waiting before processing next batch...');
          await Future.delayed(Duration(seconds: 2));
        }
      }
      
      print('✅ Batch deletion process completed successfully');
    } catch (e) {
      print('❌ Error during batch deletion process: $e');
      throw Exception('Error during batch deletion process: $e');
    }
  }

  // Get all organizations
  Future<List<Map<String, dynamic>>> getAllOrganizations() async {
    try {
      print('🔄 Fetching all organizations...');
      
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'organization')
          .get();
      
      final organizations = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Organization',
        };
      }).toList();
      
      print('✅ Fetched ${organizations.length} organizations');
      for (var org in organizations) {
        print('  - ${org['id']}: ${org['name']}');
      }
      
      return organizations;
    } catch (e) {
      print('❌ Error fetching organizations: $e');
      return [];
    }
  }
}