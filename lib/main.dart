import 'package:dating/chat_page.dart';
import 'package:dating/profiles.dart';
import 'package:dating/update_profile.dart';
import 'package:flutter/material.dart';
import 'package:dating/welcome_screen.dart';
import 'package:dating/login.dart';
import 'package:dating/signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'services/auth_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
      if (kDebugMode) {
        print('Firebase initialized (web) with SESSION persistence');
      }
    } else {
      if (kDebugMode) {
        print('Firebase initialized (mobile) with default persistence');
      }
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
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/profiles': (context) => const Profiles(),
        '/Chat_page': (context) => const ChatPage(),
        '/update_profile': (context) => const UpdateProfile(),
        '/chat': (context) => const ChatPage(),
        // '/likes': (context) => const LikesScreen(),
        // '/chats': (context) => const ChatsScreen(),
        // '/search': (context) => const SearchScreen(),
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
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // No user logged in
        if (!snapshot.hasData) {
          if (kDebugMode) {
            print('No user found → Welcome Screen');
          }
          return const WelcomeScreen();
        }

        final user = snapshot.data!;
        if (!user.emailVerified) {
          if (kDebugMode) {
            print('User ${user.email} not verified → Ask for verification');
          }
          return const Scaffold(
            body: Center(child: Text('Please verify your email to continue.')),
          );
        }

        if (kDebugMode) {
          print('User ${user.email} logged in & verified → Profiles');
        }
        return const Profiles();
      },
    );
  }
}
