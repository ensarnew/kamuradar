class CustomLinkWatcher {
  final String id;
  final String url;
  final String label;
  final String? lastChecked12pm;
  final String? lastChangeDetected;
  final bool hasUpdate;
  final String? notes;
  final String? aiCriteria;
  final List<String> targetKeywords;

  CustomLinkWatcher({
    required this.id,
    required this.url,
    required this.label,
    this.lastChecked12pm,
    this.lastChangeDetected,
    this.hasUpdate = false,
    this.notes,
    this.aiCriteria,
    this.targetKeywords = const [],
  });

  factory CustomLinkWatcher.fromJson(Map<String, dynamic> json) {
    return CustomLinkWatcher(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      label: json['label'] ?? '',
      lastChecked12pm: json['last_checked_12pm'],
      lastChangeDetected: json['last_change_detected'],
      hasUpdate: json['has_update'] ?? false,
      notes: json['notes'],
      aiCriteria: json['ai_criteria'],
      targetKeywords: List<String>.from(json['target_keywords'] ?? []),
    );
  }
}

