import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ImageSearchService {
  static String get apiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';
  static String get searchEngineId =>
      dotenv.env['GOOGLE_CSE_ID'] ?? '936b257bec9c04ee0';

  static Future<List<String>> fetchConditionImages(
    String conditionName, {
    int maxResults = 3,
  }) async {
    try {
      if (apiKey.isEmpty) {
        print(
          'Google API Key is missing. Please add GOOGLE_API_KEY to your .env file',
        );
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

      print('Fetching images for: $conditionName');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
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

        print('Found ${imageUrls.length} images');
        return imageUrls;
      } else {
        print('Error fetching images: ${response.statusCode}');
        print('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception fetching images: $e');
      return [];
    }
  }

  static Future<String?> getConditionImage(String conditionName) async {
    final images = await fetchConditionImages(conditionName, maxResults: 1);
    return images.isNotEmpty ? images.first : null;
  }

  static String getPlaceholderImage(String conditionName) {
    return 'https://via.placeholder.com/400x200/E3F2FD/1976D2?text=${Uri.encodeComponent(conditionName)}';
  }
}

class PexelsImageService {
  static String get apiKey => dotenv.env['PEXELS_API_KEY'] ?? '';

  static Future<String?> fetchConditionImage(String conditionName) async {
    try {
      if (apiKey.isEmpty) {
        print('Pexels API Key is missing');
        return null;
      }

      final query = Uri.encodeComponent('$conditionName skin medical');
      final url = Uri.parse(
        'https://api.pexels.com/v1/search?query=$query&per_page=1',
      );

      final response = await http
          .get(url, headers: {'Authorization': apiKey})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['photos'] != null && data['photos'].isNotEmpty) {
          return data['photos'][0]['src']['large'];
        }
      }
      return null;
    } catch (e) {
      print('Exception fetching Pexels image: $e');
      return null;
    }
  }
}
