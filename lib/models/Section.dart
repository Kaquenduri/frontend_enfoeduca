import 'AcademicPeriod.dart';

class Section {
  final String idSection;
  final String idPeriod;
  final String name;
  final String grade;
  final AcademicPeriod academicPeriod;

  const Section({
    required this.idSection,
    required this.idPeriod,
    required this.name,
    required this.grade,
    required this.academicPeriod,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id_section': String idSection,
        'id_period': String idPeriod,
        'name': String name,
        'grade': String grade,
        'academicPeriod': Map<String, dynamic> academicPeriod,
      } =>
        Section(
          idSection: idSection,
          idPeriod: idPeriod,
          name: name,
          grade: grade,
          academicPeriod: AcademicPeriod.fromJson(academicPeriod),
        ),
      _ => throw const FormatException('Failed to load section.'),
    };
  }
}
