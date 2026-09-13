class Announcement {
  final String id;
  final String title;
  final String organization;
  final String category;
  final String summary;
  final List<String> requirements;
  final String? applicationStart;
  final String? applicationDeadline;
  final String officialUrl;
  final String publishedAt;
  final String scannedAt12pm;
  final bool isHot;

  Announcement({
    required this.id,
    required this.title,
    required this.organization,
    required this.category,
    required this.summary,
    required this.requirements,
    this.applicationStart,
    this.applicationDeadline,
    required this.officialUrl,
    required this.publishedAt,
    required this.scannedAt12pm,
    this.isHot = false,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      organization: json['organization'] ?? '',
      category: json['category'] ?? '',
      summary: json['summary'] ?? '',
      requirements: List<String>.from(json['requirements'] ?? []),
      applicationStart: json['application_start'],
      applicationDeadline: json['application_deadline'],
      officialUrl: json['official_url'] ?? '',
      publishedAt: json['published_at'] ?? '',
      scannedAt12pm: json['scanned_at_12pm'] ?? '',
      isHot: json['is_hot'] ?? false,
    );
  }
}
