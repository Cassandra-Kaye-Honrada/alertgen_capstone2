import 'package:flutter/material.dart';
import 'dart:async';

// Data Models
class Allergen {
  final String name;
  final String description;
  final String prevalence;
  final IconData icon;
  final Color color;

  Allergen({
    required this.name,
    required this.description,
    required this.prevalence,
    required this.icon,
    required this.color,
  });
}

class Article {
  final String title;
  final String timeAgo;
  final String summary;
  final IconData icon;
  final Color color;

  Article({
    required this.title,
    required this.timeAgo,
    required this.summary,
    required this.icon,
    required this.color,
  });
}

class FoodAllergyScreen extends StatefulWidget {
  const FoodAllergyScreen({Key? key}) : super(key: key);

  @override
  State<FoodAllergyScreen> createState() => _FoodAllergyScreenState();
}

class _FoodAllergyScreenState extends State<FoodAllergyScreen> {
  List<Allergen> allergens = [];
  List<Article> articles = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    // Simulate loading data from FoodAllergy.org
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      allergens = [
        Allergen(
          name: 'Milk',
          description:
              'Most common food allergy in infants and young children. About 2.5% of children under age 3 are allergic.',
          prevalence: '2.5% of children under 3',
          icon: Icons.local_drink,
          color: Colors.blue[300]!,
        ),
        Allergen(
          name: 'Eggs',
          description:
              'Among the most common food allergies in children. Most children eventually outgrow their egg allergy.',
          prevalence: 'Common in children',
          icon: Icons.egg,
          color: Colors.orange[300]!,
        ),
        Allergen(
          name: 'Peanuts',
          description:
              'One of the most common allergens associated with anaphylaxis. Affects about 2.5% of children.',
          prevalence: '2.5% of children',
          icon: Icons.circle,
          color: Colors.brown[400]!,
        ),
        Allergen(
          name: 'Tree Nuts',
          description:
              'Includes almonds, walnuts, pecans, cashews. About 40% of peanut-allergic individuals also have tree nut allergy.',
          prevalence: '0.4-0.5% of population',
          icon: Icons.nature,
          color: Colors.brown[300]!,
        ),
        Allergen(
          name: 'Soy',
          description:
              'Common allergen derived from soybeans. Often found in processed foods and Asian cuisine.',
          prevalence: 'Common in processed foods',
          icon: Icons.eco,
          color: Colors.green[400]!,
        ),
        Allergen(
          name: 'Wheat',
          description:
              'One of the eight major allergens. Different from celiac disease which is an autoimmune condition.',
          prevalence: 'Major allergen',
          icon: Icons.grass,
          color: Colors.amber[700]!,
        ),
        Allergen(
          name: 'Fish',
          description:
              'Includes bass, flounder, cod, and other finned fish. Must be labeled on packaged foods.',
          prevalence: 'More common in adults',
          icon: Icons.set_meal,
          color: Colors.cyan[400]!,
        ),
        Allergen(
          name: 'Shellfish',
          description:
              'Includes crustacean shellfish (crab, lobster, shrimp). Most common food allergy in adults.',
          prevalence: 'Most common in adults',
          icon: Icons.water,
          color: Colors.red[300]!,
        ),
        Allergen(
          name: 'Sesame',
          description:
              'The 9th major allergen as of January 1, 2023. Must now be labeled on all packaged foods.',
          prevalence: 'Recently added to list',
          icon: Icons.grain,
          color: Colors.yellow[700]!,
        ),
      ];

      articles = [
        Article(
          title: 'Understanding the Nine Major Food Allergens',
          timeAgo: '2 hours ago',
          summary:
              'Learn about the Big Nine allergens that account for 90% of food allergic reactions.',
          icon: Icons.article,
          color: Colors.blue[300]!,
        ),
        Article(
          title: 'Anaphylaxis: Recognizing the Signs and Taking Action',
          timeAgo: '5 hours ago',
          summary:
              'Anaphylaxis is a severe allergic reaction requiring immediate epinephrine injection.',
          icon: Icons.emergency,
          color: Colors.red[300]!,
        ),
        Article(
          title: 'How to Read Food Labels for Allergens',
          timeAgo: '8 hours ago',
          summary:
              'FALCPA requires clear labeling of major food allergens on packaged foods.',
          icon: Icons.label,
          color: Colors.orange[300]!,
        ),
        Article(
          title: 'Sesame Now Recognized as 9th Major Allergen',
          timeAgo: '1 day ago',
          summary:
              'As of January 2023, sesame must be labeled on all packaged foods in the U.S.',
          icon: Icons.new_releases,
          color: Colors.purple[300]!,
        ),
        Article(
          title: 'Living with Food Allergies: Daily Management Tips',
          timeAgo: '2 days ago',
          summary:
              'Managing food allergies requires constant vigilance and proper allergen avoidance.',
          icon: Icons.home,
          color: Colors.green[300]!,
        ),
      ];

