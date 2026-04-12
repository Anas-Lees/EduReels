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
      _error = e.toString();
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
}
