
import 'dart:io';

import 'package:flutter/material.dart';
import '../services/tflite_service.dart';

class ResultScreen extends StatelessWidget {
  final TriageResult result;
  final File imageFile;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imageFile,
  });

  static const Color primaryTeal = Color(0xFF087F78);
  static const Color backgroundColor = Color(0xFFF5F8F8);

  static const List<String> stage1DisplayLabels = [
    'No Bites',
    'Bite Present',
  ];

  static const List<String> stage2DisplayLabels = [
    'Bee / Wasp',
    'Brown Recluse',
    'Fire Ant',
    'Tick',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isLesion = result.isLesionDetected;

    final Color statusColor = isLesion
        ? const Color(0xFFCA5A36)
        : const Color(0xFF23865B);

    final double confidence =
        (result.confidence / 100).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Evaluation Result',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Analyzed photo heading
              const Text(
                'Analyzed Photo',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203B39),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'This is the image used for classification.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 14),

              // Analyzed photo preview
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE3EBEA),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    imageFile,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 180,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Unable to display image',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Classification heading
              const Text(
                'Classification Summary',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203B39),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Here is the result of your image evaluation.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 20),

              // Main classification card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLesion
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 36,
                        color: statusColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLesion
                            ? 'POTENTIAL LESION DETECTED'
                            : 'NO LESION DETECTED',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),

                    const SizedBox(height: 13),

                    Text(
                      result.commonName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF203B39),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Main prediction confidence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Model confidence',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${result.confidence.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: primaryTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: confidence,
                        minHeight: 9,
                        backgroundColor: const Color(0xFFE7EEEE),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          primaryTeal,
                        ),
                      ),
                    ),

                    const SizedBox(height: 9),

                    const Text(
                      'Confidence reflects the model output, '
                      'not the certainty of a medical diagnosis.',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Model confidence breakdown heading
              const Text(
                'Model Confidence Breakdown',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203B39),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'View the confidence scores for each class '
                'generated by the classification models.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 16),

              // Stage 1 confidence
              _buildConfidenceCard(
                title: 'Stage 1 - Bite Detection',
                subtitle: 'MobileNetV2 Binary Classification',
                labels: stage1DisplayLabels,
                probabilities: result.stage1Probabilities,
              ),

              const SizedBox(height: 15),

              // Stage 2 confidence
              _buildConfidenceCard(
                title: 'Stage 2 - Arthropod Classification',
                subtitle: 'EfficientNetB0 Four-Class Classification',
                labels: stage2DisplayLabels,
                probabilities: result.stage2Probabilities,
              ),

              const SizedBox(height: 25),

              // First aid section
              _buildSectionHeading(
                icon: Icons.medical_services_outlined,
                title: 'Immediate First-Aid Guidelines',
                color: primaryTeal,
              ),

              const SizedBox(height: 11),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  result.firstAidSteps,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFF405452),
                  ),
                ),
              ),

              const SizedBox(height: 23),

              // Warning signs section
              _buildSectionHeading(
                icon: Icons.warning_amber_rounded,
                title: 'Red Flag Warning Signs',
                color: const Color(0xFFC33F3F),
              ),

              const SizedBox(height: 11),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF3D0CC),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFC33F3F),
                      size: 23,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        result.warningSigns,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: Color(0xFF8E3434),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 23),

              // Medical disclaimer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: primaryTeal,
                      size: 21,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This application provides AI-assisted '
                        'classification and first-aid information. '
                        'It does not replace professional medical '
                        'assessment. Seek medical attention when '
                        'needed, especially if symptoms are severe '
                        'or worsening.',
                        style: TextStyle(
                          color: Color(0xFF42615E),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Evaluate another image
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text(
                    'Evaluate Another Image',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // CONFIDENCE BREAKDOWN CARD
  // --------------------------------------------------

  Widget _buildConfidenceCard({
    required String title,
    required String subtitle,
    required List<String> labels,
    required List<double>? probabilities,
  }) {
    final bool wasExecuted = probabilities != null;

    final int highestIndex = wasExecuted
        ? _getHighestIndex(probabilities)
        : -1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE3EBEA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF203B39),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
            ),
          ),

          const SizedBox(height: 20),

          if (!wasExecuted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.black45,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'N/A - Classification not performed. '
                      'Stage 1 detected no bites.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(labels.length, (index) {
              final double percentage =
                  probabilities[index] * 100;

              final bool isHighest = index == highestIndex;

              final double progress =
                  probabilities[index].clamp(0.0, 1.0);

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == labels.length - 1 ? 0 : 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isHighest
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isHighest
                                  ? primaryTeal
                                  : const Color(0xFF405452),
                            ),
                          ),
                        ),

                        if (isHighest) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: primaryTeal,
                            size: 15,
                          ),
                          const SizedBox(width: 3),
                        ],

                        Text(
                          '${percentage.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isHighest
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isHighest
                                ? primaryTeal
                                : const Color(0xFF405452),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        backgroundColor: const Color(0xFFE7EEEE),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                          isHighest
                              ? primaryTeal
                              : const Color(0xFF91BDB8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  int _getHighestIndex(List<double> probabilities) {
    int highestIndex = 0;

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[highestIndex]) {
        highestIndex = i;
      }
    }

    return highestIndex;
  }

  // --------------------------------------------------
  // SECTION HEADING
  // --------------------------------------------------

  Widget _buildSectionHeading({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF203B39),
            ),
          ),
        ),
      ],
    );
  }
}
