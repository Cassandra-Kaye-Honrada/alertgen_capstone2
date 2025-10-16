class FoodAlternative {
  final String name;
  final String brand;
  final String description;
  final bool isPhilippines;
  final List<String> availableAt;
  final List<String> ingredients;
  final bool isSafeForUserAllergens;
  final String? imageUrl;

  FoodAlternative({
    required this.name,
    required this.brand,
    required this.description,
    required this.isPhilippines,
    required this.availableAt,
    this.ingredients = const [],
    required this.isSafeForUserAllergens,
    this.imageUrl,
  });

  factory FoodAlternative.fromJson(Map<String, dynamic> json) {
    return FoodAlternative(
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      description: json['description'] ?? '',
      isPhilippines: json['isPhilippines'] ?? true,
      availableAt: List<String>.from(json['availableAt'] ?? []),
    
      ingredients: List<String>.from(json['ingredients'] ?? []),
      isSafeForUserAllergens: json['isSafeForUserAllergens'] ?? true,
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'description': description,
      'isPhilippines': isPhilippines,
      'availableAt': availableAt,
      'ingredients': ingredients,
      'isSafeForUserAllergens': isSafeForUserAllergens,
      'imageUrl': imageUrl,
    };
  }

  FoodAlternative copyWith({
    String? name,
    String? brand,
    String? description,
    bool? isPhilippines,
    List<String>? availableAt,
    List<String>? ingredients,
    bool? isSafeForUserAllergens,
    String? imageUrl,
  }) {
    return FoodAlternative(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      isPhilippines: isPhilippines ?? this.isPhilippines,
      availableAt: availableAt ?? this.availableAt,
      ingredients: ingredients ?? this.ingredients,
      isSafeForUserAllergens:
          isSafeForUserAllergens ?? this.isSafeForUserAllergens,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
