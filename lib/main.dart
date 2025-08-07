import 'package:dating/profiles.dart';
import 'package:flutter/material.dart';
import 'package:dating/welcome_screen.dart';
import 'package:dating/login.dart';
import 'package:dating/signup.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dating App',
      
      // Initial screen (default route)
      initialRoute: '/',
      
      // Define named routes
      routes: {
        '/': (context) => const WelcomeScreen(),   // Default screen
        '/login': (context) => const Login(),      // Login screen
        '/signup': (context) => const Signup(),
        '/profiles': (context) => const Profiles(), // Profiles screen
      },
    );
  }
}
