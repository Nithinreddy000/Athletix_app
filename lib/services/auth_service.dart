import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '410293317488-5g573vf9qpuovc4aah25mk32sv75s97b.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Google OAuth Configuration
  static const String googleClientId = '410293317488-5g573vf9qpuovc4aah25mk32sv75s97b.apps.googleusercontent.com';
  static const String googleClientSecret = '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';
  static const String projectId = 'aerobic-oxide-447807-v2';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Admin credentials
  static const String adminEmail = "admin@ams.com";
  static const String adminPassword = "Admin@123";

  // Create admin account
  Future<void> createAdminAccount() async {
    try {
      // Check if admin already exists in Firebase Auth
      try {
        await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        // If successful, admin exists, sign out and return
        await _auth.signOut();
        return;
      } catch (e) {
        // Admin doesn't exist in Auth, continue with creation
      }

      // Check if admin exists in Firestore
      var adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('email', isEqualTo: adminEmail)
          .get();
      
      if (adminQuery.docs.isEmpty) {
        // Create admin user in Firebase Auth
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );

        // Set admin data in Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': adminEmail,
          'role': 'admin',
          'name': 'System Admin',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        // Sign out after creation
        await _auth.signOut();
        print('Admin account created successfully');
      } else {
        print('Admin account already exists in Firestore');
      }
    } catch (e) {
      print('Error creating admin account: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // Sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user document
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw 'User not found in database';
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // If user is admin, ensure claims are set
      if (userData['role'] == 'admin') {
        // Force token refresh
        await userCredential.user!.getIdToken(true);
        
        // Wait for a short time to allow token propagation
        await Future.delayed(const Duration(seconds: 1));
        
        // Verify admin claims
        final idTokenResult = await userCredential.user!.getIdTokenResult(true);
        if (idTokenResult.claims?['admin'] != true) {
          // If claims aren't set, try refreshing again
          await Future.delayed(const Duration(seconds: 2));
          await userCredential.user!.getIdToken(true);
        }
      }

      // Update last login
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      
      return userCredential;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Check if user exists in Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      if (!userDoc.exists) {
        // Create new user document
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isActive': true,
          'authProvider': 'google',
        });
      } else {
        // Update last login
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.exists && 
             (userDoc.data() as Map<String, dynamic>)['role'] == 'admin' &&
             (userDoc.data() as Map<String, dynamic>)['isActive'] == true;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get user role
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        return (userDoc.data() as Map<String, dynamic>)['role'];
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }
} 