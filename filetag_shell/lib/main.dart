import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FileTagApp());
}

class FileTagApp extends StatelessWidget {
  const FileTagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileTag',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C5CE7),
      ),
      home: const HomeScreen(),
    );
  }
}
