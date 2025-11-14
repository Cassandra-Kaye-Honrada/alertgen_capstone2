import 'package:allergen/screens/feature/educational/Informational_Screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

class ResourcesData {
  static List<ResourceLink> getResources() {
    return [
      ResourceLink(
        title: 'Food Allergy Information',
        description: 'Comprehensive guide to food allergies and management',
        url:
            'https://www.aaaai.org/conditions-treatments/allergies/food-allergy',
        icon: Icons.food_bank,
        color: AppColors.primary,
        category: 'Educational',
        detailedContent: '''
# Food Allergy Overview
If you have a food allergy, your immune system overreacts to a particular protein found in that food. Symptoms can occur when coming in contact with just a tiny amount of the food.

Many food allergies are first diagnosed in young children, though they may also appear in older children and adults.

## Common Food Allergens
Nine foods are responsible for the majority of allergic reactions:
- Cow’s milk
- Eggs
- Fish
- Peanuts
- Sesame
- Shellfish
- Soy
- Tree nuts
- Wheat

Many people who think they are allergic to a food may actually be intolerant to it. Some of the symptoms of food intolerance and food allergy are similar, but the differences between the two are very important. If you are allergic to a food, this allergen triggers a response in the immune system. Food allergy reactions can be life-threatening, so people with this type of allergy must be very careful to avoid their food triggers.

Being allergic to a food may also result in being allergic to a similar protein found in something else. For example, if you are allergic to ragweed, you may also develop reactions to bananas or melons. This is known as cross-reactivity. Cross-reactivity happens when the immune system thinks one protein is closely related to another. When foods are involved it is called oral allergy syndrome (OAS).

Food allergy can strike children and adults alike. While many children outgrow a food allergy, it is also possible for adults to develop allergies to particular foods.

## Food Protein-Induced Enterocolitis Syndrome (FPIES)
FPIES, sometimes referred to as a delayed food allergy, is a severe condition causing vomiting and diarrhea. In some cases, symptoms can progress to dehydration and shock brought on by low blood pressure and poor blood circulation.

Much like other food allergies, FPIES reactions are triggered by ingesting a food allergen. Although any food can be a trigger, the most common culprits include milk, soy, and grains. FPIES often develops in infancy, usually when a baby is introduced to solid food or formula, but may also occur in adults.

## Eosinophilic Esophagitis (EoE)
EoE is an allergic condition causing inflammation of the esophagus, the tube that sends food from the throat to the stomach. Most research suggests that the leading cause of EoE is an allergy or a sensitivity to particular proteins found in foods. Many people with EoE have a family history of allergic disorders such as asthma, rhinitis, dermatitis, or food allergy.
''',
        imagePaths: [
          'assets/resources/r1_1.png',
          'assets/resources/r1_2.png',
          'assets/resources/r1_3.png',
        ],
      ),
      ResourceLink(
        title: 'Common Allergens',
        description: 'Learn about the most common food allergens',
        url:
            'https://www.foodallergy.org/living-food-allergies/food-allergy-essentials/common-allergens',
        icon: Icons.warning_amber_rounded,
        color: AppColors.primaryColor3,
        category: 'Reference',
        imagePaths: [
          'assets/resources/r2_1.png',
          'assets/resources/Milk.jpg',
          'assets/resources/Egg.jpg',
          'assets/resources/peanut.jpg',
          'assets/resources/Soybeans.jpg',
          'assets/resources/wheatproducts.jpg',
          'assets/resources/treenuts.png',
          'assets/resources/lobsters.jpg',
          'assets/resources/fish.jpg',
          'assets/resources/sesame seeds.jpg',
        ],
        detailedContent: '''
# Food Allergy Essentials

## Common Allergens
Although nearly any food can trigger an allergic reaction, there are nine foods that cause the majority of reactions.

### Milk
Milk allergy is the most common food allergy in infants and young children. About 2.5 percent of children under age 3 are allergic to milk, and most of these children develop milk allergy in their first year of life.

### Eggs
Egg allergy is among the most common food allergies in children, but most children who are allergic to egg eventually outgrow their allergy. Most allergenic egg proteins are found in the egg white, but individuals with egg allergy should avoid both egg whites and egg yolks.

### Peanuts
Peanut allergy is one of the most common food allergies. Peanuts are not the same as tree nuts (almonds, cashews, walnuts, etc.), which grow on trees. Peanuts grow underground and are part of the legume family. Other legumes include beans, peas, lentils, and soybeans. Being allergic to peanuts does not mean you have a greater chance of being allergic to another legume.

### Soy
Soybean allergy is common, especially in babies and children. Soybeans are a member of the legume family. Being allergic to soy does not mean you have a greater chance of being allergic to another legume, including peanuts.

### Wheat
Wheat allergy is most common in children and is usually outgrown before adulthood. Two-thirds of children with a wheat allergy outgrow it by age 12. An allergy to wheat is not the same as celiac disease.

### Tree Nuts
Tree nut allergy is one of the most common food allergies in children and adults. Tree nuts include walnut, almond, hazelnut, cashew, pistachio, and Brazil nuts. They are not the same as peanuts (legumes) or seeds (e.g., sunflower, sesame).

### Shellfish
Shellfish allergy usually is lifelong. About 60 percent of people with shellfish allergy experience their first reaction as adults. There are two groups of shellfish:
- Crustacea (shrimp, crab, lobster) – cause most reactions and tend to be severe
- Mollusks (clams, mussels, oysters, scallops)  
Finned fish and shellfish are not related. Being allergic to one does not always mean you must avoid both.

### Fish
Finned fish allergy usually is lifelong. About 40 percent of people with fish allergy experience their first reaction as adults. Common allergens include salmon, tuna, and halibut. Finned fish and shellfish are not related. Being allergic to one does not always mean you must avoid both.

### Sesame
Sesame is a flowering plant that produces edible seeds. It is a common ingredient worldwide, from baked goods to sushi. Reports suggest this allergy has increased significantly over the past two decades. On January 1, 2023, sesame became the ninth major allergen that must be labeled in plain language on packaged foods in the U.S. Products manufactured prior to 2023 may still contain unlabeled sesame and remain on store shelves until replaced.
''',
      ),
      ResourceLink(
        title: 'Anaphylaxis Guide',
        description: 'Emergency information and treatment protocols',
        url: 'https://www.foodallergy.org/resources/anaphylaxis',
        icon: Icons.emergency,
        color: AppColors.primary,
        category: 'Emergency',
        imagePaths: ['assets/resources/Emergency Room Sign.jpg'],
        detailedContent: '''
# Anaphylaxis (pronounced an-uh-fil-LAX-is)
Anaphylaxis is a severe, potentially life-threatening allergic reaction. Symptoms can affect several areas of the body, including breathing and blood circulation.

## Emergency Room Sign
Anaphylaxis often begins within minutes after a person eats a problem food. Less commonly, symptoms may begin hours later. Up to 20 percent of patients have a second wave of symptoms hours or even days after their initial symptoms have subsided. This is called biphasic anaphylaxis.

## High Likelihood Indicators
Anaphylaxis is highly likely when any one of the following happens within minutes to hours after ingestion of the food allergen:

- A person has symptoms that involve the skin, nose, mouth, or gastrointestinal tract and either:
  - Difficulty breathing, or
  - Reduced blood pressure (e.g., pale, weak pulse, confusion, loss of consciousness)

- A person was exposed to a suspected allergen, and two or more of the following occur:
  - Skin symptoms or swollen lips
  - Difficulty breathing
  - Reduced blood pressure
  - Gastrointestinal symptoms (e.g., vomiting, diarrhea, cramping)

- A person was exposed to a known allergen, and experiences:
  - Reduced blood pressure, leading to weakness or fainting
''',
      ),
      ResourceLink(
        title: 'Drug Allergies',
        description:
            'Adverse reactions to medications are common, yet everyone responds differently. One person may develop a rash or other reactions when taking a certain medication, while another person on the same drug may have no adverse reaction at all.',
        url:
            'https://www.aaaai.org/conditions-treatments/allergies/drug-allergy',
        icon: Icons.favorite,
        color: AppColors.primaryColor3,
        category: 'Lifestyle',
        imagePaths: ['assets/resources/r3_1.jpg', 'assets/resources/r3_2.jpg'],
        detailedContent: '''

#Only about 5% to 10% of these reactions are due to an allergy to the medication.

An allergic reaction occurs when the immune system overreacts to a harmless substance, in this case a medication, which triggers an allergic reaction. Sensitivities to drugs may produce similar symptoms, but do not involve the immune system.

# Common Drug Allergens
Certain medications are more likely to produce allergic reactions than others. The most common are:
- Antibiotics, such as penicillin
- Aspirin and non-steroidal anti-inflammatory medications, such as ibuprofen
- Anticonvulsants
- Monoclonal antibody therapy
- Chemotherapy

The chances of developing an allergy are higher when you take the medication frequently or when it is rubbed on the skin or given by injection, rather than taken by mouth.
''',
      ),
      ResourceLink(
        title: 'Skin Allergy',
        description:
            'Irritated skin can be caused by a variety of factors. These include immune system disorders, medications, and infections. When an allergen triggers an immune system response in the skin, it results in an allergic skin condition.',
        url:
            'https://www.aaaai.org/conditions-treatments/allergies/skin-allergy',
        icon: Icons.child_care,
        color: AppColors.primary,
        category: 'Pediatric',
        imagePaths: ['assets/resources/r4_1.jpg', 'assets/resources/r4_2.jpg'],
        detailedContent: '''

## Atopic Dermatitis (Eczema)
Eczema is the most common skin condition, especially in children. It affects one in five infants but only 10% of adults. One explanation for eczema is thought to be due to “leakiness” of the skin barrier, causing it to dry out and become prone to irritation and inflammation by environmental factors. Some young children with eczema may flare with a particular food.  

In about half of patients with severe atopic dermatitis, the disease is due to inheritance of a faulty gene called filaggrin, although this is affected by race and ethnicity. Unlike urticaria (hives), histamine is not the only cause of eczema itch, so antihistamines may not fully control symptoms. Eczema is often linked with asthma, allergic rhinitis (hay fever), or food allergy; this progression is called the atopic march.

## Allergic Contact Dermatitis
Allergic contact dermatitis occurs when your skin comes in direct contact with an allergen. For example, nickel allergy can cause red, bumpy, scaly, itchy, or swollen skin at the point of contact.  

Contact with poison ivy, poison oak, or poison sumac can also cause allergic contact dermatitis. The rash is caused by the oily coating of these plants and can result from touching the plant directly or indirectly via clothing, pets, or gardening tools.

## Urticaria (Hives)
Hives are an inflammation of the skin triggered when the immune system releases histamine, causing small blood vessels to leak, leading to swelling and itching. Swelling without itching in deep layers is called angioedema.  

- Acute urticaria: Occurs after eating a particular food or coming in contact with a trigger. Can also be triggered by heat, exercise, medications, foods, insect bites, or infections.  
- Chronic urticaria: Rarely caused by specific triggers; allergy tests usually are not helpful. Chronic urticaria can last for months or years. Though uncomfortable, hives are not contagious.

## Angioedema
Angioedema is swelling without itching in deep layers of the skin. It often occurs with urticaria (hives) and affects soft tissues such as eyelids, mouth, or genitals.  

- Acute angioedema: Lasts minutes to hours, commonly caused by allergic reactions to medications or foods.  
- Chronic recurrent angioedema: Returns over a long period, with episodes lasting hours to several days. Most cases do not have an identifiable cause.

## Hereditary Angioedema (HAE)
Hereditary angioedema (HAE) is a rare genetic condition causing swelling in hands, feet, face, intestinal wall, and airways. HAE does not respond to typical angioedema treatments like antihistamines or adrenaline, so specialist evaluation is important.

Skin conditions are among the most common allergies treated and managed by an allergist/immunologist, a physician specialized in diagnosing and providing relief for allergic skin conditions.
''',
      ),

      ResourceLink(
        title: 'Hay Fever / Rhinitis',
        description:
            'There are two types of rhinitis: allergic and non-allergic.',
        url:
            'https://www.aaaai.org/conditions-treatments/allergies/hay-fever-rhinitis',
        icon: Icons.cleaning_services,
        color: AppColors.primary,
        category: 'Safety',
        imagePaths: [
          'assets/resources/Rhinitis1.jpg',
          'assets/resources/Rhinitis2.jpg',
        ],
        detailedContent: '''
## Allergic Rhinitis
If you have allergic rhinitis, your immune system mistakenly identifies a typically harmless substance as an intruder. This substance is called an allergen. The immune system responds to the allergen by releasing histamine and chemical mediators, which typically cause symptoms in the nose, throat, eyes, ears, skin, and roof of the mouth.

Seasonal allergic rhinitis (hay fever) is most often caused by pollen carried in the air during different times of the year.

Allergic rhinitis can also be triggered by common indoor allergens such as:
- Dried skin flakes, urine, and saliva from pet dander
- Mold
- Droppings from dust mites
- Cockroach particles  

This is called perennial allergic rhinitis, as symptoms typically occur year-round.

Symptoms may also be triggered by irritants such as smoke, strong odors, or changes in air temperature and humidity, due to inflammation of the nasal lining.

Many people with allergic rhinitis are prone to allergic conjunctivitis (eye allergy). Allergic rhinitis can also worsen asthma symptoms in people who suffer from both conditions.

## Nonallergic Rhinitis
At least one out of three people with rhinitis symptoms do not have allergies. Nonallergic rhinitis usually affects adults and causes year-round symptoms, especially runny nose and nasal congestion. Unlike allergic rhinitis, the immune system is not involved.

## Symptoms & Diagnosis

### Symptoms
Allergic rhinitis symptoms include:
- Itching in the nose, roof of the mouth, throat, eyes
- Sneezing
- Stuffy nose (congestion)
- Runny nose
- Tearing eyes
- Dark circles under the eyes

Hay fever symptoms tend to flare up in the spring and fall. Perennial allergic rhinitis symptoms persist year-round.

### Diagnosis
An allergist / immunologist can diagnose specific allergens or determine if symptoms are non-allergic. Diagnosis includes a thorough health history followed by:
- Skin tests
- Blood tests  

These tests determine allergic rhinitis triggers.

## Treatment & Management
Once allergens are identified, your allergist will help develop a plan to avoid triggers. Examples include:

- Indoor allergens: Reduce dust mites, mold, and pet dander.
- Outdoor allergens (pollen): Limit outdoor activities during high pollen counts. The National Allergy BureauTM (NAB) provides accurate pollen and mold levels across the U.S.

### Immunotherapy
- Allergy shots: Provide long-term relief for many sufferers.  
- Sublingual immunotherapy (SLIT) allergy tablets: Daily tablets administered under the tongue as an alternative to shots.

### Medications
Your allergist may prescribe:
- Nasal corticosteroid sprays  
- Antihistamine pills  
- Nasal antihistamine sprays  
- Decongestant pills or sprays  

Non-allergic rhinitis treatments include nasal corticosteroids, nasal antihistamines, nasal saline, ipratropium nasal spray (for runny nose), and decongestants (used short-term only).

Starting allergy medications before allergen exposure can prevent histamine release and reduce severity of symptoms.
''',
      ),
      ResourceLink(
        title: 'Environmental Allergies',
        description:
            'Environmental allergies are a growing concern for many in the UK, and factors such as climate change, air pollution, and seasonal changes can significantly impact people with conditions like hay fever, also known as allergic rhinitis and asthma.',
        url:
            'https://www.allergyuk.org/information-and-support/support-for-you/living-with-an-allergy/environmental-allergies/',
        icon: Icons.energy_savings_leaf,
        color: AppColors.primary,
        category: 'Safety',
        imagePaths: ['assets/resources/Pollution.png'],
        detailedContent: '''
# Hay Fever, Allergic Rhinitis, and Environmental Factors

Hay fever, or allergic rhinitis, affects millions of people and is closely linked to environmental factors. Exposure to allergens like pollen, dust, and mold can lead to symptoms such as sneezing, itchy eyes, runny nose, and congestion. Seasonal changes, pollution, and climate change directly impact the severity and duration of these symptoms.

## Seasonal Changes and Pollen Levels
Pollen is one of the most common environmental triggers for hay fever. Different plants release pollen throughout the year:
- Trees: Spring (can start as early as February in some regions)  
- Grasses: Late spring to early summer (often the most challenging time)  
- Weeds: Late summer to early autumn (e.g., nettle, mugwort, ragweed)  

Windy or dry weather during peak pollen seasons can disperse pollen more widely, worsening symptoms.

## Air Pollution and Hay Fever
Air pollutants can intensify hay fever symptoms and make pollen more allergenic. Common pollutants include:
- Nitrogen dioxide (NO₂): From vehicle emissions  
- Particulate matter (PM): From industrial sources  

Polluted air can irritate the respiratory system and alter pollen grains, increasing allergic reactions.

## Asthma and Environmental Triggers
People with asthma are highly sensitive to environmental changes. Shifts in weather, rising temperatures, and increased pollution can make managing asthma more difficult.

### How Environmental Factors Affect Asthma
Environmental triggers such as pollen, pollution, and weather conditions can cause:
- Increased inflammation of the airways  
- Coughing, shortness of breath, wheezing, and chest tightness  

### Common Environmental Triggers Include:
- Air pollution and ground-level ozone: Irritate airways and increase risk of attacks, especially in urban areas.  
- Pollen from trees, grasses, and weeds: Can worsen asthma symptoms. Thunderstorms during high pollen seasons can create “thunderstorm asthma.”  
- Changes in humidity and temperature: Can tighten airways and trigger symptoms. High humidity may trap pollutants and pollen.

## Thunderstorm Asthma
Thunderstorm asthma occurs during high pollen seasons. Thunderstorms break pollen grains into smaller, more inhalable particles, which can penetrate deeper into the airways and trigger asthma attacks. This phenomenon poses risks even for individuals without asthma but with hay fever.
''',
      ),
    ];
  }
}
