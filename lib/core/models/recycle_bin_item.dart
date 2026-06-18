class RecycleBinItem {
  const RecycleBinItem({
    required this.id,
    required this.originalPath,
    required this.name,
    required this.size,
    required this.fileType,
    required this.deletedAt,
    required this.permanentDeleteAt,
  });

  final int id;
  final String originalPath;
  final String name;
  final int size;
  final String fileType;
  final DateTime deletedAt;
  final DateTime permanentDeleteAt;

  bool get isPermanentlyDeletable =>
      permanentDeleteAt.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_path': originalPath,
      'name': name,
      'size': size,
      'file_type': fileType,
      'deleted_at': deletedAt.millisecondsSinceEpoch,
      'permanent_delete_at': permanentDeleteAt.millisecondsSinceEpoch,
    };
  }

  factory RecycleBinItem.fromMap(Map<String, dynamic> map) {
    return RecycleBinItem(
      id: map['id'] as int,
      originalPath: map['original_path'] as String,
      name: map['name'] as String,
      size: map['size'] as int,
      fileType: map['file_type'] as String,
      deletedAt: DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int),
      permanentDeleteAt:
          DateTime.fromMillisecondsSinceEpoch(map['permanent_delete_at'] as int),
    );
  }
}
