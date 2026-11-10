import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(ArthropodTriageApp(cameras: cameras));
}

class ArthropodTriageApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const ArthropodTriageApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arthropod Bite & Sting Triage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}