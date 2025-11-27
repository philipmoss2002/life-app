class Document {
  final int? id;
  final String title;
  final String category;
  final String? filePath;
  final DateTime? renewalDate;
  final String? notes;
  final DateTime createdAt;

  Document({
    this.id,
    required this.title,
    required this.category,
    this.filePath,
    this.renewalDate,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'filePath': filePath,
      'renewalDate': renewalDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'],
      title: map['title'],
      category: map['category'],
      filePath: map['filePath'],
      renewalDate: map['renewalDate'] != null
          ? DateTime.parse(map['renewalDate'])
          : null,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
