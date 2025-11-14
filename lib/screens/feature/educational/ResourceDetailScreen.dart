// Enhanced Resource Detail Screen
import 'package:allergen/screens/feature/educational/Informational_Screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourceDetailScreen extends StatelessWidget {
  final ResourceLink resource;

  const ResourceDetailScreen({Key? key, required this.resource})
    : super(key: key);

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Could not open $urlString')),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.open_in_new, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Opening external link...')),
                ],
              ),
              backgroundColor: resource.color,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        title: Text(
          resource.title,
          style: AppTextStyles.headline.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: resource.color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.open_in_new),
            onPressed: () => _launchURL(context, resource.url),
            tooltip: 'Open in browser',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // 🔥 CAROUSEL AREA
            // --------------------------------------------------
            CarouselSlider(
              options: CarouselOptions(
                height: 240,
                autoPlay: true,
                enlargeCenterPage: true,
                enableInfiniteScroll: true,
                viewportFraction: 0.9,
              ),
              items:
                  resource.imagePaths.map((path) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        path,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    );
                  }).toList(),
            ),

            const SizedBox(height: 16),

            // CATEGORY LABEL
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: resource.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  resource.category,
                  style: TextStyle(
                    color: resource.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // DESCRIPTION SECTION
            // --------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            color: resource.color,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Overview',
                            style: AppTextStyles.headline.copyWith(
                              fontSize: 18,
                              color: AppColors.textBlack,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        resource.description,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          color: AppColors.textGray,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // DETAILED MARKDOWN CONTENT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMarkdownContent(resource.detailedContent),
            ),

            const SizedBox(height: 24),

            // --------------------------------------------------
            // EXTERNAL RESOURCE CARD
            // --------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: resource.color.withOpacity(0.05),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.public, color: resource.color, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'External Resource',
                            style: AppTextStyles.headline.copyWith(
                              fontSize: 17,
                              color: AppColors.textBlack,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: resource.color.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.link, color: resource.color, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                resource.url,
                                style: TextStyle(
                                  color: resource.color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchURL(context, resource.url),
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: const Text(
                            'Visit Source Website',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: resource.color,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.textBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This will open in your default browser',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  //

  Widget _buildMarkdownContent(String content) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          lines.map((line) {
            if (line.startsWith('#')) {
              final level = line.split(' ')[0].length;
              final text = line.substring(level).trim();
              return Container(
                margin: EdgeInsets.only(top: level == 1 ? 0 : 16, bottom: 12),
                child: Text(
                  text,
                  style: AppTextStyles.headline.copyWith(
                    fontSize: level == 1 ? 22 : (level == 2 ? 18 : 16),
                    color: level == 1 ? resource.color : AppColors.textBlack,
                  ),
                ),
              );
            } else if (line.startsWith('-') || line.startsWith('•')) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 8, right: 12),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: resource.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line.substring(1).trim(),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else if (line.trim().isEmpty) {
              return const SizedBox(height: 12);
            } else if (line.startsWith('###')) {
              final text = line.substring(3).trim();
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  text,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  line,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textGray,
                  ),
                ),
              );
            }
          }).toList(),
    );
  }
}
