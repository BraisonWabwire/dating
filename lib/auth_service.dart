import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        if (kDebugMode) {
          print('Verification email sent to ${userCredential.user!.email}');
        }
      }
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Signup error: ${e.code} - ${e.message}');
      }
      throw Exception(_handleAuthException(e));
    }
  }

  // Log in with email and password
  Future<User?> loginWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (kDebugMode) {
        print('User logged in: ${userCredential.user?.email}, Verified: ${userCredential.user?.emailVerified}');
      }
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Login error: ${e.code} - ${e.message}');
      }
      throw Exception(_handleAuthException(e));
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      if (kDebugMode) {
        print('Password reset email sent to $email');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Password reset error: ${e.code} - ${e.message}');
      }
      throw Exception(_handleAuthException(e));
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kDebugMode) {
        print('User signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      throw Exception('Failed to sign out: $e');
    }
  }

  // Handle FirebaseAuth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'invalid-credential':
        return 'Invalid credentials provided.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  // Get current user
  User? getCurrentUser() {
    final user = _auth.currentUser;
    if (kDebugMode) {
      print('Current user: ${user?.email}, Verified: ${user?.emailVerified}');
    }
    return user;
  }

  // Check if email is verified
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.reload();
        if (kDebugMode) {
          print('Email verification check for ${user.email}: ${user.emailVerified}');
        }
        return user.emailVerified;
      } catch (e) {
        if (kDebugMode) {
          print('Error checking email verification: $e');
        }
        return false;
      }
    }
    return false;
  }
}