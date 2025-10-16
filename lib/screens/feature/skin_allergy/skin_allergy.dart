import 'dart:io';
import 'package:allergen/screens/feature/ResultScreenTemplate.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SkinResultScreen extends ResultScreenTemplate {
  final Map<String, dynamic> skinData;

  const SkinResultScreen({Key? key, required this.skinData, File? image})
    : super(key: key, image: image, resultData: skinData);

  @override
  _SkinResultScreenState createState() => _SkinResultScreenState();
}

class _SkinResultScreenState
    extends ResultScreenTemplateState<SkinResultScreen> {
  @override
  String getTitle() => 'Result';

  @override
  String getMainTitle() =>
      widget.skinData['conditionName'] ?? 'Unknown Condition';

  @override
  Widget buildStatusBadge() {
    final isFoodAllergyRelated =
        widget.skinData['isFoodAllergyRelated'] ?? false;

    return isFoodAllergyRelated
        ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Food Allergy Related',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        )
        : Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Not Food Allergy Related',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        );
  }

  @override
  Widget buildConfidenceBadge() {
    final confidence = (widget.skinData['confidence'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics, color: Colors.blue[700], size: 16),
          const SizedBox(width: 4),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}% Confidence',
            style: TextStyle(color: Colors.blue[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  void onFirstAidTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FirstAidScreen()),
    );
  }

  @override
  Widget buildAllergenTab() {
    final likelyFoodTriggers = List<Map<String, dynamic>>.from(
      widget.skinData['likelyFoodTriggers'] ?? [],
    );
    final foodsToAvoid = List<String>.from(
      widget.skinData['foodsToAvoid'] ?? [],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (likelyFoodTriggers.isNotEmpty) ...[
            Text(
              'Likely Food Triggers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children:
                  likelyFoodTriggers.map((trigger) {
                    final allergen = trigger['allergen'] ?? 'Unknown';
                    final likelihood = trigger['likelihood'] ?? 'unknown';
                    Color likelihoodColor = getLikelihoodColor(likelihood);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: likelihoodColor.withOpacity(0.1),
                            border: Border.all(
                              color: likelihoodColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.primaryColor3,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 80,
                          child: Text(
                            allergen,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: likelihoodColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          if (foodsToAvoid.isNotEmpty) ...[
            Text(
              'Foods to Avoid',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  foodsToAvoid.map((food) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        food,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],

          if (likelyFoodTriggers.isEmpty && foodsToAvoid.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No Allergen Information',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No specific food allergen data available',
                    style: TextStyle(color: Colors.blue.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget buildDescriptionTab() {
    final description =
        widget.skinData['description'] ?? 'No description available';
    final symptoms = List<String>.from(widget.skinData['symptoms'] ?? []);
    final whenToSeekHelp = widget.skinData['whenToSeekHelp'] ?? '';
    final additionalNotes = widget.skinData['additionalNotes'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),

          // Symptoms
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Symptoms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  symptoms.map((symptom) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        symptom,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],

          // When to Seek Help
          if (whenToSeekHelp.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emergency, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'When to Seek Help',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    whenToSeekHelp,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.red[900],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Additional Notes
          if (additionalNotes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Additional Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    additionalNotes,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.amber[900],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color getLikelihoodColor(String likelihood) {
    switch (likelihood.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'low':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
