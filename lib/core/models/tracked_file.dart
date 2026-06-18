enum FileType { image, video, document, audio, archive, other }

extension FileTypeExtension on FileType {
  String get displayName {
    return switch (this) {
      FileType.image => 'Image',
      FileType.video => 'Video',
      FileType.document => 'Document',
      FileType.audio => 'Audio',
      FileType.archive => 'Archive',
      FileType.other => 'File',
    };
  }

  String get icon {
    return switch (this) {
      FileType.image => '🖼️',
      FileType.video => '🎬',
      FileType.document => '📄',
      FileType.audio => '🎵',
      FileType.archive => '📦',
      FileType.other => '📁',
    };
  }
}

class TrackedFile {
  const TrackedFile({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.fileType,
    required this.folderId,
    required this.detectedAt,
    this.expiresAt,
    required this.isStarred,
    required this.isDeleted,
  });

  final int id;
  final String path;
  final String name;
  final int size;
  final FileType fileType;
  final int folderId;
  final DateTime detectedAt;
  final DateTime? expiresAt;
  final bool isStarred;
  final bool isDeleted;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get expiresWithin24Hours {
    if (expiresAt == null) return false;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.inHours <= 24 && diff.inSeconds > 0;
  }

  bool get expiresWithin7Days {
    if (expiresAt == null) return false;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.inDays <= 7 && diff.inSeconds > 0;
  }

  TrackedFile copyWith({
    int? id,
    String? path,
    String? name,
    int? size,
    FileType? fileType,
    int? folderId,
    DateTime? detectedAt,
    DateTime? expiresAt,
    bool? isStarred,
    bool? isDeleted,
    bool clearExpiry = false,
  }) {
    return TrackedFile(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      fileType: fileType ?? this.fileType,
      folderId: folderId ?? this.folderId,
      detectedAt: detectedAt ?? this.detectedAt,
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
      isStarred: isStarred ?? this.isStarred,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'size': size,
      'file_type': fileType.name,
      'folder_id': folderId,
      'detected_at': detectedAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'is_starred': isStarred ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory TrackedFile.fromMap(Map<String, dynamic> map) {
    return TrackedFile(
      id: map['id'] as int,
      path: map['path'] as String,
      name: map['name'] as String,
      size: map['size'] as int,
      fileType: FileType.values.firstWhere(
        (e) => e.name == (map['file_type'] as String),
        orElse: () => FileType.other,
      ),
      folderId: map['folder_id'] as int,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(map['detected_at'] as int),
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
          : null,
      isStarred: (map['is_starred'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackedFile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
