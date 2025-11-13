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
  
  Future<Map<String, dynamic>?> checkExactImageMatch(String imageHash) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final querySnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('skin_cache')
          .where('imageHash', isEqualTo: imageHash)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        
        firestore
            .collection('users')
            .doc(user.uid)
            .collection('skin_cache')
            .doc(querySnapshot.docs.first.id)
            .update({
              'lastAccessed': FieldValue.serverTimestamp(),
              'accessCount': FieldValue.increment(1),
            })
            .catchError((e) => print('Error updating cache stats: $e'));
        
        return data;
      }
      
      return null;
    } catch (e) {
      print('Error checking exact image match: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> checkSimilarSkinCondition(
    File imageFile,
    String apiKey,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final querySnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('skin_cache')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      
      final currentImageBytes = await imageFile.readAsBytes();
      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
      
      for (var doc in querySnapshot.docs) {
        final cachedData = doc.data();
        final cachedImageUrl = cachedData['thumbnailUrl'] as String?;
        
        if (cachedImageUrl == null) continue;
        
        try {
          final ref = storage.refFromURL(cachedImageUrl);
          final cachedImageBytes = await ref.getData();
          
          if (cachedImageBytes == null) continue;
          
          final comparisonPrompt = '''
Compare these two skin condition images and determine if they show the SAME skin condition.

CRITICAL COMPARISON RULES:
1. Focus on the TYPE and CHARACTERISTICS of the skin condition, not the exact location
2. Consider: rash pattern, color, texture, severity, distribution
3. Images can be from different body parts or angles but show the same condition
4. Return a confidence score (0.0 to 1.0) indicating similarity of the CONDITION

Return ONLY JSON:
{
  "isSameCondition": true/false,
  "confidence": 0.XX,
  "reasoning": "Brief explanation of why they match or don't match"
}

THRESHOLDS:
- confidence >= 0.80: Definitely same condition
- confidence >= 0.65: Likely same condition
- confidence < 0.65: Different conditions
''';
          
          final response = await model.generateContent([
            Content.multi([
              TextPart(comparisonPrompt),
              TextPart("Current Image:"),
              DataPart('image/jpeg', currentImageBytes),
              TextPart("Previous Image:"),
              DataPart('image/jpeg', cachedImageBytes),
            ]),
          ]);
          
          final comparisonResult = parseComparisonResponse(response.text ?? '');
          
          if (comparisonResult['isSameCondition'] == true && 
              comparisonResult['confidence'] >= 0.65) {
            
            firestore
                .collection('users')
                .doc(user.uid)
                .collection('skin_cache')
                .doc(doc.id)
                .update({
                  'lastAccessed': FieldValue.serverTimestamp(),
                  'accessCount': FieldValue.increment(1),
                  'lastMatchConfidence': comparisonResult['confidence'],
                })
                .catchError((e) => print('Error updating cache: $e'));
            
            return {
              ...cachedData,
              'fromCache': true,
              'matchConfidence': comparisonResult['confidence'],
              'matchReasoning': comparisonResult['reasoning'],
            };
          }
        } catch (e) {
          print('Error comparing with cached image: $e');
          continue;
        }
      }
      
      return null;
    } catch (e) {
      print('Error checking similar skin condition: $e');
      return null;
    }
  }
  
  Map<String, dynamic> parseComparisonResponse(String response) {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }
      
      return json.decode(cleanResponse.trim());
    } catch (e) {
      print('Error parsing comparison response: $e');
      return {
        'isSameCondition': false,
        'confidence': 0.0,
        'reasoning': 'Failed to parse comparison result',
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
      
      String? thumbnailUrl;
      try {
        final thumbnailFileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final thumbnailRef = storage
            .ref()
            .child('skin_thumbnails')
            .child(user.uid)
            .child(thumbnailFileName);
        
        await thumbnailRef.putFile(imageFile);
        thumbnailUrl = await thumbnailRef.getDownloadURL();
      } catch (e) {
        print('Error uploading thumbnail: $e');
      }
      
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('skin_cache')
          .add({
            'conditionName': skinData['conditionName'] ?? 'Unknown',
            'isFoodAllergyRelated': skinData['isFoodAllergyRelated'] ?? false,
            'confidence': skinData['confidence'] ?? 0.5,
            'description': skinData['description'] ?? '',
            'severity': skinData['severity'] ?? 'unknown',
            'likelyFoodTriggers': skinData['likelyFoodTriggers'] ?? [],
            'symptoms': skinData['symptoms'] ?? [],
            'immediateActions': skinData['immediateActions'] ?? [],
            'foodsToAvoid': skinData['foodsToAvoid'] ?? [],
            'whenToSeekHelp': skinData['whenToSeekHelp'] ?? '',
            'additionalNotes': skinData['additionalNotes'] ?? '',
            'imageHash': imageHash,
            'thumbnailUrl': thumbnailUrl ?? '',
            'timestamp': FieldValue.serverTimestamp(),
            'lastAccessed': FieldValue.serverTimestamp(),
            'accessCount': 1,
          });
    } catch (e) {
      print('Error saving skin analysis cache: $e');
    }
  }
  //
  
}