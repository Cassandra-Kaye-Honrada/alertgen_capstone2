import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class SkinAnalysisCache {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  String generateImageHash(File imageFile) {
    try {
      final bytes = imageFile.readAsBytesSync();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Error generating image hash: $e');
      return '';
    }
  }

  String generateConditionCacheKey(String conditionName) {
    String normalized = conditionName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(
          RegExp(
            r'\b(allergic reaction|allergy|reaction|induced|related|triggered)\b',
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(food|environmental|temperature|heat|cold|sun)\s+(allergy|related|triggered|induced)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    print('Cache key generation: "$conditionName" -> "$normalized"');
    return normalized;
  }

  Future<Map<String, dynamic>?> checkExactImageMatch(String imageHash) async {
    try {
      final querySnapshot =
          await firestore
              .collection('skin_cache')
              .where('imageHash', isEqualTo: imageHash)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();

        firestore
            .collection('skin_cache')
            .doc(querySnapshot.docs.first.id)
            .update({
              'lastAccessed': FieldValue.serverTimestamp(),
              'accessCount': FieldValue.increment(1),
            })
            .catchError((e) => print('Error updating cache stats: $e'));

        return {
          ...data,
          'matchType': 'exact_image',
          'matchLevel': 1,
          'fromCache': true,
        };
      }

      return null;
    } catch (e) {
      print('Error checking exact image match: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkConditionNameMatch(
    String conditionName,
  ) async {
    try {
      final cacheKey = generateConditionCacheKey(conditionName);
      print('Looking up cache with key: $cacheKey');

      final doc = await firestore.collection('skin_cache').doc(cacheKey).get();

      if (doc.exists) {
        final data = doc.data()!;
        print('Cache HIT for condition: $conditionName (key: $cacheKey)');

        firestore
            .collection('skin_cache')
            .doc(cacheKey)
            .update({
              'lastAccessed': FieldValue.serverTimestamp(),
              'accessCount': FieldValue.increment(1),
            })
            .catchError((e) => print('Error updating cache stats: $e'));

        return {
          ...data,
          'matchType': 'condition_name',
          'matchLevel': 2,
          'fromCache': true,
        };
      }

      print('Cache MISS for condition: $conditionName (key: $cacheKey)');
      return null;
    } catch (e) {
      print('Error checking condition name match: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkSimilarSkinCondition(
    File imageFile,
    String apiKey,
  ) async {
    try {
      final querySnapshot =
          await firestore
              .collection('skin_cache')
              .where('thumbnailUrl', isNull: false)
              .orderBy('timestamp', descending: true)
              .limit(15)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final currentImageBytes = await imageFile.readAsBytes();
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
      );

      Map<String, dynamic>? bestMatch;
      double bestConfidence = 0.0;

      for (var i = 0; i < querySnapshot.docs.length; i++) {
        final doc = querySnapshot.docs[i];
        final cachedData = doc.data();
        final cachedImageUrl = cachedData['thumbnailUrl'] as String?;
        final cachedConditionName =
            cachedData['conditionName'] as String? ?? 'Unknown';
        final cachedDescription = cachedData['description'] as String? ?? '';
        final cachedSymptoms =
            (cachedData['symptoms'] as List?)?.join(', ') ?? '';

        if (cachedImageUrl == null) continue;

        try {
          final ref = storage.refFromURL(cachedImageUrl);
          final cachedImageBytes = await ref.getData();

          if (cachedImageBytes == null) continue;

          final comparisonPrompt = '''
You are an expert dermatologist comparing two skin condition images with STRICT DIAGNOSTIC CRITERIA.

CACHED CONDITION: $cachedConditionName
Description: $cachedDescription
Key Symptoms: $cachedSymptoms

CRITICAL DIAGNOSTIC FEATURES TO MATCH:

1. LESION MORPHOLOGY (50% weight) - MOST IMPORTANT:
   Primary lesion type:
   - Papules (small raised bumps) vs Vesicles (fluid-filled) vs Wheals (raised welts)
   - Plaques (large flat areas) vs Patches (color change only) vs Nodules (deep bumps)
   
   Heat Rash specific: Tiny uniform papules/vesicles (1-2mm), crystal-clear or red
   Atopic Dermatitis specific: Larger irregular patches (>5mm), dry and scaly
   Hives specific: Raised wheals with defined borders, vary in size

2. DISTRIBUTION PATTERN (25% weight):
   - Heat Rash: Clustered in sweaty areas (neck, chest, back, skin folds)
   - Atopic Dermatitis: Flexural areas (elbow creases, behind knees), face in children
   - Hives: Random distribution, can appear anywhere
   - Contact Dermatitis: Limited to area of contact

3. TEXTURE & SURFACE (15% weight):
   - Heat Rash: Smooth tiny bumps, may be moist
   - Atopic Dermatitis: Dry, scaly, rough, thickened (lichenification)
   - Hives: Smooth raised surface, no scaling

4. COLOR & INFLAMMATION (10% weight):
   - Heat Rash: Pink to red, uniform color
   - Atopic Dermatitis: Red to brown, may have excoriations
   - Hives: Pink to red, blanches with pressure

STRICT MATCHING RULES:
- If PRIMARY LESION TYPE differs → confidence must be ≤0.45
- If DISTRIBUTION doesn't match typical pattern → reduce confidence by 0.20
- IGNORE: Different angles, lighting, body parts (if pattern consistent)
- ACCEPT: Same condition on different body areas IF lesion morphology matches

EXAMPLES OF CORRECT SCORING:
✓ Heat rash on chest (close-up) vs Heat rash on back (distant) → 0.85+ (SAME tiny papules pattern)
✓ Heat rash (early) vs Heat rash (fully developed) → 0.75+ (SAME lesion type, different stage)
✗ Heat rash vs Atopic Dermatitis → ≤0.45 (DIFFERENT lesion morphology: tiny papules vs large patches)
✗ Heat rash vs Hives → ≤0.40 (DIFFERENT lesion type: papules vs wheals)

Return ONLY valid JSON:
{
  "isSameCondition": true/false,
  "confidence": 0.XX,
  "matchedCharacteristics": {
    "lesionMorphology": "DETAILED comparison of lesion types",
    "distributionPattern": "Pattern comparison with typical locations",
    "textureAndSurface": "Surface characteristic comparison",
    "colorInflammation": "Color and inflammation assessment"
  },
  "keyFindings": {
    "similarities": ["specific similarity 1", "specific similarity 2"],
    "criticalDifferences": ["specific difference 1", "specific difference 2"]
  },
  "reasoning": "Detailed diagnostic reasoning based on PRIMARY lesion morphology",
  "diagnosticCertainty": "High/Medium/Low based on image quality and characteristic visibility"
}

CONFIDENCE THRESHOLDS:
- 0.85-1.00: Definitely same - PRIMARY lesion morphology identical, pattern matches
- 0.70-0.84: Very likely same - Core features match, minor variations acceptable
- 0.50-0.69: Possibly same - Some overlap but significant uncertainties
- 0.00-0.49: Different conditions - PRIMARY lesion morphology doesn't match

BE DIAGNOSTICALLY ACCURATE: 
- Heat Rash = tiny uniform papules/vesicles
- Atopic Dermatitis = large irregular dry patches
- If lesion size/morphology differs significantly → LOW confidence
''';

          final response = await model.generateContent([
            Content.multi([
              TextPart(comparisonPrompt),
              TextPart("CACHED IMAGE (Previous Diagnosis):"),
              TextPart("Condition: $cachedConditionName"),
              DataPart('image/jpeg', cachedImageBytes),
              TextPart("CURRENT IMAGE (New Scan):"),
              TextPart(
                "Analyze this image and compare with the cached image above",
              ),
              DataPart('image/jpeg', currentImageBytes),
            ]),
          ]);

          final comparisonResult = parseDetailedComparisonResponse(
            response.text ?? '',
          );
          final confidence = (comparisonResult['confidence'] ?? 0.0).toDouble();
          final isSame = comparisonResult['isSameCondition'] ?? false;

          print(
            'Comparison with $cachedConditionName: confidence=$confidence, isSame=$isSame',
          );
          print('Reasoning: ${comparisonResult['reasoning']}');

          if (confidence > bestConfidence) {
            bestConfidence = confidence;
            bestMatch = {
              'cachedData': cachedData,
              'docId': doc.id,
              'comparisonResult': comparisonResult,
              'confidence': confidence,
            };
          }

          if (isSame && confidence >= 0.70) {
            print(
              'Visual match found: $cachedConditionName (confidence: $confidence)',
            );
            print('Match reasoning: ${comparisonResult['reasoning']}');

            firestore
                .collection('skin_cache')
                .doc(doc.id)
                .update({
                  'lastAccessed': FieldValue.serverTimestamp(),
                  'accessCount': FieldValue.increment(1),
                  'lastMatchConfidence': confidence,
                  'lastMatchDetails': comparisonResult,
                })
                .catchError((e) => print('Error updating cache: $e'));

            return {
              ...cachedData,
              'matchType': 'visual_similarity',
              'matchLevel': 3,
              'fromCache': true,
              'matchConfidence': confidence,
              'matchReasoning': comparisonResult['reasoning'],
              'matchedCharacteristics':
                  comparisonResult['matchedCharacteristics'],
              'keyFindings': comparisonResult['keyFindings'],
              'diagnosticFeatures': comparisonResult['diagnosticFeatures'],
            };
          }
        } catch (e) {
          print('Error comparing with cached image: $e');
          continue;
        }
      }

      print('No visual match found. Best confidence: $bestConfidence');
      return null;
    } catch (e) {
      print('Error checking similar skin condition: $e');
      return null;
    }
  }

  Map<String, dynamic> parseDetailedComparisonResponse(String response) {
    try {
      String cleanResponse = response;

      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
        if (cleanResponse.contains('```')) {
          cleanResponse = cleanResponse.split('```')[0];
        }
      }

      cleanResponse = cleanResponse.trim();

      final parsed = json.decode(cleanResponse);

      if (parsed['confidence'] != null) {
        parsed['confidence'] = (parsed['confidence'] as num).toDouble();
      }

      return parsed;
    } catch (e) {
      print('Error parsing detailed comparison response: $e');
      return {
        'isSameCondition': false,
        'confidence': 0.0,
        'reasoning': 'Failed to parse comparison result',
        'matchedCharacteristics': {},
        'keyFindings': {
          'similarities': [],
          'differences': ['Parse error occurred'],
        },
        'diagnosticFeatures': [],
      };
    }
  }

  Future<void> saveSkinAnalysisCache(
    Map<String, dynamic> skinData,
    File imageFile,
    String imageHash,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final conditionName = skinData['conditionName'] ?? 'Unknown';
      final conditionCacheKey = generateConditionCacheKey(conditionName);

      print(
        'Saving to cache with key: $conditionCacheKey (from: $conditionName)',
      );

      String? thumbnailUrl;
      try {
        final thumbnailFileName =
            'skin_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final thumbnailRef = storage
            .ref()
            .child('skin_thumbnails')
            .child('global')
            .child(thumbnailFileName);

        await thumbnailRef.putFile(imageFile);
        thumbnailUrl = await thumbnailRef.getDownloadURL();
      } catch (e) {
        print('Error uploading thumbnail: $e');
      }

      await firestore.collection('skin_cache').doc(conditionCacheKey).set({
        'conditionName': conditionName,
        'conditionCacheKey': conditionCacheKey,
        'isFoodAllergyRelated': skinData['isFoodAllergyRelated'] ?? false,
        'isTemperatureRelated': skinData['isTemperatureRelated'] ?? false,
        'isEnvironmentalTrigger': skinData['isEnvironmentalTrigger'] ?? false,
        'confidence': skinData['confidence'] ?? 0.5,
        'description': skinData['description'] ?? '',
        'severity': skinData['severity'] ?? 'unknown',
        'likelyFoodTriggers': skinData['likelyFoodTriggers'] ?? [],
        'environmentalTriggers': skinData['environmentalTriggers'] ?? [],
        'symptoms': skinData['symptoms'] ?? [],
        'immediateActions': skinData['immediateActions'] ?? [],
        'foodsToAvoid': skinData['foodsToAvoid'] ?? [],
        'environmentalPrecautions': skinData['environmentalPrecautions'] ?? [],
        'whenToSeekHelp': skinData['whenToSeekHelp'] ?? '',
        'additionalNotes': skinData['additionalNotes'] ?? '',
        'imageHash': imageHash,
        'thumbnailUrl': thumbnailUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
        'accessCount': 1,
        'createdBy': user.uid,
      }, SetOptions(merge: true));

      print('Successfully saved skin analysis to cache');
    } catch (e) {
      print('Error saving skin analysis cache: $e');
    }
  }
}
