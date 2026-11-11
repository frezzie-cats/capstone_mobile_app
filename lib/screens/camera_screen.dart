
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:capstone_mobile_app/services/tflite_service.dart';
import 'package:capstone_mobile_app/screens/result_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Camera and AI service
  CameraController? _controller;
  final TfliteService _tfliteService = TfliteService();

  // Initialization futures
  late Future<void> _cameraInitializationFuture;
  late Future<void> _modelsFuture;
  late Future<void> _initializationFuture;

  // UI states
  bool _isReady = false;
  bool _isProcessing = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();

    _initializeCameraAndModels();
  }

  // --------------------------------------------------
  // INITIALIZE CAMERA AND AI MODELS
  // --------------------------------------------------

  void _initializeCameraAndModels() {
    if (widget.cameras.isEmpty) {
      _initializationError = 'No camera was detected on this device.';
      _initializationFuture = Future<void>.value();
      return;
    }

    try {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      // Start camera initialization.
      _cameraInitializationFuture = _controller!.initialize();

      // Start model loading at the same time.
      _modelsFuture = _tfliteService.loadModels();

      // Wait for both operations.
      _initializationFuture = _initializeApp();
    } catch (e) {
      _initializationError = e.toString();
      _initializationFuture = Future<void>.value();
    }
  }

  Future<void> _initializeApp() async {
    try {
      await Future.wait<void>([
        _cameraInitializationFuture,
        _modelsFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _isReady = true;
        _initializationError = null;
      });

      debugPrint('Camera and AI models initialized successfully.');
    } catch (e, stackTrace) {
      debugPrint('App initialization failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isReady = false;
        _initializationError = e.toString();
      });
    }
  }

  // --------------------------------------------------
  // CAPTURE AND PROCESS IMAGE
  // --------------------------------------------------

  Future<void> _captureAndProcess() async {
    if (_isProcessing || !_isReady) return;

    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      _showError('Camera is not ready.');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Ensure initialization has completed.
      await _initializationFuture;

      if (!mounted) return;

      // Capture image.
      final XFile capturedImage = await controller.takePicture();

      final File imageFile = File(capturedImage.path);

      // Run the two-stage classification.
      final result = await _tfliteService.processImage(imageFile);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      // Navigate to the result screen.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            result: result,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Image processing failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showError('Error processing image: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // --------------------------------------------------
  // CAMERA PREVIEW
  // --------------------------------------------------

  Widget _buildCameraPreview() {
    final controller = _controller;

    if (controller == null) {
      return const Center(
        child: Text(
          'Camera unavailable',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _cameraInitializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to initialize camera:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done &&
            controller.value.isInitialized) {
          return SizedBox.expand(
            child: CameraPreview(controller),
          );
        }

        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF32D6C3),
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // STATUS INDICATOR
  // --------------------------------------------------

  Widget _buildStatusIndicator() {
    final bool hasError = _initializationError != null;

    final Color statusColor = hasError
        ? Colors.redAccent
        : _isReady
            ? const Color(0xFF32D6C3)
            : Colors.orangeAccent;

    final String statusText = hasError
        ? 'Initialization Failed'
        : _isReady
            ? 'AI Models Ready'
            : 'Preparing AI Models';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasError
                ? Icons.error_outline
                : _isReady
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top,
            color: statusColor,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // CAMERA FRAME
  // --------------------------------------------------

  Widget _buildCameraFrame() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF32D6C3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          _buildCorner(Alignment.topLeft),
          _buildCorner(Alignment.topRight),
          _buildCorner(Alignment.bottomLeft),
          _buildCorner(Alignment.bottomRight),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? const BorderSide(
                    color: Color(0xFF32D6C3),
                    width: 4,
                  )
                : BorderSide.none,
            bottom: alignment.y > 0
                ? const BorderSide(
                    color: Color(0xFF32D6C3),
                    width: 4,
                  )
                : BorderSide.none,
            left: alignment.x < 0
                ? const BorderSide(
                    color: Color(0xFF32D6C3),
                    width: 4,
                  )
                : BorderSide.none,
            right: alignment.x > 0
                ? const BorderSide(
                    color: Color(0xFF32D6C3),
                    width: 4,
                  )
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // BUILD SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101A20),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 18,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARTHROPOD CARE',
                        style: TextStyle(
                          color: Color(0xFF32D6C3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Bite & Sting Classifier',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusIndicator(),
                ],
              ),
            ),

            // CAMERA AREA
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera preview
                    _buildCameraPreview(),

                    // Dark gradient overlay
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Camera frame and instructions
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCameraFrame(),
                          const SizedBox(height: 22),
                          const Text(
                            'Position the affected area inside the frame',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Processing overlay
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withValues(alpha: 0.8),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF32D6C3),
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Analyzing Image',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please wait while the AI processes your image.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // BOTTOM CONTROLS
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  const Text(
                    'For best results, use good lighting and keep the affected area in focus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),

                  if (_initializationError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Initialization failed: $_initializationError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isProcessing || !_isReady)
                          ? null
                          : _captureAndProcess,
                      icon: Icon(
                        _isProcessing
                            ? Icons.hourglass_top
                            : Icons.camera_alt,
                      ),
                      label: Text(
                        _isProcessing
                            ? 'Analyzing...'
                            : _isReady
                                ? 'Capture & Analyze'
                                : 'Preparing AI Models...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF32D6C3),
                        foregroundColor: const Color(0xFF101A20),
                        disabledBackgroundColor: Colors.grey.shade700,
                        disabledForegroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _tfliteService.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
