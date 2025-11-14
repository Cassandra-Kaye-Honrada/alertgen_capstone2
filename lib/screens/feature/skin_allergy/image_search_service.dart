import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ImageCacheService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'condition_image_cache';

  /// Fetch images for a condition - first checks Firebase cache, then Google API
  static Future<List<String>> fetchConditionImages(
    String conditionName, {
    int maxResults = 3,
  }) async {
    try {
      // Normalize condition name for consistent caching
      final normalizedName = conditionName.trim().toLowerCase();

      // Step 1: Check Firebase cache first
      final cachedImages = await _getFromCache(normalizedName);
      if (cachedImages != null && cachedImages.isNotEmpty) {
        print('✓ Found cached images for: $conditionName');
        return cachedImages;
      }

      // Step 2: If not in cache, fetch from Google API
      print('× No cache found. Fetching from Google API: $conditionName');
      final fetchedImages = await _fetchFromGoogleAPI(
        conditionName,
        maxResults: maxResults,
      );

      // Step 3: Save to Firebase cache for future use
      if (fetchedImages.isNotEmpty) {
        await _saveToCache(normalizedName, fetchedImages);
        print('✓ Saved ${fetchedImages.length} images to cache');
      }

      return fetchedImages;
    } catch (e) {
      print('Error in fetchConditionImages: $e');
      return [];
    }
  }

  /// Get images from Firebase cache
  static Future<List<String>?> _getFromCache(String normalizedName) async {
    try {
      final docSnapshot =
          await _firestore
              .collection(_collectionName)
              .doc(normalizedName)
              .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['imageUrls'] != null) {
          final List<dynamic> urls = data['imageUrls'];
          return urls.map((url) => url.toString()).toList();
        }
      }
      return null;
    } catch (e) {
      print('Error getting from cache: $e');
      return null;
    }
  }

  /// Save images to Firebase cache
  static Future<void> _saveToCache(
    String normalizedName,
    List<String> imageUrls,
  ) async {
    try {
      await _firestore.collection(_collectionName).doc(normalizedName).set({
        'conditionName': normalizedName,
        'imageUrls': imageUrls,
        'cachedAt': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  /// Update last accessed timestamp
  static Future<void> _updateLastAccessed(String normalizedName) async {
    try {
      await _firestore.collection(_collectionName).doc(normalizedName).update({
        'lastAccessed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last accessed: $e');
    }
  }

  /// Fetch images from Google Custom Search API
  static Future<List<String>> _fetchFromGoogleAPI(
    String conditionName, {
    int maxResults = 3,
  }) async {
    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
      final searchEngineId = dotenv.env['GOOGLE_CSE_ID'] ?? '936b257bec9c04ee0';

      if (apiKey.isEmpty) {
        print('Google API Key is missing. Please add GOOGLE_API_KEY to .env');
        return [];
      }

      final query = Uri.encodeComponent(
        '$conditionName medical skin condition dermatology',
      );

      final url = Uri.parse(
        'https://www.googleapis.com/customsearch/v1?'
        'key=$apiKey&'
        'cx=$searchEngineId&'
        'q=$query&'
        'searchType=image&'
        'num=$maxResults&'
        'safe=active&'
        'imgSize=medium&'
        'imgType=photo',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<String> imageUrls = [];

        if (data['items'] != null) {
          for (var item in data['items']) {
            if (item['link'] != null) {
              imageUrls.add(item['link']);
            }
          }
        }

        return imageUrls;
      } else {
        print('Google API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching from Google API: $e');
      return [];
    }
  }

  /// Get placeholder image URL
  static String getPlaceholderImage(String conditionName) {
    return 'https://via.placeholder.com/400x200/E3F2FD/1976D2?text=${Uri.encodeComponent(conditionName)}';
  }

  /// Clear all cached images (for maintenance)
  static Future<void> clearAllCache() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('✓ Cache cleared successfully');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Clear cache for specific condition
  static Future<void> clearConditionCache(String conditionName) async {
    try {
      final normalizedName = conditionName.trim().toLowerCase();
      await _firestore.collection(_collectionName).doc(normalizedName).delete();
      print('✓ Cache cleared for: $conditionName');
    } catch (e) {
      print('Error clearing condition cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return {
        'totalCachedConditions': snapshot.docs.length,
        'totalImages': snapshot.docs.fold<int>(0, (sum, doc) {
          final data = doc.data();
          final urls = data['imageUrls'] as List?;
          return sum + (urls?.length ?? 0);
        }),
      };
    } catch (e) {
      print('Error getting cache stats: $e');
      return {};
    }
  }
}

// Legacy compatibility - keep the old class name
class ImageSearchService {
  static Future<List<String>> fetchConditionImages(
    String conditionName, {
    int maxResults = 3,
  }) async {
    return ImageCacheService.fetchConditionImages(
      conditionName,
      maxResults: maxResults,
    );
  }

  static Future<String?> getConditionImage(String conditionName) async {
    final images = await ImageCacheService.fetchConditionImages(
      conditionName,
      maxResults: 1,
    );
    return images.isNotEmpty ? images.first : null;
  }

  static String getPlaceholderImage(String conditionName) {
    return ImageCacheService.getPlaceholderImage(conditionName);
  }
}
