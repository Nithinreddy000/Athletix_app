import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SessionService {
  static const String _tokenKey = 'session_token';
  static const String _expiryKey = 'session_expiry';
  static const String _roleKey = 'user_role';
  static const Duration sessionDuration = Duration(hours: 1);

  final SharedPreferences _prefs;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SessionService(this._prefs);

  static Future<SessionService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionService(prefs);
  }

  Future<void> createSession(User user) async {
    final expiryTime = DateTime.now().add(sessionDuration);
    await _prefs.setString(_tokenKey, user.uid);
    await _prefs.setString(_expiryKey, expiryTime.toIso8601String());
    
    // Set persistence to LOCAL only on web platform
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }
  }

  Future<void> setUserRole(String role) async {
    await _prefs.setString(_roleKey, role);
  }

  String? get userRole => _prefs.getString(_roleKey);

  Future<void> clearSession() async {
    try {
      await _prefs.remove(_tokenKey);
      await _prefs.remove(_expiryKey);
      await _prefs.remove(_roleKey);
      await _prefs.clear();
      await _auth.signOut();
      
      // Set persistence to NONE only on web platform
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.NONE);
      }
    } catch (e) {
      print('Error clearing session: $e');
    }
  }

  bool get hasValidSession {
    final token = _prefs.getString(_tokenKey);
    final expiryString = _prefs.getString(_expiryKey);
    final currentUser = _auth.currentUser;
    
    if (token == null || expiryString == null || currentUser == null) return false;
    
    try {
      final expiry = DateTime.parse(expiryString);
      if (DateTime.now().isAfter(expiry)) {
        clearSession();
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> checkAndRefreshSession() async {
    if (!hasValidSession) {
      await clearSession();
    } else {
      // Refresh the session duration
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await createSession(currentUser);
      }
    }
  }
} 