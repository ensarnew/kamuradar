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
  final bool isNotificationActive;
  final String? lastScannedResult;
  final bool isScanning;

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
    this.isNotificationActive = true,
    this.lastScannedResult,
    this.isScanning = false,
  });

  CustomLinkWatcher copyWith({
    String? id,
    String? url,
    String? label,
    String? lastChecked12pm,
    String? lastChangeDetected,
    bool? hasUpdate,
    String? notes,
    String? aiCriteria,
    List<String>? targetKeywords,
    bool? isNotificationActive,
    String? lastScannedResult,
    bool? isScanning,
  }) {
    return CustomLinkWatcher(
      id: id ?? this.id,
      url: url ?? this.url,
      label: label ?? this.label,
      lastChecked12pm: lastChecked12pm ?? this.lastChecked12pm,
      lastChangeDetected: lastChangeDetected ?? this.lastChangeDetected,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      notes: notes ?? this.notes,
      aiCriteria: aiCriteria ?? this.aiCriteria,
      targetKeywords: targetKeywords ?? this.targetKeywords,
      isNotificationActive: isNotificationActive ?? this.isNotificationActive,
      lastScannedResult: lastScannedResult ?? this.lastScannedResult,
      isScanning: isScanning ?? this.isScanning,
    );
  }

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
      isNotificationActive: json['is_notification_active'] ?? true,
      lastScannedResult: json['last_scanned_result'],
      isScanning: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'label': label,
      'last_checked_12pm': lastChecked12pm,
      'last_change_detected': lastChangeDetected,
      'has_update': hasUpdate,
      'notes': notes,
      'ai_criteria': aiCriteria,
      'target_keywords': targetKeywords,
      'is_notification_active': isNotificationActive,
      'last_scanned_result': lastScannedResult,
    };
  }
}
