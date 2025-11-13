import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/health_environment_analytics/AirQualityDetailScreen.dart';
import 'package:allergen/screens/profile_screen_items/ProfileScreen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

// Data Models
class Allergen {
  final String name;
  final String description;
  final String prevalence;
  final IconData icon;
  final Color color;
  final List<String> symptoms;
  final List<String> hiddenSources;

  Allergen({
    required this.name,
    required this.description,
    required this.prevalence,
    required this.icon,
    required this.color,
    required this.symptoms,
    required this.hiddenSources,
  });
}

class Article {
  final String title;
  final String timeAgo;
  final String summary;
  final IconData icon;
  final Color color;
  final String url;

  Article({
    required this.title,
    required this.timeAgo,
    required this.summary,
    required this.icon,
    required this.color,
    required this.url,
  });
}

class ResourceLink {
  final String title;
  final String description;
  final String url;
  final IconData icon;
  final Color color;
  final String category;
  final String detailedContent;

  ResourceLink({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    required this.color,
    required this.category,
    required this.detailedContent,
  });
}

class FoodAllergyScreen extends StatefulWidget {
  const FoodAllergyScreen({Key? key}) : super(key: key);

  @override
  State<FoodAllergyScreen> createState() => _FoodAllergyScreenState();
}

class _FoodAllergyScreenState extends State<FoodAllergyScreen>
    with TickerProviderStateMixin {
  List<Allergen> allergens = [];
  List<ResourceLink> resources = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedFilter = 'All';
  late AnimationController _fabController;
  late AnimationController _statsController;
  Timer? _refreshTimer;

  final List<String> filters = ['All', 'Children', 'Adults', 'Severe'];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _statsController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      loadData();
    });
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $urlString'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    setState(() {
      allergens = [
        Allergen(
          name: 'Milk',
          description:
              'Most common food allergy in infants and young children. About 2.5% of children under age 3 are allergic.',
          prevalence: '2.5% of children under 3',
          icon: Icons.local_drink,
          color: AppColors.primary,
          symptoms: [
            'Hives or skin rash',
            'Digestive problems',
            'Wheezing',
            'Swelling of lips/throat',
          ],
          hiddenSources: [
            'Baked goods',
            'Processed meats',
            'Margarine',
            'Nougat',
            'Caramel candies',
          ],
        ),
        Allergen(
          name: 'Eggs',
          description:
              'Among the most common food allergies in children. Most children eventually outgrow their egg allergy.',
          prevalence: 'Common in children',
          icon: Icons.egg,
          color: AppColors.primaryColor2Teal,
          symptoms: [
            'Skin inflammation',
            'Nasal congestion',
            'Digestive upset',
            'Asthma symptoms',
          ],
          hiddenSources: [
            'Mayonnaise',
            'Marshmallows',
            'Pasta',
            'Foam on coffee',
            'Pretzels',
          ],
        ),
        Allergen(
          name: 'Peanuts',
          description:
              'One of the most common allergens associated with anaphylaxis. Affects about 2.5% of children.',
          prevalence: '2.5% of children',
          icon: Icons.circle,
          color: AppColors.primary,
          symptoms: [
            'Anaphylaxis',
            'Throat tightness',
            'Difficulty breathing',
            'Rapid pulse',
          ],
          hiddenSources: [
            'Asian cuisine',
            'Baked goods',
            'Candy',
            'Chili',
            'Pet food',
          ],
        ),
        Allergen(
          name: 'Tree Nuts',
          description:
              'Includes almonds, walnuts, pecans, cashews. About 40% of peanut-allergic individuals also have tree nut allergy.',
          prevalence: '0.4-0.5% of population',
          icon: Icons.nature,
          color: AppColors.primaryColor2Teal,
          symptoms: [
            'Severe reactions',
            'Breathing problems',
            'Skin reactions',
            'GI distress',
          ],
          hiddenSources: [
            'Pesto',
            'Barbecue sauce',
            'Cereals',
            'Ice cream',
            'Liqueurs',
          ],
        ),
        Allergen(
          name: 'Soy',
          description:
              'Common allergen derived from soybeans. Often found in processed foods and Asian cuisine.',
          prevalence: 'Common in processed foods',
          icon: Icons.eco,
          color: AppColors.primary,
          symptoms: [
            'Itching',
            'Tingling mouth',
            'Runny nose',
            'Skin reactions',
          ],
          hiddenSources: [
            'Vegetable broth',
            'Canned tuna',
            'Processed meats',
            'Energy bars',
            'Worcestershire',
          ],
        ),
        Allergen(
          name: 'Wheat',
          description:
              'One of the eight major allergens. Different from celiac disease which is an autoimmune condition.',
          prevalence: 'Major allergen',
          icon: Icons.grass,
          color: AppColors.primaryColor2Teal,
          symptoms: [
            'Hives',
            'Difficulty breathing',
            'Digestive upset',
            'Nasal congestion',
          ],
          hiddenSources: [
            'Soy sauce',
            'Beer',
            'Ice cream',
            'Processed meats',
            'Gelatinized starch',
          ],
        ),
        Allergen(
          name: 'Fish',
          description:
              'Includes bass, flounder, cod, and other finned fish. Must be labeled on packaged foods.',
          prevalence: 'More common in adults',
          icon: Icons.set_meal,
          color: AppColors.primary,
          symptoms: ['Hives', 'Vomiting', 'Diarrhea', 'Anaphylaxis possible'],
          hiddenSources: [
            'Caesar dressing',
            'Worcestershire',
            'Imitation crab',
            'Asian sauces',
            'Supplements',
          ],
        ),
        Allergen(
          name: 'Shellfish',
          description:
              'Includes crustacean shellfish (crab, lobster, shrimp). Most common food allergy in adults.',
          prevalence: 'Most common in adults',
          icon: Icons.water,
          color: AppColors.primaryColor2Teal,
          symptoms: [
            'Anaphylaxis',
            'Hives',
            'Indigestion',
            'Respiratory issues',
          ],
          hiddenSources: [
            'Asian cuisine',
            'Bouillabaisse',
            'Cuttlefish ink',
            'Glucosamine',
            'Surimi',
          ],
        ),
        Allergen(
          name: 'Sesame',
          description:
              'The 9th major allergen as of January 1, 2023. Must now be labeled on all packaged foods.',
          prevalence: 'Recently added to list',
          icon: Icons.grain,
          color: AppColors.primary,
          symptoms: [
            'Anaphylaxis',
            'Skin rash',
            'Digestive issues',
            'Respiratory problems',
          ],
          hiddenSources: ['Bread', 'Crackers', 'Tahini', 'Hummus', 'Cosmetics'],
        ),
      ];

      resources = [
        ResourceLink(
          title: 'Food Allergy Information',
          description: 'Comprehensive guide to food allergies and management',
          url:
              'https://www.aaaai.org/conditions-treatments/allergies/food-allergy',
          icon: Icons.food_bank,
          color: AppColors.primary,
          category: 'Educational',
          detailedContent: '''
# Comprehensive Food Allergy Guide

## Understanding Food Allergies
A food allergy occurs when the immune system mistakenly identifies a specific food or substance in food as harmful. When you eat the offending food, your immune system releases antibodies and chemicals like histamine.

## Common Symptoms
- Hives, itching, or eczema
- Swelling of the lips, face, tongue, or throat
- Wheezing, nasal congestion, or trouble breathing
- Abdominal pain, diarrhea, nausea, or vomiting
- Dizziness, lightheadedness, or fainting

## Diagnosis and Testing
- Skin prick tests
- Blood tests (specific IgE)
- Oral food challenges
- Elimination diets

## Management Strategies
- Strict avoidance of allergens
- Reading food labels carefully
- Carrying emergency medication
- Having an action plan
          ''',
        ),
        ResourceLink(
          title: 'Common Allergens',
          description: 'Learn about the most common food allergens',
          url:
              'https://www.foodallergy.org/living-food-allergies/food-allergy-essentials/common-allergens',
          icon: Icons.warning_amber_rounded,
          color: AppColors.primaryColor2Teal,
          category: 'Reference',
          detailedContent: '''
# The Big 9 Allergens

## 1. Milk
- Most common in children
- Different from lactose intolerance
- Often outgrown by adulthood

## 2. Eggs
- Second most common in children
- Both yolk and white can cause reactions
- Often outgrown

## 3. Peanuts
- One of the most severe allergens
- Rarely outgrown
- High risk of anaphylaxis

## 4. Tree Nuts
- Includes almonds, walnuts, cashews
- Often lifelong allergy
- Cross-reactivity common

## 5. Soy
- Common in processed foods
- Often outgrown in childhood
- Found in many Asian dishes

## 6. Wheat
- Different from celiac disease
- Often outgrown
- Many alternative grains available

## 7. Fish
- More common in adults
- Can develop later in life
- Specific to certain fish types

## 8. Shellfish
- Most common in adults
- Includes crustaceans and mollusks
- Often lifelong

## 9. Sesame
- Recently recognized major allergen
- Must be labeled since 2023
- Found in many baked goods
          ''',
        ),
        ResourceLink(
          title: 'Anaphylaxis Guide',
          description: 'Emergency information and treatment protocols',
          url: 'https://www.foodallergy.org/resources/anaphylaxis',
          icon: Icons.emergency,
          color: AppColors.primary,
          category: 'Emergency',
          detailedContent: '''
# Anaphylaxis Emergency Guide

## What is Anaphylaxis?
Anaphylaxis is a severe, potentially life-threatening allergic reaction that can occur within seconds or minutes of exposure to an allergen.

## Signs and Symptoms

### Mild to Moderate Reactions
- Hives, welts, or body redness
- Tingling mouth
- Swelling of lips, face, eyes
- Vomiting, abdominal pain

### Severe Reactions (Anaphylaxis)
- Difficult or noisy breathing
- Swelling of tongue and throat
- Wheezing or persistent cough
- Difficulty talking or hoarse voice
- Persistent dizziness or collapse
- Pale and floppy (young children)

## Emergency Treatment

### Step 1: Administer Epinephrine
- Use auto-injector immediately
- Don't wait to see if symptoms improve
- Inject into outer thigh
- Massage area for 10 seconds

### Step 2: Call Emergency Services
- Call 911 or local emergency number
- Say "anaphylaxis" clearly
- Request ambulance with epinephrine

### Step 3: Additional Care
- Lie person flat, don't allow standing
- If breathing difficult, allow sitting
- Don't give food or drink
- Be prepared for second dose

## Prevention
- Always carry two epinephrine auto-injectors
- Wear medical identification
- Have an action plan
- Educate family and friends
          ''',
        ),
        ResourceLink(
          title: 'Living with Allergies',
          description: 'Daily management and lifestyle tips',
          url:
              'https://www.aaaai.org/conditions-treatments/allergies/drug-allergy',
          icon: Icons.favorite,
          color: AppColors.primaryColor2Teal,
          category: 'Lifestyle',
          detailedContent: '''
# Daily Management Guide

## Meal Planning
### Safe Cooking Practices
- Clean all surfaces thoroughly
- Use separate utensils and cookware
- Prepare allergen-free meals first
- Label containers clearly

### Grocery Shopping
- Read labels every time (ingredients can change)
- Look for "may contain" warnings
- Choose certified allergen-free products
- Shop during less busy hours

## Social Situations

### Eating Out Safely
- Call ahead to discuss allergies
- Speak to manager and chef directly
- Choose simple preparation methods
- Avoid buffet-style restaurants

### Parties and Gatherings
- Bring safe food to share
- Educate hosts about cross-contamination
- Have emergency medication accessible
- Consider eating before attending

## Travel Tips

### Planning
- Research medical facilities at destination
- Learn key phrases in local language
- Carry doctor's note and prescription
- Pack extra medication

### Air Travel
- Notify airline in advance
- Bring safe snacks and meals
- Wipe down tray tables and armrests
- Keep medication in carry-on

## Emotional Well-being
- Join support groups
- Practice stress management
- Educate friends and family
- Focus on what you can eat
          ''',
        ),
        ResourceLink(
          title: 'Child Allergy Guide',
          description: 'Managing allergies in children and schools',
          url:
              'https://www.aaaai.org/conditions-treatments/allergies/skin-allergy',
          icon: Icons.child_care,
          color: AppColors.primary,
          category: 'Pediatric',
          detailedContent: '''
# Children's Allergy Management

## School Preparation

### Communication with School
- Meet with school nurse and administration
- Provide written allergy action plan
- Educate teachers and staff
- Discuss field trip safety

### Classroom Safety
- No-food sharing policies
- Hand-washing routines
- Clean eating surfaces
- Allergy-aware classroom

## Age-Specific Guidance

### Infants and Toddlers
- Introduce allergens one at a time
- Watch for reaction signs
- Keep emergency plans visible
- Educate all caregivers

### School-age Children
- Teach them to recognize symptoms
- Practice saying "no" to unsafe foods
- Role-play asking for help
- Build confidence in self-advocacy

### Teenagers
- Discuss social pressures
- Review emergency procedures
- Encourage carrying own medication
- Address dating and social situations

## Emergency Preparedness

### Action Plan Components
- Clear symptom identification
- Step-by-step emergency instructions
- Emergency contacts
- Medication locations

### Training
- Train teachers and staff
- Practice with substitute teachers
- Update plans annually
- Review with child as they age
          ''',
        ),
        ResourceLink(
          title: 'Skin Allergy Information',
          description: 'Learn about skin allergies, symptoms, and treatments',
          url:
              'https://www.aaaai.org/conditions-treatments/allergies/skin-allergy',
          icon: Icons.face,
          color: AppColors.primaryColor2Teal,
          category: 'Medical',
          detailedContent: '''
# Skin Allergy Information

## Overview
Irritated skin can be caused by a variety of factors. These include immune system disorders, medications and infections. When an allergen is responsible for triggering an immune system response in the skin, then it is an allergic skin condition.

## Types of Skin Allergies

### Atopic Dermatitis (Eczema)
Eczema is the most common skin condition, especially in children. It affects one in five infants but only 10% of adults. One explanation for eczema is thought to be due to "leakiness" of the skin barrier, which causes it to dry out and become prone to irritation and inflammation by many environmental factors.

**Key Facts:**
- Some young children with eczema can flare with a particular food
- In about half of patients with severe atopic dermatitis, the disease is due to inheritance of a faulty gene in their skin called filaggrin
- Unlike with urticaria (hives), histamine is not the only cause of the itch of eczema so anti-histamines may not control the symptoms
- Eczema is often linked with asthma, allergic rhinitis (hay fever) or food allergy
- This order of progression is called the atopic march

### Allergic Contact Dermatitis
Allergic contact dermatitis occurs when your skin comes in direct contact with an allergen.

**Common Triggers:**
- Nickel allergy from jewelry
- Poison ivy, poison oak and poison sumac
- The red, itchy rash is caused by an oily coating covering these plants
- Can also come from touching clothing, pets or gardening tools that have contact with the oil

### Urticaria (Hives)
Hives are an inflammation of the skin triggered when the immune system releases histamine. This causes small blood vessels to leak, which leads to swelling and itching.

**Types:**
- **Acute urticaria**: Occurs after eating a particular food or contact with a trigger
- **Chronic urticaria**: Lasts more than six weeks and can last months or years
- Swelling without itching in deep layers of the skin is called angioedema

### Angioedema
Angioedema is swelling without itching in the deep layers of the skin. It is often seen together with urticaria (hives).

**Characteristics:**
- Often occurs in soft tissues such as eyelids, mouth or genitals
- **Acute**: Lasts minutes to hours, commonly caused by allergic reactions
- **Chronic recurrent**: Returns over long periods, each episode lasting hours to days

### Hereditary Angioedema (HAE)
- Rare but serious genetic condition involving swelling in various body parts
- Does not respond to typical angioedema treatment with antihistamines or adrenaline
- Important to see a specialist for screening

## Symptoms & Diagnosis

### Atopic Dermatitis (Eczema)
**Symptoms:**
- Itchy, red or dry skin
- May "weep" or leak fluid that crusts over when scratched
- In infants: often appears on the face
- In children: elbows, wrists, behind knees and ears
- In adolescents/adults: same as children plus hands and feet

**Diagnosis:**
- Treatment depends on moisturizers and topical medicines
- Topical steroids for inflammation
- Severe cases may need antibiotics for infection
- Infants with severe eczema should be evaluated for food allergy

### Urticaria (Hives) and Angioedema
**Symptoms:**
- Itchy, red and white raised bumps or welts
- Welts disappear in minutes to hours without scarring
- Acute: lasts up to six weeks
- Chronic: lasts more than six weeks, even months or years
- Angioedema: swelling without itch around eyes, cheeks, lips

**Diagnosis:**
- Majority of chronic cases have no identifiable cause
- Allergy testing helpful for acute cases with specific triggers
- Food allergy rarely causes chronic hives

## Treatment & Management

### Atopic Dermatitis (Eczema)
**Key Strategies:**
- Avoid scratching - "itch which rashes"
- Skin care to rehydrate and repair skin barrier
- Trilipid creams and moisturizers
- Topical medications: steroids, calcineurin inhibitors, phosphodiesterase 4 inhibitors, JAK inhibitors

**Advanced Therapies:**
- Dupilumab: injectable biologic for moderate-to-severe cases (ages 6 months+)
- Tralokinumab: injectable biologic for adults with moderate-to-severe cases
- Oral JAK/STAT inhibitors: Upadacitinib (age 12+), Abrocitinib (age 18+)

**Additional Treatments:**
- Antibiotics for bacterial infections
- Antifungals for secondary fungal infections
- Avoid oral steroids due to side effects and rebound
- Cotton undergarments to protect skin
- Avoid soap products with sodium laurel sulfate

### Urticaria (Hives) and Angioedema
**Management:**
- Identify and avoid triggers when possible
- Oral antihistamines to control itch and recurrence
- Increased antihistamine doses if needed
- Omalizumab: injectable biologic for chronic spontaneous urticaria (age 12+)
- For angioedema with ACE inhibitors: consult doctor for medication change

## Important Notes
- Skin conditions are among the most common forms of allergy treated by allergists/immunologists
- Always consult with a specialist for accurate diagnosis and personalized treatment
- Chronic conditions may require ongoing management strategies
- Early intervention can prevent complications and improve quality of life

## When to See a Specialist
- Symptoms interfere with daily activities
- Over-the-counter treatments ineffective
- Condition lasts more than two weeks
- Severe reactions involving breathing difficulties
- Suspected hereditary conditions like HAE
''',
        ),
        ResourceLink(
          title: 'Cross-Contamination',
          description: 'Preventing accidental exposure risks',
          url:
              'https://www.aaaai.org/conditions-treatments/allergies/hay-fever-rhinitis',
          icon: Icons.cleaning_services,
          color: AppColors.primary,
          category: 'Safety',
          detailedContent: '''
# Cross-Contamination Prevention

## Understanding Risks

### Direct Cross-Contact
- Using same utensils for different foods
- Shared cooking surfaces and oils
- Food preparation on contaminated surfaces
- Hand-to-food contact

### Indirect Cross-Contact
- Airborne particles during cooking
- Residual allergens in shared equipment
- Storage of allergen-containing foods
- Improper cleaning procedures

## Home Safety Measures

### Kitchen Organization
- Designate allergen-free zones
- Use color-coded utensils and cutting boards
- Store allergen-free foods separately
- Label all containers clearly

### Cleaning Protocols
- Wash hands with soap and water
- Use separate sponges and cloths
- Clean surfaces with dedicated cleaners
- Run empty cycle in dishwasher between loads

## Reading Labels Effectively

### Required Labeling
The FDA requires clear labeling of the 9 major allergens:
- Milk
- Eggs
- Fish
- Shellfish
- Tree nuts
- Peanuts
- Wheat
- Soybeans
- Sesame

### Advisory Statements
Voluntary warnings include:
- "May contain [allergen]"
- "Processed in a facility that also processes [allergen]"
- "Made on shared equipment with [allergen]"

## Best Practices
- Always read labels, even on familiar products
- Contact manufacturers when in doubt
- Choose products with clear allergen statements
- When unsure, choose certified allergen-free products
          ''',
        ),
      ];

      isLoading = false;
    });

    _statsController.forward(from: 0);
  }

  List<Allergen> getFilteredAllergens() {
    var filtered = allergens;

    if (searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (a) =>
                    a.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    a.description.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ),
              )
              .toList();
    }

    if (selectedFilter != 'All') {
      filtered =
          filtered.where((a) {
            switch (selectedFilter) {
              case 'Children':
                return a.prevalence.toLowerCase().contains('children');
              case 'Adults':
                return a.prevalence.toLowerCase().contains('adults');
              case 'Severe':
                return a.symptoms.any(
                  (s) => s.toLowerCase().contains('anaphylaxis'),
                );
              default:
                return true;
            }
          }).toList();
    }

    return filtered;
  }

  Widget buildTreatmentSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Treat Allergic Reaction',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Learn essential first aid steps for allergic reactions.',
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FirstAidScreen()),
                  ),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home
          GestureDetector(
            onTap:
                () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Icon(Icons.home, color: AppColors.Gray, size: 24),
          ),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AirQualityDetailScreen(
                        apiKey: 'AIzaSyCWva81wgqeq5qIShLvoO9hs20ejk73gCE',
                      ),
                ),
              );
            },
            child: const Icon(
              Icons.analytics_outlined,
              color: AppColors.Gray,
              size: 24,
            ),
          ),

          // Scanner
          GestureDetector(
            onTap: () {
              // Navigate to scanner - you'll need to import your scanner screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CameraScannerScreen()),
              );
            },
            child: Image.asset(
              'assets/navigation/scan_gray.png',
              width: 18,
              height: 18,
              errorBuilder:
                  (context, error, stackTrace) => Icon(
                    Icons.camera_alt,
                    color: Color(0xFF64748B),
                    size: 24,
                  ),
            ),
          ),

          // Education/Food Allergy
          GestureDetector(
            onTap: () {
              // Navigate to food allergy screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FoodAllergyScreen()),
              );
            },
            child: const Icon(Icons.school, color: AppColors.primary, size: 35),
          ),

          // Profile
          GestureDetector(
            onTap: () {
              // Navigate to profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          UserProfile(emergencyService: EmergencyService()),
                ),
              );
            },
            child: Icon(Icons.person, color: AppColors.Gray, size: 24),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        title: Text(
          'Learn About Allergy',
          style: AppTextStyles.headline.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'About',
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
              : RefreshIndicator(
                onRefresh: loadData,
                backgroundColor: AppColors.primary,
                color: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchBar(),
                          _buildFilterChips(),
                          _buildAnimatedStatsCard(),
                          const SizedBox(height: 8),
                          _buildSectionHeader(
                            context,
                            'Major Food Allergens',
                            Icons.restaurant,
                          ),
                          _buildAllergensGrid(),
                          const SizedBox(height: 16),
                          buildTreatmentSection(),

                          _buildSectionHeader(
                            context,
                            'Educational Resources',
                            Icons.menu_book,
                          ),
                          ...resources.map(
                            (resource) => _buildResourceItem(resource, context),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.textBlack.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search allergens, symptoms...',
            hintStyle: TextStyle(color: AppColors.textGray),
            prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 24),
            suffixIcon:
                searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(Icons.clear, color: AppColors.textGray),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                        });
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(
                filter,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textBlack,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedFilter = selected ? filter : 'All';
                });
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textBlack,
              ),
              elevation: isSelected ? 4 : 1,
              shadowColor: AppColors.primary.withOpacity(0.3),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedStatsCard() {
    return AnimatedBuilder(
      animation: _statsController,
      builder: (context, child) {
        return Opacity(
          opacity: _statsController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _statsController.value)),
            child: _buildStatsCard(),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Food Allergy Statistics',
                  style: AppTextStyles.headline.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: loadData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatRow(Icons.people, '33 million', 'People in U.S. impacted'),
          _buildStatRow(
            Icons.child_care,
            '1 in 13',
            'Children have food allergies',
          ),
          _buildStatRow(Icons.person, '11%', 'Adults with food allergies'),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  'Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String number, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            number,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.headline.copyWith(
              fontSize: 20,
              color: AppColors.textBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergensGrid() {
    final filtered = getFilteredAllergens();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppColors.textGray,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No allergens found',
                style: AppTextStyles.headline.copyWith(
                  color: AppColors.textBlack,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
              ),
            ],
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
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildAllergenCard(filtered[index]);
      },
    );
  }

  Widget _buildAllergenCard(Allergen allergen) {
    return Card(
      elevation: 3,
      shadowColor: allergen.color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showAllergenDetails(allergen),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: allergen.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: allergen.color.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(allergen.icon, color: allergen.color, size: 24),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    allergen.name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: allergen.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Tap to learn',
                    style: TextStyle(
                      fontSize: 8,
                      color: allergen.color,
                      fontWeight: FontWeight.w600,
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

  Widget _buildResourceItem(ResourceLink resource, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shadowColor: resource.color.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _navigateToResourceDetail(resource, context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: resource.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(resource.icon, color: resource.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.title,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          resource.description,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            color: AppColors.textGray,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: resource.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                resource.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: resource.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Spacer(),
                            Text(
                              'Read more',
                              style: TextStyle(
                                fontSize: 12,
                                color: resource.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: resource.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: resource.color,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToResourceDetail(ResourceLink resource, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResourceDetailScreen(resource: resource),
      ),
    );
  }

  void _showAllergenDetails(Allergen allergen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.defaultbackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppColors.lightGray,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: allergen.color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  allergen.icon,
                                  color: allergen.color,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      allergen.name,
                                      style: AppTextStyles.headline.copyWith(
                                        fontSize: 28,
                                        color: AppColors.textBlack,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: allergen.color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        allergen.prevalence,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: allergen.color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _buildDetailSection(
                            'About',
                            allergen.description,
                            Icons.info_outline,
                            allergen.color,
                          ),
                          _buildDetailSection(
                            'Common Symptoms',
                            allergen.symptoms.map((s) => '• $s').join('\n'),
                            Icons.warning_amber_rounded,
                            allergen.color,
                          ),
                          _buildDetailSection(
                            'Hidden Sources',
                            allergen.hiddenSources
                                .map((s) => '• $s')
                                .join('\n'),
                            Icons.visibility_off,
                            allergen.color,
                          ),
                          _buildDetailSection(
                            'Labeling Requirements',
                            'This allergen must be clearly labeled on all packaged foods according to FALCPA and FASTER Act requirements.',
                            Icons.label,
                            allergen.color,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showEmergencyInfo();
                                  },
                                  icon: const Icon(Icons.emergency, size: 20),
                                  label: const Text(
                                    'Emergency Info',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.check, size: 20),
                                  label: const Text(
                                    'Got it',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: allergen.color,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(
                                      color: allergen.color,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildDetailSection(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textGray,
              height: 1.6,
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emergency,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Anaphylaxis Emergency',
                    style: AppTextStyles.headline.copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Anaphylaxis is a severe, potentially life-threatening allergic reaction.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Signs & Symptoms:',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textBlack,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildSymptomItem('Difficulty breathing or wheezing'),
                  _buildSymptomItem('Swelling of throat, tongue, or lips'),
                  _buildSymptomItem('Rapid pulse'),
                  _buildSymptomItem('Dizziness or fainting'),
                  _buildSymptomItem('Skin reactions (hives, itching)'),
                  const SizedBox(height: 16),
                  Text(
                    'Treatment Steps:',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textBlack,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildTreatmentStep('1', 'Inject epinephrine immediately'),
                  _buildTreatmentStep('2', 'Call 911'),
                  _buildTreatmentStep(
                    '3',
                    'Lay person down with legs elevated',
                  ),
                  _buildTreatmentStep(
                    '4',
                    'Give second dose if no improvement in 5-15 min',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor2Teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryColor2Teal.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.primaryColor2Teal,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Always carry TWO epinephrine auto-injectors',
                            style: TextStyle(
                              color: AppColors.primaryColor2Teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSymptomItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textGray,
                ),
              ),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.textBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info, color: AppColors.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'About This App',
                  style: AppTextStyles.headline.copyWith(fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This educational app provides information about food allergies based on data from FoodAllergy.org (FARE) and AAAAI.',
                    style: AppTextStyles.body.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoSection(
                    'Key Facts',
                    Icons.analytics,
                    AppColors.primary,
                    [
                      '33 million Americans impacted',
                      '1 in 13 children affected',
                      '9 major allergens recognized',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    'Features',
                    Icons.stars,
                    AppColors.primaryColor2Teal,
                    [
                      'Search allergens',
                      'Filter by category',
                      'Emergency info access',
                      'Educational resources',
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.medical_information,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Always consult healthcare providers for medical advice.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoSection(
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textBlack,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: color)),
                Expanded(
                  child: Text(
                    item,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      height: 1.3,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Enhanced Resource Detail Screen
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
            // Header Section
            Container(
              width: double.infinity,
              color: resource.color,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textBlack.withOpacity(0.1),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(resource.icon, color: resource.color, size: 48),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      resource.category,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description Card
                  Card(
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

                  const SizedBox(height: 20),

                  // Detailed Content
                  _buildMarkdownContent(resource.detailedContent),

                  const SizedBox(height: 24),

                  // External Link Card
                  Card(
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
                              Icon(
                                Icons.public,
                                color: resource.color,
                                size: 22,
                              ),
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
                                Icon(
                                  Icons.link,
                                  color: resource.color,
                                  size: 18,
                                ),
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
                              onPressed:
                                  () => _launchURL(context, resource.url),
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

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
