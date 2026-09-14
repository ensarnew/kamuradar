class ExamScheduleItem {
  final String id;
  final String title;
  final String organization;
  final String applicationDates;
  final String? examDate;
  final String? resultDate;
  final String status;
  final String officialUrl;

  ExamScheduleItem({
    required this.id,
    required this.title,
    required this.organization,
    required this.applicationDates,
    this.examDate,
    this.resultDate,
    required this.status,
    required this.officialUrl,
  });

  factory ExamScheduleItem.fromJson(Map<String, dynamic> json) {
    return ExamScheduleItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      organization: json['organization'] ?? '',
      applicationDates: json['application_dates'] ?? '',
      examDate: json['exam_date'],
      resultDate: json['result_date'],
      status: json['status'] ?? '',
      officialUrl: json['official_url'] ?? '',
    );
  }
}

typedef ExamSchedule = ExamScheduleItem;
