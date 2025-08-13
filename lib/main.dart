import 'package:dating/chat_page.dart';
import 'package:dating/profiles.dart';
import 'package:dating/update_profile.dart';
import 'package:dating/email_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:dating/welcome_screen.dart';
import 'package:dating/login.dart';
import 'package:dating/signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'auth_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.setPersistence(
      kIsWeb ? Persistence.SESSION : Persistence.LOCAL,
    );
    if (kDebugMode) {
      print('Firebase initialized, persistence set to ${kIsWeb ? "SESSION" : "LOCAL"}');
    }
    runApp(const MyApp());
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initialization error: $e');
    }
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to initialize Firebase: $e')),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dating App',
      home: const AuthWrapper(),
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/profiles': (context) => const Profiles(),
        '/Chat_page': (context) => const ChatPage(),
        '/update_profile': (context) => const UpdateProfile(),
        '/email_verification': (context) => const EmailVerificationScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (kDebugMode) {
          print('Auth state: connection=${snapshot.connectionState}, user=${snapshot.data?.email}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('Auth state error: ${snapshot.error}');
          }
          return const Scaffold(
            body: Center(child: Text('Error loading authentication state')),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<bool>(
            future: AuthService().isEmailVerified(),
            builder: (context, emailSnapshot) {
              if (kDebugMode) {
                print('Email verification state: ${emailSnapshot.data}, error: ${emailSnapshot.error}');
              }
              if (emailSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (emailSnapshot.hasError) {
                if (kDebugMode) {
                  print('Email verification error: ${emailSnapshot.error}');
                }
                return const Scaffold(
                  body: Center(child: Text('Error checking email verification')),
                );
              }
              if (emailSnapshot.hasData && emailSnapshot.data == true) {
                if (kDebugMode) {
                  print('Redirecting to Profiles for verified user: ${snapshot.data!.email}');
                }
                return const Profiles();
              } else {
                if (kDebugMode) {
                  print('Redirecting to EmailVerificationScreen for unverified user: ${snapshot.data!.email}');
                }
                return const EmailVerificationScreen();
              }
            },
          );
        }
        if (kDebugMode) {
          print('No user logged in, redirecting to WelcomeScreen');
        }
        return const WelcomeScreen();
      },
    );
  }
}