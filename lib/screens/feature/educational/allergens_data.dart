import 'package:allergen/screens/feature/educational/Informational_Screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

class AllergensData {
  static List<Allergen> getAllergens() {
    return [
      Allergen(
        name: 'Milk',
        description:
            'Cow\'s milk allergy is the most common food allergy in infants and young children. About 2.5 percent of children under three years old are allergic to milk.',
        prevalence: '2.5% of children under 3',
        icon: Icons.local_drink,
        color: AppColors.primary,
        imagePath: 'assets/resources/Milk.jpg',
        detailedInfo:
            'Cow\'s milk allergy is the most common food allergy in infants and young children. Even though most children eventually outgrow their allergy to milk, milk allergy is also among the most common food allergies in adults.\n\n'
            'Approximately 70% of children with cow milk allergy tolerate baked cow milk. Baked milk can be defined as milk that has been extensively heated, which disrupts the structure of the proteins that cause cow milk allergy. Young children who are allergic to fresh milk but can eat baked milk without reacting may be more likely to outgrow their milk allergy at an earlier age than young children who react to baked milk.\n\n'
            'When a person with a milk allergy is exposed to milk, proteins in the milk bind to specific IgE antibodies made by the person\'s immune system. This triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'About 2.5 percent of children under three years old are allergic to milk.',
        symptoms: [
          'Hives or skin rash',
          'Digestive problems',
          'Wheezing',
          'Swelling of lips/throat',
          'Nausea or vomiting',
          'Anaphylaxis (in severe cases)',
        ],
        hiddenSources: [
          'Artificial butter flavor',
          'Baked goods and desserts',
          'Breakfast foods (cereals, pancakes, waffles)',
          'Caramel candies',
          'Chocolate',
          'Luncheon meat, hot dogs and sausages',
          'Margarine',
          'Non-dairy products (many contain casein)',
          'Nougat',
          'Shellfish (sometimes dipped in milk)',
          'Sherbert',
          'Snack foods (chips, crackers, pretzels)',
          'Tuna fish (some brands contain casein)',
          'Specialty beverages (smoothies, lattes)',
          'Grilled steaks (butter added for flavor)',
          'Some medications (psyllium, Advair diskus, Flovent diskus, probiotics)',
        ],
        livingWith: '',
        allergicReactions:
            'Cow milk allergy varies from person to person, and allergic reactions can be unpredictable. Symptoms of a milk allergy reaction can range from mild, such as hives, to severe, such as anaphylaxis.\n\n'
            'If you have a milk allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important that you avoid cow\'s milk and cow\'s milk-containing food products. Always read food labels and ask questions about ingredients before eating a food that you have not prepared yourself.\n\n'
            'If you are allergic to cow\'s milk, your doctor may recommend you also avoid milk from other domestic animals. For example, goat\'s milk protein is very similar to cow\'s milk protein and may cause a reaction in people who have a milk allergy.\n\n'
            'Milk is one of the eight major allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains" statement on the package.\n\n'
            'Avoid foods that contain milk or any of these ingredients:\n'
            '• Butter, butter fat, butter oil, butter acid, butter ester(s)\n'
            '• Buttermilk\n'
            '• Casein and Caseinates (in all forms)\n'
            '• Cheese, Cottage cheese\n'
            '• Cream, Half-and-half\n'
            '• Curds, Custard\n'
            '• Ghee\n'
            '• Lactalbumin, Lactoglobulin\n'
            '• Lactose, Lactulose\n'
            '• Milk (in all forms including condensed, dry, evaporated, goat\'s milk, low-fat, non-fat, powder, whole)\n'
            '• Pudding\n'
            '• Rennet casein\n'
            '• Sour cream, sour cream solids\n'
            '• Whey (in all forms)\n'
            '• Yogurt\n\n'
            'NOTE: Deli meat slicers are often used for both meat and cheese products, leading to cross-contact. Many restaurants put butter on grilled steaks to add extra flavor.',
        outgrow:
            'Most children, up to 75%, eventually outgrow a milk allergy. The allergy is most likely to continue in children who have high levels of cow\'s milk antibodies in their blood.\n\n'
            'Blood tests that measure these antibodies can help your allergist determine whether or not a child is likely to outgrow a milk allergy.\n\n'
            'Ingestion of baked forms of cow milk may help lead to tolerance or resolution of the allergy with time. Be sure to speak to your practitioner about a formal baked milk challenge before trialing at home.',
      ),
 
      Allergen(
        name: 'Egg',
        description:
            'Hen\'s egg allergy is among the most common food allergies in infants and young children, but is less common in older children and adults. Most children eventually outgrow their allergy to egg (71% by 6 years of age).',
        prevalence: '2% of children',
        icon: Icons.egg,
        color: AppColors.primary,
        imagePath: 'assets/resources/Egg.jpg',
        detailedInfo:
            'Hen\'s egg allergy is among the most common food allergies in infants and young children, but is less common in older children and adults. Most children eventually outgrow their allergy to egg (71% by 6 years of age), although some individuals remain allergic to egg throughout their lives.\n\n'
            'When a person with an egg allergy is exposed to egg, proteins in the egg bind to specific IgE antibodies made by the person\'s immune system. This triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'Approximately 70% of children with egg allergy tolerate baked egg. Heating disrupts the protein responsible for egg allergy. The safe and regular ingestion of baked egg foods can lead to tolerance or resolution of egg allergy over time. Speak to your allergist before trialing baked egg products at home.\n\n'
            'Experts estimate that as many as 2 percent of children are allergic to eggs.',
        symptoms: [
          'Skin inflammation',
          'Nasal congestion',
          'Digestive upset',
          'Asthma symptoms',
          'Hives or eczema',
          'Anaphylaxis (rare)',
        ],
        hiddenSources: [
          'Baked goods (although some people can tolerate these)',
          'Breakfast foods (pancakes, waffles)',
          'Breads (may be coated with egg wash)',
          'Cake decorations or fillings (buttercream, frosting, mousse)',
          'Chips and crackers',
          'Egg substitutes',
          'Hollandaise',
          'Ice cream, custard, sorbet',
          'Lecithin',
          'Marzipan',
          'Marshmallows',
          'Nougat',
          'Pasta (most commercially made cooked pastas)',
          'Pretzels (sometimes covered in egg wash)',
          'Salad dressings',
          'Souffle',
          'Specialty coffee drinks and bar drinks (eggs in foam or topping)',
          'Tortillas',
        ],
        livingWith: '',
        allergicReactions:
            'Symptoms of an egg allergy reaction can range from mild, such as hives, to severe, such as anaphylaxis. Allergic reactions can be unpredictable, and even very small amounts of egg can cause one.\n\n'
            'If you have an egg allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important that you avoid eggs and egg products. Always read food labels and ask questions about ingredients before eating a food that you have not prepared yourself.\n\n'
            'The whites of an egg contain the proteins that most commonly cause allergic reactions to egg. If you have an egg allergy, you must avoid eggs completely (both the egg white and the egg yolk). Even if you aren\'t allergic to egg yolk proteins, it is impossible to separate the egg white completely from the yolk. Cross-contact will always be a concern.\n\n'
            'If you are allergic to chicken eggs, your doctor may recommend you also avoid eggs from other domestic animals. Eggs from birds such as ducks, geese, turkeys and quails can cause a cross-reaction.\n\n'
            'Egg is one of the eight major allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains" statement on the package.\n\n'
            'Avoid foods that contain eggs or any of these ingredients:\n'
            '• Albumin (also spelled albumen)\n'
            '• Apovitellin\n'
            '• Avidin globulin\n'
            '• Egg (dried, powdered, solids, white, yolk)\n'
            '• Eggnog\n'
            '• Lysozyme\n'
            '• Mayonnaise\n'
            '• Meringue (meringue powder)\n'
            '• Ovalbumin\n'
            '• Ovomucoid\n'
            '• Ovomucin\n'
            '• Ovovitellin\n'
            '• Surimi\n'
            '• Vitellin\n\n'
            'NOTE: Most commercially made cooked pastas (including those in prepared foods such as soup) contain egg. Boxed, dry pastas are usually egg-free. But these types of pasta may be processed on equipment that is also used for egg-containing products. Fresh pasta is sometimes egg-free, too. Read the label or ask about ingredients before eating any pasta.',
        outgrow:
            'Most children eventually outgrow their allergy to egg (71% by 6 years of age), although some individuals remain allergic to egg throughout their lives.\n\n'
            'Ingestion of baked forms of eggs may help lead to tolerance or resolution of the allergy with time. Be sure to speak to your practitioner about a formal baked egg challenge before trialing at home.',
      ),
      Allergen(
        name: 'Peanut',
        description:
            'Peanut allergy is the most common food allergy in children under age 18 and the third-most common food allergy in adults. Peanut allergy is usually lifelong: only about 20 percent of children with peanut allergy outgrow it over time.',
        prevalence: '2% of pediatric population',
        icon: Icons.circle,
        color: AppColors.primary,
        imagePath: 'assets/resources/peanut.jpg',
        detailedInfo:
            'Peanut allergy is the most common food allergy in children under age 18 and the third-most common food allergy in adults. Peanut allergy is usually lifelong: only about 20 percent of children with peanut allergy outgrow it over time.\n\n'
            'When a person with a peanut allergy is exposed to peanut, proteins in the peanut bind to specific IgE antibodies made by the person\'s immune system. Subsequent exposure to peanut protein, typically by oral ingestion, triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'Allergy to peanut is the only food allergy for which a treatment has been approved by the U.S. Food and Drug Administration – Palforzia. There are other treatment protocols currently being used to improve an individual\'s tolerance to the peanut protein, such as peanut oral immunotherapy, but these are non-FDA approved.\n\n'
            'Peanuts are not the same as tree nuts (such as almonds, cashews, pistachios, walnuts, pecans and more), which grow on trees. Though approximately 40% of children with tree nut allergies have an allergy to peanut. Peanuts grow underground and are part of a different plant family, the legumes. Other examples of legumes include beans, peas, lentils and soybeans. Being allergic to peanuts does not mean you have a greater chance of being allergic to another legume. However, allergy to lupine, another legume commonly used in vegan cooking, can occur in patients with peanut allergy.\n\n'
            'Peanut allergies affect up to 2% of pediatric population, and many will carry this allergy into adulthood.',
        symptoms: [
          'Anaphylaxis',
          'Throat tightness',
          'Difficulty breathing',
          'Rapid pulse',
          'Hives or skin rash',
          'Digestive problems',
          'Drop in blood pressure',
        ],
        hiddenSources: [
          'African, Asian, and Mexican restaurant food',
          'Alternative nut butters (soy nut butter, sunflower seed butter)',
          'Candy (including chocolate candy)',
          'Chili',
          'Egg rolls',
          'Enchilada sauce',
          'Glazes and marinades',
          'Grains (such as Museli cereal)',
          'Granola',
          'Ice creams',
          'Marzipan',
          'Nougat',
          'Pancakes',
          'Pet food',
          'Sauces (chili sauce, hot sauce, pesto, gravy, mole sauce, salad dressing)',
          'Specialty pizzas',
          'Sunflower seeds (often produced on shared equipment)',
          'Sweets (pudding, cookies, baked goods, pies, hot chocolate)',
          'Trail mix',
          'Vegetarian food products (meat substitutes)',
          'Peanut hulls in compost/lawn fertilizer',
        ],
        livingWith: '',
        allergicReactions:
            'Peanuts can cause a severe, potentially life-threatening allergic reaction (anaphylaxis). Allergic reactions can be unpredictable, and even very small amounts of peanut can cause a serious allergic reaction.\n\n'
            'Casual skin contact is less likely to trigger a severe reaction, and can become a problem if the affected area then touches the eyes, nose or mouth. For example, if a child with peanut allergy gets peanut butter on her fingers and rubs her eyes, she can have an allergic reaction.\n\n'
            'If you have a peanut allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important that you avoid peanut and peanut products. Always read food labels to identify peanut ingredients.\n\n'
            'Peanuts and tree nuts often touch one another during manufacturing and serving processes, and may cause an allergic reaction due to cross-contact. Discuss with your allergist whether you need to also avoid tree nuts.\n\n'
            'Peanut is one of the eight major allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains" statement on the package.\n\n'
            'Avoid foods that contain peanuts or any of these ingredients:\n'
            '• Arachis oil (another name for peanut oil)\n'
            '• Artificial nuts\n'
            '• Beer nuts\n'
            '• Cold-pressed, expelled or extruded peanut oil\n'
            '• Ground nuts\n'
            '• Lupin (or lupine) - becoming a common flour substitute in gluten-free food\n'
            '• Mandelonas (peanuts soaked in almond flavoring)\n'
            '• Mixed nuts\n'
            '• Monkey nuts\n'
            '• Nut meat or nut meal\n'
            '• Nut pieces\n'
            '• Peanut butter\n'
            '• Peanut flour\n'
            '• Peanut protein hydrolysate\n\n'
            'NOTE: Highly refined peanut oil is not required to be labeled as an allergen. Studies show that most people with peanut allergy can safely eat this kind of peanut oil. If you are allergic to peanuts, ask your doctor whether you should avoid highly refined peanut oil.\n\n'
            'Everyone with peanut allergy should avoid cold-pressed, expelled or extruded peanut oils—sometimes called gourmet peanut oils. These oils are not highly refined and may contain small amounts of peanut protein.',
        outgrow:
            'Allergy to peanuts appears to be on the rise in children. According to a FARE-funded study, the number of children in the U.S. with peanut allergy more than tripled between 1997 and 2008. Two studies in the United Kingdom and Canada also showed a high prevalence of peanut allergy in school-aged children.\n\n'
            'Peanut allergies tend to be lifelong, although studies show that about 20 percent of children with peanut allergy do eventually outgrow their allergy.\n\n'
            'Younger siblings of children who are allergic to peanuts may be at higher risk for allergy to peanuts. Your doctor can provide guidance on food allergy testing for siblings. Recent research shows that introducing infants to peanuts early on may help prevent them from developing this food allergy.',
      ),
      Allergen(
        name: 'Tree Nuts',
        description:
            'Tree nut allergies are among the most common food allergies in both children and adults. The six tree nut allergies most commonly reported by children and adults are allergies to walnut, almond, hazelnut, pecan, cashew and pistachio.',
        prevalence: 'Over 2% of pediatric population',
        icon: Icons.nature,
        color: AppColors.primary,
        imagePath: 'assets/resources/treenuts.png',
        detailedInfo:
            'Tree nut allergies are among the most common food allergies in both children and adults. The six tree nut allergies most commonly reported by children and adults are allergies to walnut, almond, hazelnut, pecan, cashew and pistachio.\n\n'
            'Approximately 50% of children that are allergic to one tree nut are allergic to another tree nut. Approximately two-thirds of patients reactive to cashew or walnut will react to pistachio or pecan, respectively. Most children who are allergic to one or more tree nuts do not outgrow their tree nut allergy.\n\n'
            'When a person with an allergy to a particular tree nut is exposed to that tree nut, proteins in the nut bind to specific IgE antibodies made by the person\'s immune system. This binding triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'In the U.S., plain-language labeling on packaged foods is required for 12 different tree nuts. These tree nuts are not the same as peanut (only 40% of children with tree nut allergies have an allergy to peanut), which grows underground and is a legume related to beans and peas. Tree nuts are also different from seed allergens such as sesame, sunflower, poppy and mustard, which do not grow on trees.\n\n'
            'Research shows over 2% of the pediatric population is affected by allergies to tree nuts, and many will carry these allergies into adulthood.',
        symptoms: [
          'Severe allergic reactions',
          'Breathing problems',
          'Skin reactions and hives',
          'Gastrointestinal distress',
          'Anaphylaxis',
          'Throat swelling',
        ],
        hiddenSources: [
          'Cereals, crackers, cookies, candy, chocolates',
          'Confections and energy bars',
          'Flavored coffee',
          'Frozen desserts',
          'Marinades and barbeque sauces',
          'Cold cuts (such as mortadella)',
          'Pesto (often includes pine nuts or walnuts)',
          'Ice cream parlors and bakeries',
          'Coffee shops',
          'Chinese, African, Indian, Thai and Vietnamese restaurants',
          'Tree nut oils in lotions, hair care products and soaps',
          'Crushed walnut shells in "natural" sponges or brushes',
          'Alcoholic beverages with nut flavoring',
          'Argan oil (in personal care and cosmetic products)',
          'Pink peppercorn/Brazilian Pepper (risk for cashew allergy)',
        ],
        livingWith: '',
        allergicReactions:
            'Tree nuts can cause a severe and potentially life-threatening allergic reaction (anaphylaxis). Allergic reactions can be unpredictable, and even very small amounts of tree nuts can cause a serious allergic reaction.\n\n'
            'If you have a tree nut allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important that you avoid all tree nuts and tree nut products.\n\n'
            'If you\'re allergic to one type of tree nut, you have a higher chance of being allergic to other types. For this reason, your doctor may recommend you avoid all nuts. You may also be advised to avoid peanuts because of the higher likelihood of cross-contact with tree nuts during manufacturing and processing. These issues should be discussed and further evaluated by your allergist and specific allergy testing may be warranted.\n\n'
            'Tree nuts, as a food category, are one of the nine major food allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains: Tree nuts [species]" statement on the package.\n\n'
            'Avoid foods that contain tree nuts or any of these ingredients:\n'
            '• Almond\n'
            '• Artificial nuts\n'
            '• Beechnut\n'
            '• Black walnut, including hull extract\n'
            '• Brazil nut\n'
            '• Butternut (white walnuts)\n'
            '• California walnut\n'
            '• Cashew\n'
            '• Chestnut\n'
            '• Chinquapin nut\n'
            '• Coconut\n'
            '• Filbert/hazelnut\n'
            '• Gianduja (chocolate-hazelnut spread)\n'
            '• Ginkgo nut\n'
            '• Heart nut (Japanese walnut)\n'
            '• Hickory nut\n'
            '• Litchi/lichee/lychee nut\n'
            '• Macadamia nut (bush nut)\n'
            '• Marzipan/almond paste\n'
            '• Nangai nut\n'
            '• Natural nut extract\n'
            '• Nut butters (cashew butter)\n'
            '• Nut distillates/alcoholic extracts\n'
            '• Nut meal, nut meat\n'
            '• Nut milk (almond milk, cashew milk)\n'
            '• Nut oils (walnut oil, almond oil)\n'
            '• Nut paste, nut pieces\n'
            '• Pecan\n'
            '• Pili nut\n'
            '• Pine nut (pignoli, piñon)\n'
            '• Pistachio\n'
            '• Praline\n'
            '• Shea nut\n'
            '• Walnut (English or Persian)\n\n'
            'NOTE: Ice cream parlors, bakeries, coffee shops and certain restaurants (Chinese, African, Indian, Thai and Vietnamese) are considered high risk for people with tree nut allergy. Even if you order a tree nut-free dish, there is high risk of cross-contact.\n\n'
            'Tree nut oils, which often are not highly refined, are sometimes used in lotions, hair care products and soaps. There are no documented cases of food allergy reactions to shea nut oil or butter.',
        outgrow:
            'An allergy to tree nuts tends to be lifelong. Research shows that about 9 percent of children with a tree nut allergy eventually outgrow their allergy.\n\n'
            'Younger siblings of children who are allergic to tree nuts may be at higher risk for atopic disease. Every case is different and your doctor can provide guidance about food allergy testing for siblings if appropriate.',
      ),
      Allergen(
        name: 'Soy',
        description:
            'Soy allergy is more common in infants and young children than in older children and approximately 0.4% of infants in the U.S. have soy allergy. Most children eventually outgrow their allergy to soy, although some individuals remain allergic to soy throughout their lives.',
        prevalence: '0.4% of infants',
        icon: Icons.eco,
        color: AppColors.primary,
        imagePath: 'assets/resources/Soybeans.jpg',
        detailedInfo:
            'Soy allergy is more common in infants and young children than in older children and approximately 0.4% of infants in the U.S. have soy allergy. Most children eventually outgrow their allergy to soy, although some individuals remain allergic to soy throughout their lives.\n\n'
            'When a person with a soy allergy is exposed to soy, proteins in the soy bind to specific IgE antibodies made by the person\'s immune system. This triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'Soybeans are a member of the legume family. Beans, peas, lentils and peanuts are also legumes. While it is rare for peanut allergic patients to react to soy, the reverse is not true. One study found that up to 88% of soy-allergic patients had peanut allergy or were significantly sensitized to peanut. Individuals with soy allergy were more likely to be allergic or sensitized to major allergens including peanuts, tree nuts, egg, milk and sesame than to non-peanut legumes such as beans, peas and lentils.\n\n'
            'About 0.4 percent of children are allergic to soy.',
        symptoms: [
          'Itching or tingling in mouth',
          'Runny nose or nasal congestion',
          'Skin reactions',
          'Digestive problems',
          'Breathing difficulties',
          'Anaphylaxis (rare)',
        ],
        hiddenSources: [
          'Asian cuisine (Chinese, Indian, Indonesian, Thai, Vietnamese)',
          'Grains prepared with soy (cereals, breads, chips, crackers, pasta, rice, tortillas)',
          'Vegetable gum, vegetable starch, vegetable broth',
          'Baked goods',
          'Canned broths and soups',
          'Canned tuna and meat',
          'Cereals and cookies',
          'Crackers',
          'High-protein energy bars and snacks',
          'Dairy products (ice cream, yogurt)',
          'Infant formulas',
          'Low-fat peanut butter',
          'Medications and personal care products',
          'Pet food',
          'Processed meats and sausages',
          'Sauces',
          'Soaps and moisturizers',
          'Tempeh',
          'Vegan and vegetarian meat alternatives',
        ],
        livingWith: '',
        allergicReactions:
            'Allergic reactions to soy are typically mild, but all reactions can be unpredictable. Although rare, severe and potentially life-threatening reactions can also occur.\n\n'
            'If you have a soy allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important that you avoid soy and soy products. Always read food labels and ask questions about ingredients before eating a food that you have not prepared yourself.\n\n'
            'Soybeans alone are not a common food in American diets, but they are widely used in processed food products. Eliminating all those foods can result in an unbalanced diet. A dietitian can help you plan for proper nutrition.\n\n'
            'Soy is one of the eight major allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains" statement on the package. Note: Soy lecithin, although not exempt from FALCPA, is tolerated in most soy-allergic patients and not typically avoided on a soy-elimination diet.\n\n'
            'Avoid foods that contain soy or any of these ingredients:\n'
            '• Cold-pressed, expelled or extruded soy oil\n'
            '• Edamame\n'
            '• Miso\n'
            '• Natto\n'
            '• Okara\n'
            '• Shoyu\n'
            '• Soy (soy albumin, soy cheese, soy fiber, soy flour, soy grits, soy ice cream, soy milk, soy nuts, soy sprouts, soy yogurt)\n'
            '• Soya\n'
            '• Soybean (curd, granules)\n'
            '• Soy protein (concentrate, hydrolyzed, isolate)\n'
            '• Soy sauce\n'
            '• Tamari\n'
            '• Tempeh\n'
            '• Textured vegetable protein (TVP)\n'
            '• Tofu\n\n'
            'NOTE: Highly refined soy oil is not required to be labeled as an allergen. Studies show that most people with soy allergy can safely eat highly refined soy oil as well as soy lecithin. If you are allergic to soy, ask your doctor whether you need to avoid soy oil or soy lecithin.\n\n'
            'Everyone with soy allergy should avoid cold-pressed, expelled or extruded soy oils—sometimes called gourmet soy oils. These ingredients are not highly refined and may contain small amounts of soy protein.\n\n'
            'With a move toward plant-based diets, many vegan and vegetarian options rely on soy as a meat alternative to achieve similar texture in comparable products. Always check the label!\n\n'
            'IMPORTANT: Asian cuisine (including Chinese, Indian, Indonesian, Thai and Vietnamese)—even if you order a soy-free item, there is high risk of cross-contact.',
        outgrow:
            'Studies show an allergy to soy usually occurs early in childhood and often is outgrown by age three. The majority of children with soy allergy will outgrow the allergy by age 10.',
      ),
      Allergen(
        name: 'Wheat',
        description:
            'Wheat allergy is most often reported in young children and may affect up to 1% of children in the U.S. One study found that two-thirds of children with a wheat allergy outgrow it by age 12.',
        prevalence: 'Up to 1% of children',
        icon: Icons.grass,
        color: AppColors.primary,
        imagePath: 'assets/resources/wheatproducts.jpg',
        detailedInfo:
            'Wheat allergy is most often reported in young children and may affect up to 1% of children in the U.S. One study found that two-thirds of children with a wheat allergy outgrow it by age 12. However, some individuals remain allergic to wheat throughout their lives.\n\n'
            'When a person with a wheat allergy is exposed to wheat, proteins in the wheat bind to specific IgE antibodies made by the person\'s immune system. This binding triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'Wheat allergy and celiac disease are both adverse food reactions, but their underlying causes are very different. Wheat allergy results from an adverse immunologic (IgE-mediated) reaction to proteins in wheat and reactions can cause typical allergy symptoms involving the skin, gastrointestinal tract, respiratory system, and anaphylaxis in some individuals.\n\n'
            'Celiac disease is an autoimmune disease. Antibodies are produced in response to the presence of gluten resulting in inflammation and damage to the lining of the small intestine. Many symptoms involve the gastrointestinal tract (e.g., diarrhea, constipation, weight loss, abdominal pain and bloating). Other symptoms can include skin rashes and disorders that result from nutrient deficiencies. The estimated global prevalence of celiac disease is 1%, similar to wheat allergy.\n\n'
            'It\'s important to work with your physician to determine an accurate diagnosis to prevent short- and long-term complications.',
        symptoms: [
          'Hives or skin rash',
          'Difficulty breathing',
          'Digestive upset',
          'Nasal congestion',
          'Headache',
          'Anaphylaxis (rare)',
        ],
        hiddenSources: [
          'Glucose syrup',
          'Soy sauce',
          'Starch (gelatinized starch, modified starch, modified food starch, vegetable starch)',
          'Surimi',
          'Plant-based meat alternatives',
          'Ale and beer',
          'Asian dishes (wheat flour shaped to look like meat)',
          'Baked goods and baking mixes',
          'Batter-fried foods and breaded foods',
          'Breakfast cereals',
          'Candy and crackers',
          'Country-style wreaths (decorated with wheat)',
          'Hot dogs',
          'Imitation crab meat',
          'Ice cream',
          'Marinara sauce',
          'Personal care items (cosmetics, hair products)',
          'Play dough or modeling clay',
          'Potato chips',
          'Processed meats and sausages',
          'Rice cakes',
          'Salad dressings and sauces',
          'Spices and soups',
          'Turkey patties',
        ],
        livingWith: '',
        allergicReactions:
            'Symptoms of a wheat allergy reaction can range from mild, such as hives, to severe, such as anaphylaxis. Allergic reactions can be unpredictable, and even very small amounts of wheat can cause one.\n\n'
            'If you have a wheat allergy, keep an epinephrine delivery device you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important that you avoid wheat and wheat-containing foods. Always read food labels and ask questions about ingredients before eating a food that you have not prepared yourself.\n\n'
            'Wheat is the most common grain product in the United States. Patients with wheat allergy rarely are allergic to other common grains except in some cases, barley. You can still eat a wide variety of foods, but the grain source must be something other than wheat. Look for other grains such as amaranth, barley, corn, oat, quinoa, rice, rye and tapioca.\n\n'
            'A combination of wheat-free flours usually works best for baking. Experiment with different blends to find one that will give you the texture you desire.\n\n'
            'Wheat is one of the eight major allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains" statement on the package.\n\n'
            'Avoid foods that contain wheat or any of these ingredients:\n'
            '• Bread crumbs\n'
            '• Bulgur\n'
            '• Cereal extract\n'
            '• Club wheat\n'
            '• Couscous\n'
            '• Cracker meal\n'
            '• Durum\n'
            '• Einkorn, Emmer\n'
            '• Farina, Farro\n'
            '• Flour (all-purpose, bread, cake, durum, enriched, graham, high-gluten, high-protein, instant, pastry, self-rising, soft wheat, steel ground, stone ground, whole wheat)\n'
            '• Freekeh\n'
            '• Hydrolyzed wheat protein\n'
            '• Kamut\n'
            '• Matzoh, matzoh meal\n'
            '• Pasta\n'
            '• Seitan\n'
            '• Semolina\n'
            '• Spelt\n'
            '• Sprouted wheat\n'
            '• Triticale\n'
            '• Vital wheat gluten\n'
            '• Wheat (bran, durum, germ, gluten, grass, malt, sprouts, starch)\n'
            '• Wheat bran hydrolysate\n'
            '• Wheat germ oil\n'
            '• Wheat grass\n'
            '• Wheat protein isolate\n'
            '• Whole wheat berries\n\n'
            'NOTE: Buckwheat is not related to wheat and is considered safe to eat.',
        outgrow:
            'One study found that two-thirds of children with a wheat allergy outgrow it by age 12. However, some individuals remain allergic to wheat throughout their lives.',
      ),
      Allergen(
        name: 'Fish',
        description:
            'Finned fish is one of the most common food allergies with a prevalence of 1% in the U.S. population. In one study, salmon, tuna, catfish and cod were the fish to which people most commonly reported allergic reactions.',
        prevalence: '1% of U.S. population',
        icon: Icons.set_meal,
        color: AppColors.primary,
        imagePath: 'assets/resources/fish.jpg',
        detailedInfo:
            'Finned fish is one of the most common food allergies with a prevalence of 1% in the U.S. population. In one study, salmon, tuna, catfish and cod were the fish to which people most commonly reported allergic reactions.\n\n'
            'When a person with an allergy to a particular fish is exposed to that fish, proteins in the fish bind to specific IgE antibodies made by the person\'s immune system. This triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'Finned fish and shellfish are not closely related. Being allergic to one does not always mean that you must avoid both, though care is needed to prevent cross-contact between fish and shellfish. Discuss this issue in detail with your allergist to make sure the appropriate food restrictions are implemented.\n\n'
            'About 40 percent of people with fish allergy experience their first allergic reaction as adults.',
        symptoms: [
          'Hives or skin rash',
          'Vomiting or diarrhea',
          'Breathing difficulties',
          'Anaphylaxis',
          'Throat swelling',
          'Drop in blood pressure',
        ],
        hiddenSources: [
          'Barbecue sauce',
          'Bouillabaisse',
          'Caesar salad and Caesar dressing',
          'Caponata (Sicilian eggplant relish)',
          'Imitation or artificial fish/shellfish (surimi, "sea legs", "sea sticks")',
          'Worcestershire sauce',
          'African cuisine',
          'Chinese cuisine',
          'Indonesian cuisine',
          'Thai cuisine',
          'Vietnamese cuisine',
          'Kimchi made with fish sauce',
          'Fish flavoring',
          'Fish gelatin (from skin and bones)',
          'Fish oil',
          'Fish sticks',
        ],
        livingWith: '',
        allergicReactions:
            'Finned fish can cause severe and potentially life-threatening allergic reactions (such as anaphylaxis). Allergic reactions can be unpredictable, and even very small amounts of fish can cause one.\n\n'
            'If you have a fish allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important to avoid all fish and fish products. Always read food labels and ask questions about ingredients before eating a food that you have not prepared yourself.\n\n'
            'Steer clear of seafood restaurants, where there is a high risk of food cross-contact. You should also avoid touching fish and going to fish markets. Being in any area where fish are being cooked can put you at risk, as fish protein could be in the steam.\n\n'
            'More than half of people who are allergic to one type of fish are also allergic to other fish. Your allergist will usually recommend you avoid all fish. If you are allergic to a specific type of fish but want to eat other fish, talk to your doctor about further allergy testing and recommendations.\n\n'
            'Finned fish is one of the eight major allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains" statement on the package.\n\n'
            'There are more than 20,000 species of fish. Although this is not a complete list, allergic reactions have been commonly reported to:\n'
            '• Anchovies\n'
            '• Bass\n'
            '• Catfish\n'
            '• Cod\n'
            '• Flounder\n'
            '• Grouper\n'
            '• Haddock\n'
            '• Hake\n'
            '• Halibut\n'
            '• Herring\n'
            '• Mahi mahi\n'
            '• Perch\n'
            '• Pike\n'
            '• Pollock\n'
            '• Salmon\n'
            '• Scrod\n'
            '• Sole\n'
            '• Snapper\n'
            '• Swordfish\n'
            '• Tilapia\n'
            '• Trout\n'
            '• Tuna\n\n'
            'Also avoid these fish products:\n'
            '• Fish Flavoring\n'
            '• Fish gelatin (made from skin and bones of fish)\n'
            '• Fish oil\n'
            '• Fish sticks\n\n'
            'IMPORTANT: Certain multicultural cuisines (especially African, Chinese, Indonesian, Thai and Vietnamese) contain many hidden sources of fish and—even if you order a fish-free dish, there is high risk of cross-contact.\n\n'
            'NOTE: Carrageenan, or "Irish moss," is not fish. It is a red marine algae used in many foods. It is safe for most people with food allergies. Fish allergy is sometimes confused with iodine allergy because fish contains iodine. But iodine is not what triggers the reaction. If you have a fish allergy, you do not need to worry about cross-reactions with iodine or radiocontrast material.',
        outgrow:
            'Fish allergy is typically lifelong. About 40 percent of people with fish allergy experience their first allergic reaction as adults, and the allergy tends to persist throughout life.',
      ),
      Allergen(
        name: 'Shellfish',
        description:
            'Shellfish allergies are the most common food allergies in adults and among the most common food allergies in children. Approximately 2% of the U.S. population reports an allergy to shellfish. Shellfish allergies are usually lifelong.',
        prevalence: '2% of U.S. population',
        icon: Icons.water,
        color: AppColors.primary,
        imagePath: 'assets/resources/lobsters.jpg',
        detailedInfo:
            'Shellfish allergies are the most common food allergies in adults and among the most common food allergies in children. Approximately 2% of the U.S. population reports an allergy to shellfish. Shellfish allergies are usually lifelong.\n\n'
            'When a person with an allergy to a particular shellfish is exposed to that shellfish, proteins in the shellfish bind to specific IgE antibodies made by the person\'s immune system. This triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'There are two groups of shellfish: crustaceans (such as shrimp, prawns, crab and lobster) and mollusks/bivalves (such as clams, mussels, oysters, scallops, octopus, squid, abalone, snail). Allergy to crustaceans is more common than allergy to mollusks, with shrimp being the most common shellfish allergen for both children and adults.\n\n'
            'Finned fish and shellfish are not closely related. Being allergic to one does not always mean that you must avoid both, though care is needed to prevent cross-contact between fish and shellfish. Discuss this issue in detail with your allergist to make sure the appropriate food restrictions are implemented.\n\n'
            'About 60 percent of people with shellfish allergy experience their first allergic reaction as adults.',
        symptoms: [
          'Anaphylaxis',
          'Hives or eczema',
          'Indigestion or vomiting',
          'Respiratory issues',
          'Swelling of lips, face, or throat',
          'Dizziness or fainting',
        ],
        hiddenSources: [
          'Bouillabaisse',
          'Cuttlefish ink',
          'Glucosamine',
          'Fish stock',
          'Seafood flavoring (crab or clam extract)',
          'Fish sauce (sometimes made from krill)',
          'Surimi (imitation crab)',
        ],
        livingWith: '',
        allergicReactions:
            'Shellfish can cause severe and potentially life-threatening allergic reactions (such as anaphylaxis). Allergic reactions can be unpredictable, and even very small amounts of shellfish can cause one.\n\n'
            'If you have a shellfish allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important to avoid all shellfish and shellfish products. Always read food labels and ask questions about ingredients before eating a food that you have not prepared yourself.\n\n'
            'Most people who are allergic to one group of shellfish are allergic to other types. Your allergist will usually recommend you avoid all kinds of shellfish. If you are allergic to a specific type of shellfish but want to eat other shellfish, talk to your doctor about further allergy testing.\n\n'
            'Steer clear of seafood restaurants, where there is a high risk of food cross-contact. You should also avoid touching shellfish and going to fish markets. Being in any area where shellfish are being cooked can put you at risk, as shellfish protein could be in the steam.\n\n'
            'Crustacean shellfish are one of the eight major allergens that must be listed in plain language on packaged foods sold in the U.S., as required by federal law, either within the ingredient list or in a separate "Contains" statement on the package. For crustacean shellfish, the specific variety must also be identified on the package such as crab or shrimp.\n\n'
            'IMPORTANT: Mollusks are not required to be labeled in the U.S. at this time and may be present in a food item unexpectedly.\n\n'
            'Avoid foods that contain shellfish or any of these ingredients:\n'
            '• Barnacle\n'
            '• Crab\n'
            '• Crawfish (crawdad, crayfish, ecrevisse)\n'
            '• Krill\n'
            '• Lobster (langouste, langoustine, Moreton bay bugs, scampi, tomalley)\n'
            '• Prawns\n'
            '• Shrimp (crevette, scampi)\n\n'
            'Your doctor may advise you to avoid mollusks or these ingredients:\n'
            '• Abalone\n'
            '• Clams (cherrystone, geoduck, littleneck, pismo, quahog)\n'
            '• Cockle\n'
            '• Cuttlefish\n'
            '• Limpet (lapas, opihi)\n'
            '• Mussels\n'
            '• Octopus\n'
            '• Oysters\n'
            '• Periwinkle\n'
            '• Sea cucumber\n'
            '• Sea urchin\n'
            '• Scallops\n'
            '• Snails (escargot)\n'
            '• Squid (calamari)\n'
            '• Whelk (Turban shell)\n\n'
            'NOTE: Carrageenan, or "Irish moss," is not shellfish. It is a red marine algae used in many foods. It is safe for most people with food allergies. Shellfish allergy is sometimes confused with iodine allergy because shellfish contains iodine. But iodine is not what triggers the reaction. The major allergen in shellfish is a muscle protein called tropomyosin. If you have a shellfish allergy, you do not need to worry about cross-reactions with iodine or radiocontrast material.',
        outgrow:
            'Shellfish allergies are usually lifelong. About 60 percent of people with shellfish allergy experience their first allergic reaction as adults, and the allergy tends to persist throughout life.',
      ),
      Allergen(
        name: 'Sesame',
        description:
            'Sesame is the ninth most common food allergy among children and adults in the U.S. Several reports suggest this allergy has increased significantly worldwide over the past two decades.',
        prevalence: '0.23% of U.S. children and adults',
        icon: Icons.grain,
        color: AppColors.primary,
        imagePath: 'assets/resources/sesame seeds.jpg',
        detailedInfo:
            'Sesame is the ninth most common food allergy among children and adults in the U.S. The edible seeds of the sesame plant are a common ingredient in cuisines around the world, from baked goods to sushi. Several reports suggest this allergy has increased significantly worldwide over the past two decades.\n\n'
            'When a person with an allergy to sesame is exposed to sesame, proteins in the sesame bind to specific IgE antibodies made by the person\'s immune system. This triggers the person\'s immune defenses, leading to reaction symptoms that can be mild or very severe.\n\n'
            'On January 1, 2023, sesame became the ninth major allergen that must be labeled in plain language on packaged foods in the U.S. Products manufactured prior to 2023 may still contain unlabeled sesame and will remain on store shelves until replaced by new inventory.\n\n'
            'Approximately 0.23% of US children and adults are allergic to sesame.',
        symptoms: [
          'Anaphylaxis',
          'Skin rash or hives',
          'Digestive issues',
          'Respiratory problems',
          'Throat swelling',
          'Itching or tingling',
        ],
        hiddenSources: [
          'Asian cuisine (sesame oil commonly used)',
          'Baked goods (bagels, bread, breadsticks, hamburger buns, rolls)',
          'Bread crumbs',
          'Cereals (granola and muesli)',
          'Chips (bagel chips, pita chips, tortilla chips)',
          'Crackers (melba toast, sesame snap bars)',
          'Dipping sauces (baba ghanoush, hummus, tahini sauce)',
          'Dressings, gravies, marinades and sauces',
          'Falafel',
          'Flavored rice, noodles, risotto, shish kebabs, stews, stir fry',
          'Goma-dofu (Japanese dessert)',
          'Herbs and herbal drinks',
          'Margarine',
          'Pasteli (Greek dessert)',
          'Processed meats and sausages',
          'Protein and energy bars',
          'Snack foods (pretzels, candy, Halvah, Japanese snack mix, rice cakes)',
          'Soups',
          'Sushi',
          'Tempeh',
          'Turkish cake',
          'Vegetarian burgers',
          'Cosmetics (hair care, soaps, body oils, creams)',
          'Medications',
          'Nutritional supplements',
          'Perfumes',
          'Pet foods',
          'Spice blends and flavorings (in pre-2023 products)',
        ],
        livingWith: '',
        allergicReactions:
            'Sensitivity to sesame varies from person to person, and reactions can be unpredictable. Symptoms of a sesame allergy reaction can range from mild, such as hives, to severe, such as anaphylaxis.\n\n'
            'If you have a sesame allergy, keep an epinephrine delivery device with you at all times. Epinephrine is the first-line treatment for anaphylaxis.',
        avoidance:
            'To prevent a reaction, it is very important to avoid sesame. Sesame ingredients can be listed by many uncommon names. Always read food labels and ask questions about ingredients before eating a food that you have not prepared yourself.\n\n'
            'Avoid foods that contain sesame or any of these ingredients:\n'
            '• Benne, benne seed, benniseed\n'
            '• Gingelly, gingelly oil\n'
            '• Gomasio (sesame salt)\n'
            '• Halvah\n'
            '• Sesame flour\n'
            '• Sesame oil\n'
            '• Sesame paste\n'
            '• Sesame salt\n'
            '• Sesame seed\n'
            '• Sesamol\n'
            '• Sesamum indicum\n'
            '• Sesemolina\n'
            '• Sim sim\n'
            '• Tahini, Tahina, Tehina\n'
            '• Til\n\n'
            'IMPORTANT: Studies show that most people with specific food protein allergies can safely eat highly refined oils made from those foods (examples include highly refined peanut and soybean oil). However, sesame oil is not highly refined and should be avoided by people who are allergic to sesame.\n\n'
            'In packaged foods manufactured prior to January 1, 2023, sesame may appear undeclared in ingredients such as flavors or spice blends. If you are unsure whether a product could contain sesame, call the manufacturer to ask about their ingredients and manufacturing practices.\n\n'
            'Spice blend and flavoring recipes are considered proprietary information. The manufacturer may not be able to share the entire ingredient list. Instead, ask if sesame is specifically used as an ingredient.\n\n'
            'NOTE: In non-food items, the scientific name for sesame, Sesamum indicum, may be on the label. Check cosmetics (hair care products, soaps, body oils, creams), medications, nutritional supplements, perfumes, and pet foods.',
        outgrow:
            'Limited research suggests that sesame allergy is usually lifelong, similar to tree nut and peanut allergies. More research is needed to understand the natural history of sesame allergy in children and adults.',
      ),
    ];
  }
}
