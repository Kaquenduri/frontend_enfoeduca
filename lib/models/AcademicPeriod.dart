class AcademicPeriod {
  final String periodId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  const AcademicPeriod({
    required this.periodId,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory AcademicPeriod.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'period_id': String periodId,
        'name': String name,
        'start_date': String startDate,
        'end_date': String endDate,
      } =>
        AcademicPeriod(
          periodId: periodId,
          name: name,
          startDate: DateTime.parse(startDate),
          endDate: DateTime.parse(endDate),
        ),
      _ => throw const FormatException('Failed to load academic period.'),
    };
  }
}
