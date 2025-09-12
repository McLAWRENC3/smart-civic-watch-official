// Main application entry point and routing configuration
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_incident_screen.dart';
import 'screens/emergency_contacts_screen.dart';

// Main application widget that sets up routing and theme
class SmartCivicWatchApp extends StatelessWidget {
  const SmartCivicWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Civic Watch',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Set initial route to login screen
      initialRoute: '/',
      // Define all application routes
      routes: {
        // Login screen route (initial route)
        '/': (context) => const LoginScreen(),
        // User registration screen
        '/register': (context) => const RegisterScreen(),
        // Main dashboard/home screen
        '/home': (context) => const HomeScreen(),
        // Incident reporting screen
        '/report': (context) => const ReportIncidentScreen(),
        // Emergency contacts management screen
        '/emergency': (context) => const EmergencyContactsScreen(),
      },
    );
  }
}