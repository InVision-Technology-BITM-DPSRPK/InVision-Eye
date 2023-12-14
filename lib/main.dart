import 'package:flutter/material.dart';
import 'camscreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CamScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
