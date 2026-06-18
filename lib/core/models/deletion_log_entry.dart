class DeletionLogEntry {
  const DeletionLogEntry({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.size,
    required this.deletedAt,
    required this.reason,
  });

  final int id;
  final String filePath;
  final String fileName;
  final int size;
  final DateTime deletedAt;
  final String reason;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'size': size,
      'deleted_at': deletedAt.millisecondsSinceEpoch,
      'reason': reason,
    };
  }

  factory DeletionLogEntry.fromMap(Map<String, dynamic> map) {
    return DeletionLogEntry(
      id: map['id'] as int,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      size: map['size'] as int,
      deletedAt: DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int),
      reason: map['reason'] as String,
    );
  }
}
