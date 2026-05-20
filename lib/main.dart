import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const DocuAIApp());
}

class DocuAIApp extends StatelessWidget {
  const DocuAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocuAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A2F5A)),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: const HomeScreen(),
    );
  }
}