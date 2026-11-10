
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/tflite_service.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  final TfliteService _tfliteService = TfliteService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize();
    _tfliteService.loadModels();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tfliteService.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;

    try {
      setState(() => _isProcessing = true);

      await _initializeControllerFuture;

      final XFile imageXFile = await _controller.takePicture();
      final File imageFile = File(imageXFile.path);

      final TriageResult result =
          await _tfliteService.processImage(imageFile);

      if (!mounted) return;

      setState(() => _isProcessing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing image: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color teal = Color(0xFF087F78);

    return Scaffold(
      backgroundColor: const Color(0xFF101C1B),
      body: Stack(
        children: [
          // Live camera preview
          Positioned.fill(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return SizedBox.expand(
                    child: CameraPreview(_controller),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to initialize camera.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.tealAccent,
                  ),
                );
              },
            ),
          ),

          // Dark overlay for better text visibility
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.25, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Main interface
          SafeArea(
            child: Column(
              children: [
                // Top header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: teal,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ARTHROPOD CARE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Bite & Sting Classification',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: Colors.greenAccent,
                              size: 8,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'CAMERA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Camera framing guide
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.tealAccent,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'ALIGN AFFECTED AREA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Corner markers
                          ..._buildCornerMarkers(),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom instructions and capture button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 25),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Position the affected area',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Keep the bite or sting inside the frame. '
                        'Make sure the area is clearly visible.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : _captureAndProcess,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text(
                            'Capture & Analyze',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: teal,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white54,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'AI-assisted classification and guidance',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(30),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18302E),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.tealAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.tealAccent,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 22),
                        Text(
                          'Analyzing Image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Executing two-stage AI classification...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerMarkers() {
    const double size = 22;
    const double thickness = 4;
    const Color color = Colors.tealAccent;

    Widget corner({
      required Alignment alignment,
      required BorderRadius borderRadius,
    }) {
      return Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: alignment.y < 0
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              bottom: alignment.y > 0
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              left: alignment.x < 0
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              right: alignment.x > 0
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
            ),
            borderRadius: borderRadius,
          ),
        ),
      );
    }

    return [
      corner(
        alignment: Alignment.topLeft,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
        ),
      ),
      corner(
        alignment: Alignment.topRight,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
        ),
      ),
      corner(
        alignment: Alignment.bottomLeft,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
        ),
      ),
      corner(
        alignment: Alignment.bottomRight,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(18),
        ),
      ),
    ];
  }
}
