class MonitoredFolder {
  const MonitoredFolder({
    required this.id,
    required this.path,
    required this.displayName,
    required this.isEnabled,
    required this.defaultRetentionDays,
    required this.createdAt,
  });

  final int id;
  final String path;
  final String displayName;
  final bool isEnabled;
  final int defaultRetentionDays;
  final DateTime createdAt;

  MonitoredFolder copyWith({
    int? id,
    String? path,
    String? displayName,
    bool? isEnabled,
    int? defaultRetentionDays,
    DateTime? createdAt,
  }) {
    return MonitoredFolder(
      id: id ?? this.id,
      path: path ?? this.path,
      displayName: displayName ?? this.displayName,
      isEnabled: isEnabled ?? this.isEnabled,
      defaultRetentionDays: defaultRetentionDays ?? this.defaultRetentionDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'display_name': displayName,
      'is_enabled': isEnabled ? 1 : 0,
      'default_retention_days': defaultRetentionDays,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory MonitoredFolder.fromMap(Map<String, dynamic> map) {
    return MonitoredFolder(
      id: map['id'] as int,
      path: map['path'] as String,
      displayName: map['display_name'] as String,
      isEnabled: (map['is_enabled'] as int) == 1,
      defaultRetentionDays: map['default_retention_days'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonitoredFolder && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