      isLoading = false;
    });
  }

  List<Allergen> getFilteredAllergens() {
    if (searchQuery.isEmpty) return allergens;
    return allergens
        .where(
          (a) =>
              a.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              a.description.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Allergy Education'),
        backgroundColor: Colors.blue[400],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      _buildStatsCard(),
                      _buildSectionHeader(
                        context,
                        'Major Food Allergens',
                        true,
                      ),
                      _buildAllergensGrid(),
                      const SizedBox(height: 20),
                      _buildEmergencyCard(),
                      const SizedBox(height: 20),
                      _buildSectionHeader(context, 'Hot Topic', false),
                      _buildHotTopic(),
                      const SizedBox(height: 20),
                      _buildSectionHeader(context, 'Latest Articles', true),
                      ...articles.map((article) => _buildNewsItem(article)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[400],
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search allergens, symptoms...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[300]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Food Allergy Facts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow('33 million', 'People in U.S. impacted'),
          _buildStatRow('1 in 13', 'Children have food allergies'),
          _buildStatRow('11%', 'Adults with food allergies'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String number, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            number,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '- $label',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool showAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (showAll)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('View all items')));
              },
              child: Row(
                children: const [
                  Text('All'),
                  Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllergensGrid() {
    final filtered = getFilteredAllergens();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No allergens found',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildAllergenCard(filtered[index]);
      },
    );
  }

  Widget _buildAllergenCard(Allergen allergen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAllergenDetails(allergen),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: allergen.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(allergen.icon, color: allergen.color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                allergen.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[300]!, width: 2),
      ),
      child: InkWell(
        onTap: () => _showEmergencyInfo(),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emergency, color: Colors.red[700], size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Action Plan',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to learn about anaphylaxis signs and epinephrine use',
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.red[700]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotTopic() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[300]!, Colors.blue[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _showCrossContaminationInfo(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Understanding Cross-Contamination',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Learn about "may contain" labels and shared equipment risks',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.restaurant, color: Colors.white, size: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsItem(Article article) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _showArticleDetails(article),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: article.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(article.icon, color: article.color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.timeAgo,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAllergenDetails(Allergen allergen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: allergen.color.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                allergen.icon,
                                color: allergen.color,
                                size: 40,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                allergen.name,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildDetailSection('About', allergen.description),
                        _buildDetailSection('Prevalence', allergen.prevalence),
                        _buildDetailSection(
                          'Labeling',
                          'This allergen must be clearly labeled on all packaged foods according to FALCPA and FASTER Act requirements.',
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check),
                            label: const Text('Got it'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showArticleDetails(Article article) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(article.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.timeAgo,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(article.summary),
                const SizedBox(height: 16),
                Text(
                  'Source: FoodAllergy.org',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showEmergencyInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.emergency, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Anaphylaxis Emergency'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anaphylaxis is a severe, potentially life-threatening allergic reaction.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Signs & Symptoms:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('• Difficulty breathing or wheezing'),
                  Text('• Swelling of throat, tongue, or lips'),
                  Text('• Rapid pulse'),
                  Text('• Dizziness or fainting'),
                  Text('• Skin reactions (hives, itching)'),
                  const SizedBox(height: 16),
                  Text(
                    'Treatment:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('• Inject epinephrine immediately'),
                  Text('• Call 911'),
                  Text('• Lay person down with legs elevated'),
                  Text('• Give second dose if no improvement in 5-15 minutes'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Text(
                      '⚠️ Always carry TWO epinephrine auto-injectors',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showCrossContaminationInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cross-Contamination'),
            content: SingleChildScrollView(
              child: Text(
                'Cross-contact occurs when a residue or trace amount of an allergenic food becomes incorporated into another food not intended to contain it.\n\n'
                'Advisory labels like "may contain" or "processed in a facility with" are voluntary and not regulated by law.\n\n'
                'The absence of an advisory label does NOT mean a product is safe. Always contact manufacturers if unsure.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About This App'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This educational app provides information about food allergies based on data from FoodAllergy.org (FARE).',
                ),
                const SizedBox(height: 16),
                Text(
                  'Key Facts:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('• 33 million Americans impacted'),
                Text('• 1 in 13 children affected'),
                Text('• 9 major allergens recognized'),
                const SizedBox(height: 16),
                Text(
                  'Always consult healthcare providers for medical advice.',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
