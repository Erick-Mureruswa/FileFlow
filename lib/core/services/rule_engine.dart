import 'dart:convert';
import 'dart:io';

import 'package:fileflow/core/models/retention_rule.dart';
import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/shared/utils/file_utils.dart';

class RuleEngine {
  const RuleEngine();

  // Returns true if this file is protected by any enabled rule (should not be deleted).
  bool isProtected(TrackedFile file, List<RetentionRule> rules) {
    final enabledRules = rules.where((r) => r.isEnabled).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in enabledRules) {
      if (_matches(file, rule)) return true;
    }
    return false;
  }

  bool _matches(TrackedFile file, RetentionRule rule) {
    return switch (rule.ruleType) {
      RuleType.neverDelete => true,
      RuleType.fileType => _matchesFileType(file, rule.conditionValue),
      RuleType.fileSize => _matchesFileSize(file, rule.conditionValue),
      RuleType.folderPath => _matchesFolderPath(file, rule.conditionValue),
      RuleType.fileExtension => _matchesExtension(file, rule.conditionValue),
    };
  }

  bool _matchesFileType(TrackedFile file, String? condition) {
    if (condition == null) return false;
    try {
      final data = jsonDecode(condition) as Map<String, dynamic>;
      final typeName = data['type'] as String?;
      return file.fileType.name == typeName;
    } on FormatException {
      return false;
    }
  }

  bool _matchesFileSize(TrackedFile file, String? condition) {
    if (condition == null) return false;
    try {
      final data = jsonDecode(condition) as Map<String, dynamic>;
      final operator = data['operator'] as String;
      final bytes = data['bytes'] as int;
      return switch (operator) {
        'gt' => file.size > bytes,
        'gte' => file.size >= bytes,
        'lt' => file.size < bytes,
        'lte' => file.size <= bytes,
        _ => false,
      };
    } on FormatException {
      return false;
    }
  }

  bool _matchesFolderPath(TrackedFile file, String? condition) {
    if (condition == null) return false;
    try {
      final data = jsonDecode(condition) as Map<String, dynamic>;
      final rulePath = data['path'] as String;
      return file.path.startsWith(rulePath);
    } on FormatException {
      return false;
    }
  }

  bool _matchesExtension(TrackedFile file, String? condition) {
    if (condition == null) return false;
    try {
      final data = jsonDecode(condition) as Map<String, dynamic>;
      final extensions = (data['extensions'] as List).cast<String>();
      final fileExt = file.name.split('.').last.toLowerCase();
      return extensions.contains(fileExt);
    } on FormatException {
      return false;
    }
  }

  // Compute the expiry date for a newly detected file based on folder's default retention.
  DateTime? computeExpiry(int defaultRetentionDays, DateTime detectedAt) {
    if (defaultRetentionDays <= 0) return null;
    return detectedAt.add(Duration(days: defaultRetentionDays));
  }

  // Checks that the file still physically exists on disk.
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  // Detects the file type from its name using FileUtils.
  FileType detectFileType(String filename) {
    return FileUtils.detectType(filename);
  }
}
