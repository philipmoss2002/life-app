class FileAttachment {
  final int? id;
  final String filePath;
  final String fileName;
  final String? label;
  final DateTime addedAt;

  FileAttachment({
    this.id,
    required this.filePath,
    required this.fileName,
    this.label,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  String get displayName => label ?? fileName;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'label': label,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    return FileAttachment(
      id: map['id'],
      filePath: map['filePath'],
      fileName: map['fileName'],
      label: map['label'],
      addedAt: DateTime.parse(map['addedAt']),
    );
  }

  FileAttachment copyWith({
    int? id,
    String? filePath,
    String? fileName,
    String? label,
    DateTime? addedAt,
  }) {
    return FileAttachment(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      label: label ?? this.label,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
