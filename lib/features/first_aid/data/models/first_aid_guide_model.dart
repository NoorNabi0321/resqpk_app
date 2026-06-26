class FirstAidStep {
  final int step;
  final String title;
  final String instruction;

  const FirstAidStep({required this.step, required this.title, required this.instruction});

  factory FirstAidStep.fromJson(Map<String, dynamic> json) => FirstAidStep(
        step: json['step'] is int ? json['step'] as int : int.tryParse('${json['step']}') ?? 0,
        title: json['title']?.toString() ?? '',
        instruction: json['instruction']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'step': step, 'title': title, 'instruction': instruction};
}

class FirstAidGuideModel {
  final String id;
  final String category;
  final String titleEn;
  final String? titleUr;
  final String slug;
  final List<String> emergencyTypes;
  final List<FirstAidStep> stepsEn;
  final List<FirstAidStep>? stepsUr;
  final String? iconName;
  final bool isFeatured;
  final int displayOrder;

  const FirstAidGuideModel({
    required this.id,
    required this.category,
    required this.titleEn,
    this.titleUr,
    required this.slug,
    this.emergencyTypes = const [],
    this.stepsEn = const [],
    this.stepsUr,
    this.iconName,
    this.isFeatured = false,
    this.displayOrder = 0,
  });

  static List<FirstAidStep> _steps(dynamic v) {
    if (v is List) {
      return v.map((e) => FirstAidStep.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    return const [];
  }

  static List<String> _strings(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  factory FirstAidGuideModel.fromJson(Map<String, dynamic> json) {
    final stepsUrRaw = json['steps_ur'] ?? json['stepsUr'];
    return FirstAidGuideModel(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      titleEn: (json['title_en'] ?? json['titleEn'])?.toString() ?? '',
      titleUr: (json['title_ur'] ?? json['titleUr'])?.toString(),
      slug: json['slug']?.toString() ?? '',
      emergencyTypes: _strings(json['emergency_types'] ?? json['emergencyTypes']),
      stepsEn: _steps(json['steps_en'] ?? json['stepsEn']),
      stepsUr: stepsUrRaw != null ? _steps(stepsUrRaw) : null,
      iconName: (json['icon_name'] ?? json['iconName'])?.toString(),
      isFeatured: (json['is_featured'] ?? json['isFeatured']) == true,
      displayOrder: json['display_order'] is int
          ? json['display_order'] as int
          : int.tryParse('${json['display_order'] ?? json['displayOrder']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title_en': titleEn,
        'title_ur': titleUr,
        'slug': slug,
        'emergency_types': emergencyTypes,
        'steps_en': stepsEn.map((s) => s.toJson()).toList(),
        'steps_ur': stepsUr?.map((s) => s.toJson()).toList(),
        'icon_name': iconName,
        'is_featured': isFeatured,
        'display_order': displayOrder,
      };

  String getTitle(String language) {
    if (language == 'ur' && titleUr != null && titleUr!.isNotEmpty) return titleUr!;
    return titleEn;
  }

  List<FirstAidStep> getSteps(String language) {
    if (language == 'ur' && stepsUr != null && stepsUr!.isNotEmpty) return stepsUr!;
    return stepsEn;
  }
}
