
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../database/db_helper.dart';

class TriageResult {
  final bool isLesionDetected;
  final String speciesKey;
  final String commonName;
  final double confidence;
  final String firstAidSteps;
  final String warningSigns;

  TriageResult({
    required this.isLesionDetected,
    required this.speciesKey,
    required this.commonName,
    required this.confidence,
    required this.firstAidSteps,
    required this.warningSigns,
  });
}

class TfliteService {
  Interpreter? _stage1Interpreter;
  Interpreter? _stage2Interpreter;

  Future<void>? _loadingFuture;
  bool _isDisposed = false;

  static const List<String> stage1Labels = [
    'no_bites',
    'bite_present',
  ];

  static const List<String> stage2Labels = [
    'bee_wasp',
    'brown_recluse_necrotic',
    'fire_ant',
    'tick_erythema_migrans',
  ];

  // --------------------------------------------------
  // LOAD MODELS
  // --------------------------------------------------

  Future<void> loadModels() {
    if (_isDisposed) {
      return Future.error(
        StateError('TfliteService has already been disposed.'),
      );
    }

    // Return immediately if both models are already loaded.
    if (_stage1Interpreter != null &&
        _stage2Interpreter != null) {
      return Future<void>.value();
    }

    // Share an existing loading operation.
    if (_loadingFuture != null) {
      return _loadingFuture!;
    }

    _loadingFuture = _loadModelsInternal();

    return _loadingFuture!;
  }

  Future<void> _loadModelsInternal() async {
    Interpreter? stage1;
    Interpreter? stage2;

    try {
      debugPrint('Loading Stage 1 model...');

      stage1 = await Interpreter.fromAsset(
        'assets/models/stage1_mobilenetv2_binary.tflite',
      );

      debugPrint('Stage 1 model loaded successfully.');

      debugPrint('Loading Stage 2 model...');

      stage2 = await Interpreter.fromAsset(
        'assets/models/stage2_efficientnetb0_4class.tflite',
      );

      debugPrint('Stage 2 model loaded successfully.');

      if (_isDisposed) {
        throw StateError(
          'TfliteService was disposed during model loading.',
        );
      }

      // Assign only after both models have loaded.
      _stage1Interpreter = stage1;
      _stage2Interpreter = stage2;

      debugPrint('Both TensorFlow Lite models are ready.');
    } catch (e, stackTrace) {
      debugPrint('Model loading failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      // Clean up partially loaded interpreters.
      stage1?.close();
      stage2?.close();

      _stage1Interpreter = null;
      _stage2Interpreter = null;

      rethrow;
    } finally {
      _loadingFuture = null;
    }
  }

  // --------------------------------------------------
  // PREPROCESS IMAGE
  // --------------------------------------------------

  Future<Float32List> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw Exception('Failed to decode image.');
    }

    final resizedImage = img.copyResize(
      decodedImage,
      width: 224,
      height: 224,
    );

    final Float32List inputBuffer = Float32List(
      1 * 224 * 224 * 3,
    );

    int pixelIndex = 0;

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);

        inputBuffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
        inputBuffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
        inputBuffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }

    return inputBuffer;
  }

  // --------------------------------------------------
  // PROCESS IMAGE
  // --------------------------------------------------

  Future<TriageResult> processImage(File imageFile) async {
    if (_isDisposed) {
      throw StateError(
        'Cannot process images after TfliteService is disposed.',
      );
    }

    // Ensure both models are ready before inference.
    await loadModels();

    if (_stage1Interpreter == null ||
        _stage2Interpreter == null) {
      throw StateError(
        'TensorFlow Lite models are not initialized.',
      );
    }

    final inputBuffer = await _preprocessImage(imageFile);

    final inputTensor = inputBuffer.reshape(
      [1, 224, 224, 3],
    );

    // --------------------------------------------------
    // STAGE 1: BINARY CLASSIFICATION
    // --------------------------------------------------

    var stage1Output = List.generate(
      1,
      (_) => List<double>.filled(2, 0.0),
    );

    _stage1Interpreter!.run(
      inputTensor,
      stage1Output,
    );

    final List<double> s1Probabilities = List<double>.from(
      stage1Output[0],
    );

    int s1PredictedIndex =
        s1Probabilities[0] > s1Probabilities[1] ? 0 : 1;

    String s1Class = stage1Labels[s1PredictedIndex];

    // If no bite or lesion is detected.
    if (s1Class == 'no_bites') {
      return TriageResult(
        isLesionDetected: false,
        speciesKey: 'no_bites',
        commonName: 'No Bite / Unlesioned Skin',
        confidence: s1Probabilities[s1PredictedIndex] * 100,
        firstAidSteps:
            'No active cutaneous lesion detected. Maintain clean skin hygiene.',
        warningSigns:
            'If you develop unexpected skin redness, swelling, or localized pain, re-evaluate.',
      );
    }

    // --------------------------------------------------
    // STAGE 2: FOUR-CLASS CLASSIFICATION
    // --------------------------------------------------

    var stage2Output = List.generate(
      1,
      (_) => List<double>.filled(4, 0.0),
    );

    _stage2Interpreter!.run(
      inputTensor,
      stage2Output,
    );

    final List<double> s2Probabilities = List<double>.from(
      stage2Output[0],
    );

    int s2TopIndex = 0;
    double maxProb = s2Probabilities[0];

    for (int i = 1; i < s2Probabilities.length; i++) {
      if (s2Probabilities[i] > maxProb) {
        maxProb = s2Probabilities[i];
        s2TopIndex = i;
      }
    }

    String predictedSpeciesKey = stage2Labels[s2TopIndex];

    double confidenceScore = maxProb * 100;

    // --------------------------------------------------
    // STAGE 3: SQLITE DATABASE LOOKUP
    // --------------------------------------------------

    final guidelineData =
        await DatabaseHelper.instance.getGuideline(
      predictedSpeciesKey,
    );

    final String commonName =
        guidelineData?['common_name'] as String? ??
            predictedSpeciesKey;

    final String firstAidSteps =
        guidelineData?['first_aid_steps'] as String? ??
            'First-aid details unavailable.';

    final String warningSigns =
        guidelineData?['warning_signs'] as String? ??
            'Warning sign information unavailable.';

    // --------------------------------------------------
    // RETURN RESULT
    // --------------------------------------------------

    return TriageResult(
      isLesionDetected: true,
      speciesKey: predictedSpeciesKey,
      commonName: commonName,
      confidence: confidenceScore,
      firstAidSteps: firstAidSteps,
      warningSigns: warningSigns,
    );
  }

  // --------------------------------------------------
  // DISPOSE INTERPRETERS
  // --------------------------------------------------

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;

    _stage1Interpreter?.close();
    _stage2Interpreter?.close();

    _stage1Interpreter = null;
    _stage2Interpreter = null;

    debugPrint('TensorFlow Lite interpreters disposed.');
  }
}
