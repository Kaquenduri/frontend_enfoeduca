class TeacherAssignment {
  final String idSection;
  final String courseId;
  final String periodId;
  final String teacherId;
  final AssignmentSection section;
  final AssignmentCourse course;
  final AssignmentPeriod academicPeriod;

  TeacherAssignment({
    required this.idSection,
    required this.courseId,
    required this.periodId,
    required this.teacherId,
    required this.section,
    required this.course,
    required this.academicPeriod,
  });

  factory TeacherAssignment.fromJson(Map<String, dynamic> json) {
    return TeacherAssignment(
      idSection: json['id_section'] ?? '',
      courseId: json['course_id'] ?? '',
      periodId: json['period_id'] ?? '',
      teacherId: json['teacher_id'] ?? '',
      section: AssignmentSection.fromJson(json['section'] ?? {}),
      course: AssignmentCourse.fromJson(json['course'] ?? {}),
      academicPeriod: AssignmentPeriod.fromJson(json['academicperiod'] ?? {}),
    );
  }
}

class AssignmentSection {
  final String idSection;
  final String name;
  final String grade;

  AssignmentSection({
    required this.idSection,
    required this.name,
    required this.grade,
  });

  factory AssignmentSection.fromJson(Map<String, dynamic> json) {
    return AssignmentSection(
      idSection: json['id_section'] ?? '',
      name: json['name'] ?? '',
      grade: json['grade'] ?? '',
    );
  }
}

class AssignmentCourse {
  final String courseId;
  final String name;
  final String description;

  AssignmentCourse({
    required this.courseId,
    required this.name,
    required this.description,
  });

  factory AssignmentCourse.fromJson(Map<String, dynamic> json) {
    return AssignmentCourse(
      courseId: json['course_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class AssignmentPeriod {
  final String periodId;
  final String name;

  AssignmentPeriod({required this.periodId, required this.name});

  factory AssignmentPeriod.fromJson(Map<String, dynamic> json) {
    return AssignmentPeriod(
      periodId: json['period_id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
