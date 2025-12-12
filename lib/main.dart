// main.dart - Simplified version

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Pages/dashboard.dart'; // Assuming 'Pages/dashboard.dart' exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No Firebase, just local initialization
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => LocalAuthService())],
      child: MaterialApp(
        title: 'School Feeding Program',
        theme: ThemeData(
          primaryColor: const Color(0xFF1A4D7A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A4D7A),
            primary: const Color(0xFF1A4D7A),
            secondary: const Color(0xFF39D2C0),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 2,
            foregroundColor: Color(0xFF1A4D7A),
          ),
          fontFamily: 'Roboto',
        ),
        // FIX: The 'home' property is used for the initial route ('/').
        // This replaces 'initialRoute: /' and removes the need for a '/' entry in 'routes'.
        home: const Dashboard(),
        routes: {
          // Keep the named route for navigation later, if needed.
          '/dashboard': (context) => const Dashboard()
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class LocalAuthService extends ChangeNotifier {}
