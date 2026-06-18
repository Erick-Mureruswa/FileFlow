enum RuleType { neverDelete, fileType, fileSize, folderPath, fileExtension }

class RetentionRule {
  const RetentionRule({
    required this.id,
    required this.name,
    required this.ruleType,
    this.conditionValue,
    required this.priority,
    required this.isEnabled,
    required this.createdAt,
  });

  final int id;
  final String name;
  final RuleType ruleType;
  // JSON-encoded condition. E.g. for fileType: '{"type":"image"}'
  // for fileSize: '{"operator":"gt","bytes":104857600}'
  // for folderPath: '{"path":"/storage/Work"}'
  // for fileExtension: '{"extensions":["pdf","docx"]}'
  final String? conditionValue;
  final int priority;
  final bool isEnabled;
  final DateTime createdAt;

  RetentionRule copyWith({
    int? id,
    String? name,
    RuleType? ruleType,
    String? conditionValue,
    int? priority,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return RetentionRule(
      id: id ?? this.id,
      name: name ?? this.name,
      ruleType: ruleType ?? this.ruleType,
      conditionValue: conditionValue ?? this.conditionValue,
      priority: priority ?? this.priority,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rule_type': ruleType.name,
      'condition_value': conditionValue,
      'priority': priority,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory RetentionRule.fromMap(Map<String, dynamic> map) {
    return RetentionRule(
      id: map['id'] as int,
      name: map['name'] as String,
      ruleType: RuleType.values.firstWhere(
        (e) => e.name == (map['rule_type'] as String),
        orElse: () => RuleType.neverDelete,
      ),
      conditionValue: map['condition_value'] as String?,
      priority: map['priority'] as int,
      isEnabled: (map['is_enabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetentionRule && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
