class MaterialModel {
  final String materialId;
  final String sessionId;
  final String title;
  final String fileType;
  final String fileUrl;
  final String description;
  final String createdAt;
  final String updatedAt;

  const MaterialModel({
    required this.materialId,
    required this.sessionId,
    required this.title,
    required this.fileType,
    required this.fileUrl,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'material_id': String materialId,
        'session_id': String sessionId,
        'title': String title,
        'file_type': String fileType,
        'file_url': String fileUrl,
        'description': String description,
        'created_at': String createdAt,
        'updated_at': String updatedAt,
      } =>
        MaterialModel(
          materialId: materialId,
          sessionId: sessionId,
          title: title,
          fileType: fileType,
          fileUrl: fileUrl,
          description: description,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      _ => throw const FormatException('Failed to load Material.'),
    };
  }
}
