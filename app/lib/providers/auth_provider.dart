import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;
  StreamSubscription<User?>? _authSubscription;

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;

  AuthProvider() {
    _authSubscription = AuthService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.signInWithGoogle();
      _loading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = _parseGoogleError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.signInWithEmail(email, password);
      _loading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = _parseFirebaseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.signUpWithEmail(email, password, name);
      _loading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = _parseFirebaseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    _user = null;
    notifyListeners();
  }

  String _parseFirebaseError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'email-already-in-use':
          return 'Email already registered';
        case 'weak-password':
          return 'Password is too weak';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return e.message ?? 'Authentication failed';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  String _parseGoogleError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('sign_in_failed') || msg.contains('api.j: 10')) {
      return 'Google Sign-In is not configured for this device. Please use email/password instead.';
    }
    if (msg.contains('network_error') || msg.contains('ApiException: 7')) {
      return 'Network error. Check your internet connection.';
    }
    if (msg.contains('sign_in_cancelled') || msg.contains('ApiException: 12501')) {
      return null ?? 'Sign-in was cancelled.';
    }
    if (msg.contains('popup_closed') || msg.contains('popup-closed-by-user')) {
      return 'Sign-in popup was closed. Please try again.';
    }
    return 'Google Sign-In failed. Please try email/password.';
  }
}
