
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  // Initialization futures
  late Future<void> _cameraInitializationFuture;
  late Future<void> _modelsFuture;

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
      return;
    }

    try {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _cameraInitializationFuture = _controller!.initialize();
      _modelsFuture = _tfliteService.loadModels();

      _initializeApp();
    } catch (e) {
      _initializationError = e.toString();
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
  // CAPTURE IMAGE USING CAMERA
  // --------------------------------------------------

  Future<void> _captureAndProcess() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      _showError('Camera is not ready.');
      return;
    }

    await _handleImageSelection(() async {
      final XFile capturedImage = await controller.takePicture();
      return File(capturedImage.path);
    });
  }

  // --------------------------------------------------
  // SELECT IMAGE FROM GALLERY
  // --------------------------------------------------

  Future<void> _pickAndProcess() async {
    await _handleImageSelection(() async {
      final XFile? selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (selectedImage == null) {
        return null;
      }

      return File(selectedImage.path);
    });
  }

  // --------------------------------------------------
  // SHARED IMAGE PROCESSING
  // --------------------------------------------------

  
  Future<void> _handleImageSelection(
    Future<File?> Function() selectImage,
  ) async {
    if (_isProcessing || !_isReady) return;

    try {
      // Step 1: Capture or select an image.
      // Do not show the analyzing overlay yet.
      final File? imageFile = await selectImage();

      // Stop if the user cancels image selection.
      if (imageFile == null || !mounted) return;

      // Step 2: Show the analyzing overlay only after
      // an image has been successfully selected.
      setState(() {
        _isProcessing = true;
      });

      // Step 3: Run the two-stage classification.
      final result = await _tfliteService.processImage(imageFile);

      if (!mounted) return;

      // Step 4: Hide the processing overlay.
      setState(() {
        _isProcessing = false;
      });

      // Step 5: Navigate to Results Screen with the image.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            result: result,
            imageFile: imageFile,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Image processing failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showError('Error processing image: $e');
    } finally {
      if (mounted && _isProcessing) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  // --------------------------------------------------
  // SHOW ERROR MESSAGE
  // --------------------------------------------------

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
                    _buildCameraPreview(),

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

                  // CAPTURE BUTTON
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

                  const SizedBox(height: 12),

                  // GALLERY UPLOAD BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: (_isProcessing || !_isReady)
                          ? null
                          : _pickAndProcess,
                      icon: const Icon(
                        Icons.photo_library_outlined,
                      ),
                      label: const Text(
                        'Upload from Gallery',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF32D6C3),
                        disabledForegroundColor: Colors.white38,
                        side: const BorderSide(
                          color: Color(0xFF32D6C3),
                          width: 1.5,
                        ),
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
