import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class AllergyScreen extends StatefulWidget {
  const AllergyScreen({super.key});

  @override
  State<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen>
    with SingleTickerProviderStateMixin {
  // Food Allergy
  String foodHeading = "";
  List<Map<String, dynamic>> foodContent = [];
  List<Map<String, String>> allergens = [];

  // Anaphylaxis
  String anaphylaxisHeading = "";
  List<Map<String, dynamic>> anaphylaxisContent = [];

  // Drug Allergy
  String drugHeading = "";
  List<Map<String, dynamic>> drugContent = [];

  // Skin Allergy
  String skinHeading = "";
  List<Map<String, dynamic>> skinContent = [];

  // Allergic Rhinitis (Environmental Allergy)
  String rhinitisHeading = "";
  List<Map<String, dynamic>> rhinitisContent = [];

  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    fetchAllData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchAllData() async {
    await Future.wait([
      fetchFoodAllergy(),
      scrapeAllergens(),
      fetchAnaphylaxis(),
      fetchDrugAllergy(),
      fetchSkinAllergy(),
      fetchRhinitis(),
    ]);

    setState(() {
      isLoading = false;
    });
    _animationController.forward();
  }

  bool shouldIncludeFoodAllergy(String text) {
    final includeKeywords = [
      'immune system overreacts',
      'particular protein found in that food',
      'Symptoms can occur when coming in contact',
      'tiny amount of the food',
      'first diagnosed in young children',
      'older children and adults',
      'Nine foods are responsible',
      'majority of allergic reactions',
      "Cow's milk",
      'Eggs',
      'Fish',
      'Peanuts',
      'Sesame',
      'Shellfish',
      'Soy',
      'Tree nuts',
      'Wheat',
      'think they are allergic',
      'actually be intolerant',
      'food intolerance and food allergy',
      'allergen triggers a response',
      'life-threatening',
      'avoid their food triggers',
      'allergic to a similar protein',
      'ragweed',
      'bananas or melons',
      'cross-reactivity',
      'oral allergy syndrome',
      'OAS',
      'children outgrow a food allergy',
      'adults to develop allergies',
      'Food Protein-Induced Enterocolitis Syndrome',
      'FPIES',
      'delayed food allergy',
      'vomiting and diarrhea',
      'dehydration and shock',
      'low blood pressure and poor blood circulation',
      'milk, soy and grains',
      'introduced to solid food or formula',
      'Eosinophilic',
      'Esophagitis',
      'EoE',
      'inflammation of the esophagus',
      'tube that sends food',
      'throat to the stomach',
      'allergy or a sensitivity to particular proteins',
      'family history of allergic disorders',
      'asthma, rhinitis, dermatitis',
      'occur within minutes of eating',
      'sometimes appear a few hours later',
      'Hives or red, itchy skin',
      'Stuffy or itchy nose',
      'sneezing',
      'itchy, teary eyes',
      'Vomiting, stomach cramps',
      'Angioedema or swelling',
      'severe reaction called anaphylaxis',
      'Hoarseness, throat tightness',
      'lump in the throat',
      'Wheezing, chest tightness',
      'trouble breathing',
      'Tingling in the hands, feet, lips',
      'call 911 immediately',
      'Proper diagnosis of food allergies',
      'extremely important',
      'suspected food allergies',
      'caused by other conditions',
      'Skin tests and blood tests',
      'food challenge',
      'allergist / immunologist',
      'confirm an allergy',
      'strictly avoid that food',
      'ingest small quantities',
      'currently no cure',
      'manage your condition',
      'avoiding coming in contact',
      'peanut allergy in children aged 4-17',
      'oral immunotherapy',
      'reduce the incidence and severity',
      'omalizumab',
      'recently been approved',
      'accidental exposure',
      'used in conjunction with food allergen avoidance',
      'Read food labels',
      "don't eat foods that contain",
      'Ask about ingredients',
      'eating at restaurants',
      'foods prepared by family',
      'severe allergies to food',
      'Anaphylaxis Action Plan',
      'carry your epinephrine',
      'anaphylactic reaction',
      'milder reactions',
      'antihistamines may help',
    ];

    for (var keyword in includeKeywords) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  bool shouldFilterOutFoodAllergy(String text) {
    final excludePatterns = [
      'Food Allergy Myths',
      'Episode',
      'Test your knowledge',
      'test your knowledge',
      'Find an allergist',
      'find an allergist',
      'Find an Allergist',
      'Join AAAAI',
      'Subscribe',
      'Learn more',
      'Click here',
      'Read more',
      'Sign up',
      'Cookie',
      'Privacy Policy',
      'Terms of Use',
      'All rights reserved',
      '© ',
      'Copyright',
      'Listen to the podcast',
      'listen to the podcast',
      'discusses new treatments',
      'MD, FAAAAI',
      'trusted resource',
      'specialist close to home',
      '__',
      'podcast',
      'Podcast',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
      '2025)',
      '2024)',
      '2023)',
    ];

    for (var pattern in excludePatterns) {
      if (text.contains(pattern)) return true;
    }

    if (text.length < 50) return true;

    final datePattern = RegExp(r'\d{1,2}/\d{1,2}/\d{4}');
    if (datePattern.hasMatch(text) && text.length < 150) return true;

    return false;
  }

  Future<void> fetchFoodAllergy() async {
    try {
      final url = Uri.parse(
        "https://www.aaaai.org/conditions-treatments/allergies/food-allergy",
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final document = parser.parse(response.body);
      foodHeading =
          document.querySelector("h1")?.text.trim() ??
          document.querySelector("h2")?.text.trim() ??
          "";

      final allElements = document.querySelectorAll("h2, h3, h4, p");
      int nineAllergensSectionIndex = -1;

      for (var i = 0; i < allElements.length; i++) {
        var element = allElements[i];
        String text = element.text.trim();

        if (text.isEmpty || shouldFilterOutFoodAllergy(text)) continue;

        bool isHeading =
            element.localName == 'h2' ||
            element.localName == 'h3' ||
            element.localName == 'h4';

        if (isHeading) {
          if (text.toLowerCase().contains('food protein-induced') ||
              text.toLowerCase().contains('fpies') ||
              text.toLowerCase().contains('eosinophilic') ||
              text.toLowerCase().contains('eoe') ||
              text.toLowerCase().contains('symptoms') ||
              text.toLowerCase().contains('diagnosis') ||
              text.toLowerCase().contains('treatment') ||
              text.toLowerCase().contains('management') ||
              text.toLowerCase().contains('oral allergy')) {
            foodContent.add({'text': text, 'isHeading': true});
          }
        } else {
          if (shouldIncludeFoodAllergy(text)) {
            foodContent.add({'text': text, 'isHeading': false});

            if (text.toLowerCase().contains('nine foods are responsible')) {
              nineAllergensSectionIndex = foodContent.length;
            }
          }
        }
      }

      if (nineAllergensSectionIndex != -1) {
        foodContent.insert(nineAllergensSectionIndex, {
          'text': 'ALLERGENS_LIST_MARKER',
          'isHeading': false,
          'isMarker': true,
        });
      }
    } catch (e) {
      print("Food allergy scrape error: $e");
    }
  }

  Future<void> scrapeAllergens() async {
    final url = Uri.parse(
      "https://www.foodallergy.org/living-food-allergies/food-allergy-essentials/common-allergens",
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final titles = document.querySelectorAll("h3");
        List<Map<String, String>> extracted = [];

        for (var titleElement in titles) {
          final title = titleElement.text.trim();
          var nextElement = titleElement.nextElementSibling;
          String description = "";

          while (nextElement != null && nextElement.localName != "p") {
            nextElement = nextElement.nextElementSibling;
          }

          if (nextElement != null && nextElement.localName == "p") {
            description = nextElement.text.trim();
          }

          extracted.add({"title": title, "description": description});
        }

        allergens = extracted;
      }
    } catch (e) {
      print("Allergen scrape error: $e");
    }
  }

  bool shouldIncludeAnaphylaxis(String text) {
    final includeKeywords = [
      'pronounced an-uh-fil-LAX-is',
      'severe, potentially life-threatening',
      'allergic reaction',
      'Symptoms can affect several areas',
      'breathing and blood circulation',
      'begins within minutes',
      'problem food',
      'symptoms may begin hours later',
      '20 percent of patients',
      'second wave of symptoms',
      'biphasic anaphylaxis',
      'highly likely to be occurring',
      'within minutes to hours',
      'ingestion of the food allergen',
      'involve the skin, nose, mouth',
      'gastrointestinal tract',
      'Difficulty breathing',
      'Reduced blood pressure',
      'pale, weak pulse',
      'confusion, loss of consciousness',
      'exposed to a suspected allergen',
      'Skin symptoms or swollen lips',
      'vomiting, diarrhea, cramping',
      'exposed to a known allergen',
      'leading to weakness or fainting',
    ];

    for (var keyword in includeKeywords) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) return true;
    }

    if (text.length > 80 &&
        (text.toLowerCase().contains('anaphylaxis') ||
            text.toLowerCase().contains('symptom') ||
            text.toLowerCase().contains('allergen') ||
            text.toLowerCase().contains('breathing') ||
            text.toLowerCase().contains('blood pressure'))) {
      return true;
    }

    return false;
  }

  bool shouldFilterOutAnaphylaxis(String text) {
    final excludePatterns = [
      'FARE\'s free course',
      'Food Allergy & Anaphylaxis Emergency Care Plan',
      'Find an allergist',
      'find an allergist',
      'Join',
      'Subscribe',
      'Learn more',
      'Click here',
      'Read more',
      'Sign up',
      'Cookie',
      'Privacy Policy',
      'Terms of Use',
      'All rights reserved',
      '© ',
      'Copyright',
      'Download',
      'Share',
      'Print',
      'Email',
      'Facebook',
      'Twitter',
      'Instagram',
      'LinkedIn',
      'Resources',
      'Contact us',
      'Donate',
      'Support',
      'Newsletter',
      'Follow us',
      '__',
      'podcast',
      'Podcast',
      'webinar',
      'Webinar',
    ];

    for (var pattern in excludePatterns) {
      if (text.contains(pattern)) return true;
    }

    if (text.length < 40) return true;

    final datePattern = RegExp(r'\d{1,2}/\d{1,2}/\d{4}');
    if (datePattern.hasMatch(text) && text.length < 150) return true;

    if (text.length < 100 &&
        (text.contains('Home') ||
            text.contains('About') ||
            text.contains('Menu'))) {
      return true;
    }

    return false;
  }

  Future<void> fetchAnaphylaxis() async {
    try {
      final url = Uri.parse(
        "https://www.foodallergy.org/resources/anaphylaxis",
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final document = parser.parse(response.body);
      anaphylaxisHeading =
          document.querySelector("h1")?.text.trim() ??
          document.querySelector("h2")?.text.trim() ??
          "";

      final allElements = document.querySelectorAll("h2, h3, h4, p, li");

      for (var element in allElements) {
        String text = element.text.trim();

        if (text.isEmpty || shouldFilterOutAnaphylaxis(text)) continue;

        bool isHeading =
            element.localName == 'h2' ||
            element.localName == 'h3' ||
            element.localName == 'h4';

        if (isHeading) {
          if (text.toLowerCase().contains('anaphylaxis') ||
              text.toLowerCase().contains('symptom') ||
              text.toLowerCase().contains('sign') ||
              text.toLowerCase().contains('reaction') ||
              text.toLowerCase().contains('diagnosis') ||
              text.toLowerCase().contains('treatment')) {
            anaphylaxisContent.add({'text': text, 'isHeading': true});
          }
        } else {
          if (shouldIncludeAnaphylaxis(text)) {
            anaphylaxisContent.add({'text': text, 'isHeading': false});
          }
        }
      }
    } catch (e) {
      print("Anaphylaxis scrape error: $e");
    }
  }

  bool shouldIncludeDrugAllergy(String text) {
    final includeKeywords = [
      'Adverse reactions to medications',
      'allergic reaction occurs',
      'immune system overreacts',
      'Sensitivities to drugs',
      'penicillin',
      'Antibiotics',
      'aspirin',
      'ibuprofen',
      'Anticonvulsants',
      'Monoclonal antibody',
      'Chemotherapy',
      'frequently or when it is rubbed',
      'Symptoms Adverse reactions',
      'vomiting and hair loss',
      'upset stomach',
      'diarrhea from antibiotics',
      'ACE',
      'angiotensin converting enzyme',
      'high blood pressure',
      'cough or facial',
      'tongue swelling',
      'difficult to determine',
      'Skin rashes',
      'hives',
      'Itching',
      'Respiratory problems',
      'Swelling, such as',
      'side effects that concern',
      'suspect a drug allergy',
      'anaphylactic reaction',
      'alternative medication',
      'antihistamines',
      'corticosteroids',
      'epinephrine',
      'Standardized allergy testing',
      'oral challenge',
      'desensitization procedure',
      'gradually introducing',
      'therapeutic dose',
      'physician, dentist and pharmacy',
      'drug allergies',
    ];

    for (var keyword in includeKeywords) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) return true;
    }

    if (text.length > 100 &&
        (text.toLowerCase().contains('medication') ||
            text.toLowerCase().contains('drug') ||
            text.toLowerCase().contains('allerg') ||
            text.toLowerCase().contains('reaction'))) {
      return true;
    }

    return false;
  }

  bool shouldFilterOutDrugAllergy(String text) {
    final excludePatterns = [
      'Take our Drug Allergy Quiz',
      'Episode',
      'Test your knowledge',
      'test your knowledge',
      'Find an allergist',
      'find an allergist',
      'Find an Allergist',
      'Join AAAAI',
      'Subscribe',
      'Learn more',
      'Click here',
      'Read more',
      'Sign up',
      'Cookie',
      'Privacy Policy',
      'Terms of Use',
      'All rights reserved',
      '© ',
      'Copyright',
      'Listen to the podcast',
      'listen to the podcast',
      'discusses new treatments',
      'MD, FAAAAI',
      'trusted resource',
      'specialist close to home',
      '__',
      'podcast',
      'Podcast',
      'September',
      '2025)',
      'January',
      'February',
      'March',
      'April',
      'June',
      'July',
      'August',
      'October',
      'November',
      'December',
    ];

    for (var pattern in excludePatterns) {
      if (text.contains(pattern)) return true;
    }

    if (text.length < 50) return true;

    final datePattern = RegExp(r'\d{1,2}/\d{1,2}/\d{4}');
    if (datePattern.hasMatch(text) && text.length < 150) return true;

    return false;
  }

  Future<void> fetchDrugAllergy() async {
    try {
      final url = Uri.parse(
        "https://www.aaaai.org/conditions-treatments/allergies/drug-allergy",
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final document = parser.parse(response.body);
      drugHeading =
          document.querySelector("h1")?.text.trim() ??
          document.querySelector("h2")?.text.trim() ??
          "";

      final allElements = document.querySelectorAll("h2, h3, h4, p");

      for (var element in allElements) {
        String text = element.text.trim();

        if (text.isEmpty || shouldFilterOutDrugAllergy(text)) continue;

        bool isHeading =
            element.localName == 'h2' ||
            element.localName == 'h3' ||
            element.localName == 'h4';

        if (isHeading) {
          if (text.toLowerCase().contains('symptoms') ||
              text.toLowerCase().contains('diagnosis') ||
              text.toLowerCase().contains('treatment') ||
              text.toLowerCase().contains('management') ||
              text.toLowerCase().contains('medication') ||
              text.toLowerCase().contains('drug') ||
              text.toLowerCase().contains('reaction') ||
              text.toLowerCase().contains('allergy')) {
            drugContent.add({'text': text, 'isHeading': true});
          }
        } else {
          if (shouldIncludeDrugAllergy(text)) {
            drugContent.add({'text': text, 'isHeading': false});
          }
        }
      }
    } catch (e) {
      print("Drug allergy scrape error: $e");
    }
  }

  bool shouldIncludeSkinAllergy(String text) {
    final includeKeywords = [
      'Irritated skin can be caused',
      'Atopic Dermatitis',
      'Eczema is the most common',
      'allergic contact dermatitis',
      'Allergic Contact Dermatitis',
      'Urticaria',
      'Hives are an inflammation',
      'Angioedema is swelling',
      'Hereditary angiodema',
      'HAE',
      'immune system',
      'allergen',
      'filaggrin',
      'histamine',
      'poison ivy',
      'nickel allergy',
      'leakiness',
      'skin barrier',
      'welts',
      'soft tissues such as',
      'eyelids, mouth',
      'serious genetic condition',
      'intestinal wall and airways',
      'atopic march',
      'Coming in contact with poison',
      'oily coating covering',
      'small blood vessels to leak',
      'acute and chronic',
      'swelling without itching',
      'Chronic recurrent angioedema',
      'does not respond to typical',
    ];

    for (var keyword in includeKeywords) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) return true;
    }

    if (text.length > 100 &&
        (text.toLowerCase().contains('eczema') ||
            text.toLowerCase().contains('dermatitis') ||
            text.toLowerCase().contains('urticaria') ||
            text.toLowerCase().contains('angioedema') ||
            text.toLowerCase().contains('hives'))) {
      return true;
    }

    return false;
  }

  bool shouldFilterOutSkinAllergy(String text) {
    final excludePatterns = [
      'Episode 145',
      'Test your knowledge',
      'test your knowledge',
      'Find an allergist',
      'find an allergist',
      'Find an Allergist',
      'Join AAAAI',
      'Subscribe',
      'Learn more',
      'Click here',
      'Read more',
      'Sign up',
      'Cookie',
      'Privacy Policy',
      'Terms of Use',
      'All rights reserved',
      '© ',
      'Copyright',
      'Listen to the podcast',
      'listen to the podcast',
      'discusses new treatments',
      'MD, FAAAAI',
      'trusted resource',
      'specialist close to home',
      '__',
      'podcast',
      'Podcast',
      'September',
      '2025)',
    ];

    for (var pattern in excludePatterns) {
      if (text.contains(pattern)) return true;
    }

    if (text.length < 50) return true;

    final datePattern = RegExp(r'\d{1,2}/\d{1,2}/\d{4}');
    if (datePattern.hasMatch(text) && text.length < 150) return true;

    return false;
  }

  Future<void> fetchSkinAllergy() async {
    try {
      final url = Uri.parse(
        "https://www.aaaai.org/conditions-treatments/allergies/skin-allergy",
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final document = parser.parse(response.body);
      skinHeading =
          document.querySelector("h1")?.text.trim() ??
          document.querySelector("h2")?.text.trim() ??
          "";

      final allElements = document.querySelectorAll("h2, h3, h4, p");

      for (var element in allElements) {
        String text = element.text.trim();

        if (text.isEmpty || shouldFilterOutSkinAllergy(text)) continue;

        bool isHeading =
            element.localName == 'h2' ||
            element.localName == 'h3' ||
            element.localName == 'h4';

        if (isHeading) {
          if (text.toLowerCase().contains('atopic dermatitis') ||
              text.toLowerCase().contains('eczema') ||
              text.toLowerCase().contains('contact dermatitis') ||
              text.toLowerCase().contains('urticaria') ||
              text.toLowerCase().contains('hives') ||
              text.toLowerCase().contains('angioedema') ||
              text.toLowerCase().contains('hae') ||
              text.toLowerCase().contains('symptoms') ||
              text.toLowerCase().contains('diagnosis') ||
              text.toLowerCase().contains('treatment') ||
              text.toLowerCase().contains('management')) {
            skinContent.add({'text': text, 'isHeading': true});
          }
        } else {
          if (shouldIncludeSkinAllergy(text)) {
            skinContent.add({'text': text, 'isHeading': false});
          }
        }
      }
    } catch (e) {
      print("Skin allergy scrape error: $e");
    }
  }

  bool shouldIncludeRhinitis(String text) {
    final includeKeywords = [
      'two types of rhinitis',
      'allergic and non-allergic',
      'immune system mistakenly identifies',
      'typically harmless substance',
      'allergen',
      'histamine and chemical mediators',
      'nose, throat, eyes, ears, skin',
      'seasonal allergic rhinitis',
      'hay fever',
      'pollen carried in the air',
      'different times of the year',
      'common indoor allergens',
      'dried skin flakes',
      'pet dander',
      'dust mites',
      'cockroach particles',
      'perennial allergic rhinitis',
      'year-round',
      'irritants such as smoke',
      'strong odors',
      'temperature and humidity',
      'inflammation in the nasal lining',
      'increases sensitivity',
      'allergic conjunctivitis',
      'eye allergy',
      'asthma worse',
      'one out of three people',
      'nonallergic rhinitis',
      'afflicts adults',
      'immune system is not involved',
      'itching in the nose',
      'roof of the mouth',
      'sneezing',
      'stuffy nose',
      'congestion',
      'runny nose',
      'tearing eyes',
      'dark circles under the eyes',
      'flare up in the spring and fall',
      'allergist / immunologist',
      'specialized training',
      'allergy testing',
      'skin tests or blood tests',
      'specific allergens are diagnosed',
      'plan to avoid allergens',
      'reduce these allergens in your house',
      'outdoor allergies such as pollen',
      'limiting outdoor activities',
      'high pollen counts',
      'immunotherapy',
      'allergy shots',
      'long-term relief',
      'sublingual immunotherapy',
      'slit',
      'allergy tablets',
      'under the tongue',
      'daily basis',
      'nasal corticosteroid sprays',
      'antihistamine pills',
      'nasal antihistamine sprays',
      'decongestant pills',
      'ipratropium nasal spray',
      'nasal saline formulations',
      'not be used for more than four days',
      'started before tree pollen',
      'prevent the release of histamine',
      'symptoms are prevented',
    ];

    for (var keyword in includeKeywords) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  bool shouldFilterOutRhinitis(String text) {
    final excludePatterns = [
      'toggle',
      'sub-navigation',
      'aaaai office',
      'practice management',
      'environmentally sustainable',
      'find an allergist',
      'join',
      'subscribe',
      'learn more',
      'click here',
      'read more',
      'sign up',
      'cookie',
      'privacy',
      'terms of use',
      'rights reserved',
      '©',
      'copyright',
      'download',
      'share',
      'print',
      'email',
      'facebook',
      'twitter',
      'instagram',
      'linkedin',
      'resources',
      'contact',
      'donate',
      'support',
      'newsletter',
      'follow',
      'podcast',
      'webinar',
      'drug guide',
      'test your knowledge',
      'national allergy bureau',
      'counting stations',
      'approximately 80',
      'menu',
      'home',
      'about',
      'search',
      'login',
      'register',
      'back to',
      'previous',
      'next',
      'page',
      'sidebar',
      'footer',
      'header',
      'navigation',
      'breadcrumb',
      'current section',
      'articles',
      'quiz',
      'hay fever/ rhinitis',
      'related',
      'more information',
    ];

    String lowerText = text.toLowerCase();

    for (var pattern in excludePatterns) {
      if (lowerText.contains(pattern)) {
        return true;
      }
    }

    if (text.length < 30) return true;

    if (text.length < 100 && text.split(' ').length < 8) {
      return true;
    }

    return false;
  }

  Future<void> fetchRhinitis() async {
    try {
      final url = Uri.parse(
        "https://www.aaaai.org/conditions-treatments/allergies/hay-fever-rhinitis",
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final document = parser.parse(response.body);
      rhinitisHeading =
          document.querySelector("h1")?.text.trim() ??
          "Allergic Rhinitis (Hay Fever)";

      final mainContent =
          document.querySelector("main") ??
          document.querySelector(".content") ??
          document.querySelector("article") ??
          document.body;

      if (mainContent == null) return;

      final allElements = mainContent!.querySelectorAll("h2, h3, h4, p, li");

      for (var element in allElements) {
        String text = element.text.trim();

        if (text.isEmpty || shouldFilterOutRhinitis(text)) continue;

        bool isHeading =
            element.localName == 'h2' ||
            element.localName == 'h3' ||
            element.localName == 'h4';

        if (isHeading) {
          if (text == 'Allergic Rhinitis' ||
              text == 'Nonallergic Rhinitis' ||
              text == 'Symptoms & Diagnosis' ||
              text == 'Symptoms' ||
              text == 'Diagnosis' ||
              text == 'Treatment & Management' ||
              text.toLowerCase().contains('rhinitis') ||
              text.toLowerCase().contains('symptom') ||
              text.toLowerCase().contains('diagnosis') ||
              text.toLowerCase().contains('treatment')) {
            rhinitisContent.add({'text': text, 'isHeading': true});
          }
        } else {
          if (shouldIncludeRhinitis(text)) {
            rhinitisContent.add({'text': text, 'isHeading': false});
          }
        }
      }
    } catch (e) {
      print("Rhinitis scrape error: $e");
    }
  }

  Widget buildSection(
    String heading,
    List<Map<String, dynamic>> content,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  content.map((item) {
                    if (item['isMarker'] == true) {
                      return buildAllergensList();
                    }

                    final isHeading = item['isHeading'] as bool;
                    final text = item['text'] as String;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: isHeading ? 12 : 16,
                        top: isHeading ? 20 : 0,
                      ),
                      child:
                          isHeading
                              ? buildSubheading(text, color)
                              : buildContentText(text),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSubheading(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3748),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildContentText(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF475569),
          height: 1.6,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget buildAllergensList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 16),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                "Common Allergens",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
        ),
        ...allergens.map(
          (allergen) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B9EB3).withOpacity(0.05),
                  const Color(0xFF2B9EB3).withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2B9EB3).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B9EB3).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.medical_information,
                          color: Color(0xFF2B9EB3),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          allergen["title"] ?? "",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B9EB3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    allergen["description"] ?? "",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF475569),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2B9EB3),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF2B9EB3), const Color(0xFF1E7A8C)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 60,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.health_and_safety,
                            color: Colors.white,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Allergen Information",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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

          // Content
          SliverToBoxAdapter(
            child:
                isLoading
                    ? Container(
                      height: MediaQuery.of(context).size.height - 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2B9EB3,
                                    ).withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2B9EB3),
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Loading allergy information...",
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Info Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2B9EB3).withOpacity(0.1),
                                    const Color(0xFF1E7A8C).withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2B9EB3,
                                  ).withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2B9EB3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Educational Purpose",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D3748),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Comprehensive allergy information for better understanding and safety",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Sections
                            if (foodContent.isNotEmpty)
                              buildSection(
                                foodHeading,
                                foodContent,
                                Icons.restaurant,
                                const Color(0xFF2B9EB3),
                              ),
                            if (anaphylaxisContent.isNotEmpty)
                              buildSection(
                                anaphylaxisHeading,
                                anaphylaxisContent,
                                Icons.emergency,
                                const Color(0xFFE53935),
                              ),
                            if (drugContent.isNotEmpty)
                              buildSection(
                                drugHeading,
                                drugContent,
                                Icons.medication,
                                const Color(0xFF8B5CF6),
                              ),
                            if (skinContent.isNotEmpty)
                              buildSection(
                                skinHeading,
                                skinContent,
                                Icons.face,
                                const Color(0xFFF59E0B),
                              ),
                            if (rhinitisContent.isNotEmpty)
                              buildSection(
                                rhinitisHeading,
                                rhinitisContent,
                                Icons.air,
                                const Color(0xFF10B981),
                              ),

                            // Empty State
                            if (foodContent.isEmpty &&
                                anaphylaxisContent.isEmpty &&
                                drugContent.isEmpty &&
                                skinContent.isEmpty &&
                                rhinitisContent.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "No content available",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Please check your internet connection and try again.",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          isLoading = true;
                                        });
                                        fetchAllData();
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text("Retry"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2B9EB3,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
