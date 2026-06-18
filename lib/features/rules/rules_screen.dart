import 'dart:convert';

import 'package:fileflow/core/models/retention_rule.dart';
import 'package:fileflow/core/providers/rules_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Protection Rules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRuleSheet(context, ref),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
        error: (err, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load rules',
          subtitle: err.toString(),
          action: () => ref.read(rulesProvider.notifier).refresh(),
          actionLabel: 'Retry',
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return const EmptyState(
              icon: Icons.shield_outlined,
              title: 'No protection rules',
              subtitle:
                  'Add rules to protect specific file types, sizes, or folders from auto-deletion.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: rules.length,
            itemBuilder: (_, i) => _RuleCard(
              rule: rules[i],
              onEdit: () => _showRuleSheet(context, ref, existing: rules[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRuleSheet(
    BuildContext context,
    WidgetRef ref, {
    RetentionRule? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RuleSheet(
        existing: existing,
        onSave: (rule) => existing == null
            ? ref.read(rulesProvider.notifier).addRule(rule)
            : ref.read(rulesProvider.notifier).updateRule(rule),
      ),
    );
  }
}

// ── Rule card ──────────────────────────────────────────────────────────────

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule, required this.onEdit});
  final RetentionRule rule;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _RuleIcon(type: rule.ruleType, enabled: rule.isEnabled),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: TextStyle(
                        color: rule.isEnabled
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _conditionLabel(rule),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.isEnabled,
                onChanged: (v) =>
                    ref.read(rulesProvider.notifier).toggleEnabled(
                          rule.id,
                          enabled: v,
                        ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textMuted, size: 18),
                onPressed: () => _confirmDelete(context, ref),
                tooltip: 'Delete rule',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _conditionLabel(RetentionRule rule) {
    if (rule.conditionValue == null) {
      return rule.ruleType == RuleType.neverDelete
          ? 'Never delete any file'
          : 'No condition set';
    }

    try {
      final cond = jsonDecode(rule.conditionValue!) as Map<String, dynamic>;
      return switch (rule.ruleType) {
        RuleType.neverDelete => 'Never delete any file',
        RuleType.fileType => () {
            final t = cond['type'] as String? ?? '';
            return 'File type: $t';
          }(),
        RuleType.fileSize => () {
            final bytes = (cond['bytes'] as num?)?.toInt() ?? 0;
            final mb = bytes ~/ (1024 * 1024);
            return 'Min size: ${mb}MB';
          }(),
        RuleType.folderPath => () {
            final path = cond['path'] as String? ?? '';
            return 'Folder: $path';
          }(),
        RuleType.fileExtension => () {
            final exts = (cond['extensions'] as List<dynamic>?)
                    ?.map((e) => '.${e.toString()}')
                    .join(', ') ??
                '';
            return 'Extensions: $exts';
          }(),
      };
    } catch (_) {
      return rule.conditionValue ?? '';
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete rule?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove "${rule.name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(rulesProvider.notifier).deleteRule(rule.id);
    }
  }
}

class _RuleIcon extends StatelessWidget {
  const _RuleIcon({required this.type, required this.enabled});
  final RuleType type;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      RuleType.neverDelete => Icons.lock_outline,
      RuleType.fileType => Icons.category_outlined,
      RuleType.fileSize => Icons.storage_outlined,
      RuleType.folderPath => Icons.folder_outlined,
      RuleType.fileExtension => Icons.description_outlined,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: enabled ? AppColors.safe : AppColors.textMuted,
        size: 20,
      ),
    );
  }
}

// ── Add / Edit sheet ───────────────────────────────────────────────────────

class _RuleSheet extends StatefulWidget {
  const _RuleSheet({required this.onSave, this.existing});
  final Future<void> Function(RetentionRule) onSave;
  final RetentionRule? existing;

  @override
  State<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<_RuleSheet> {
  late final TextEditingController _nameCtrl;
  late RuleType _ruleType;
  bool _saving = false;

  // fileType condition
  String _selectedFileType = 'image';

  // fileExtension condition
  final List<String> _extensions = [];
  final _extCtrl = TextEditingController();

  // fileSize condition
  final _sizeCtrl = TextEditingController();

  // folderPath condition
  final _pathCtrl = TextEditingController();

  static const _fileTypes = ['image', 'video', 'document', 'audio', 'archive'];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _ruleType = e?.ruleType ?? RuleType.fileExtension;
    _loadCondition(e);
  }

  void _loadCondition(RetentionRule? rule) {
    if (rule?.conditionValue == null) return;
    try {
      final cond =
          jsonDecode(rule!.conditionValue!) as Map<String, dynamic>;
      switch (rule.ruleType) {
        case RuleType.fileType:
          _selectedFileType = cond['type'] as String? ?? 'image';
        case RuleType.fileSize:
          final bytes = (cond['bytes'] as num?)?.toInt() ?? 0;
          _sizeCtrl.text = (bytes ~/ (1024 * 1024)).toString();
        case RuleType.folderPath:
          _pathCtrl.text = cond['path'] as String? ?? '';
        case RuleType.fileExtension:
          final raw = cond['extensions'] as List<dynamic>?;
          if (raw != null) {
            _extensions.addAll(raw.map((e) => e.toString()));
          }
        case RuleType.neverDelete:
          break;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _extCtrl.dispose();
    _sizeCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Rule' : 'New Protection Rule',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isEditing)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Editing',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Rule name
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Rule name',
                hintText: 'e.g. Protect PDFs',
              ),
            ),
            const SizedBox(height: 16),

            // Rule type
            DropdownButtonFormField<RuleType>(
              key: ValueKey(_ruleType),
              initialValue: _ruleType,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Rule type'),
              items: const [
                DropdownMenuItem(
                  value: RuleType.fileExtension,
                  child: Text('Protect file extensions'),
                ),
                DropdownMenuItem(
                  value: RuleType.fileType,
                  child: Text('Protect file type'),
                ),
                DropdownMenuItem(
                  value: RuleType.fileSize,
                  child: Text('Protect by minimum size'),
                ),
                DropdownMenuItem(
                  value: RuleType.folderPath,
                  child: Text('Protect folder path'),
                ),
                DropdownMenuItem(
                  value: RuleType.neverDelete,
                  child: Text('Never delete anything'),
                ),
              ],
              onChanged: (v) => setState(() => _ruleType = v!),
            ),
            const SizedBox(height: 20),

            // Condition input per type
            _buildConditionInput(),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Add Rule'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionInput() {
    return switch (_ruleType) {
      RuleType.neverDelete => const SizedBox.shrink(),
      RuleType.fileType => _FileTypeInput(
          selected: _selectedFileType,
          types: _fileTypes,
          onChanged: (t) => setState(() => _selectedFileType = t),
        ),
      RuleType.fileSize => _FileSizeInput(controller: _sizeCtrl),
      RuleType.folderPath => _FolderPathInput(controller: _pathCtrl),
      RuleType.fileExtension => _ExtensionTagInput(
          extensions: _extensions,
          controller: _extCtrl,
          onAdd: _addExtension,
          onRemove: (ext) => setState(() => _extensions.remove(ext)),
        ),
    };
  }

  void _addExtension() {
    final raw = _extCtrl.text.trim().toLowerCase().replaceAll('.', '');
    if (raw.isNotEmpty && !_extensions.contains(raw)) {
      setState(() => _extensions.add(raw));
    }
    _extCtrl.clear();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final conditionJson = _buildCondition();
      final rule = RetentionRule(
        id: widget.existing?.id ?? 0,
        name: name,
        ruleType: _ruleType,
        conditionValue: conditionJson,
        priority: widget.existing?.priority ?? 0,
        isEnabled: widget.existing?.isEnabled ?? true,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      await widget.onSave(rule);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _buildCondition() {
    return switch (_ruleType) {
      RuleType.neverDelete => null,
      RuleType.fileType => jsonEncode({'type': _selectedFileType}),
      RuleType.fileSize => () {
          final mb = int.tryParse(_sizeCtrl.text.trim()) ?? 0;
          return jsonEncode({'operator': 'gt', 'bytes': mb * 1024 * 1024});
        }(),
      RuleType.folderPath => () {
          final path = _pathCtrl.text.trim();
          return path.isEmpty ? null : jsonEncode({'path': path});
        }(),
      RuleType.fileExtension => () {
          if (_extensions.isEmpty) return null;
          return jsonEncode({'extensions': _extensions});
        }(),
    };
  }
}

// ── Condition input widgets ────────────────────────────────────────────────

class _FileTypeInput extends StatelessWidget {
  const _FileTypeInput({
    required this.selected,
    required this.types,
    required this.onChanged,
  });
  final String selected;
  final List<String> types;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'File category',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final isSelected = t == selected;
            return ChoiceChip(
              label: Text(t),
              selected: isSelected,
              onSelected: (_) => onChanged(t),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.card,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.accent : AppColors.cardBorder,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FileSizeInput extends StatelessWidget {
  const _FileSizeInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Minimum size (MB)',
        hintText: 'e.g. 100',
        suffixText: 'MB',
        suffixStyle: TextStyle(color: AppColors.textSecondary),
        helperText: 'Protect files larger than this size',
        helperStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}

class _FolderPathInput extends StatelessWidget {
  const _FolderPathInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Folder path',
        hintText: '/storage/emulated/0/Work',
        prefixIcon: Icon(Icons.folder_outlined, size: 18),
        helperText: 'All files inside this folder will be protected',
        helperStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}

class _ExtensionTagInput extends StatelessWidget {
  const _ExtensionTagInput({
    required this.extensions,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> extensions;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'File extension',
                  hintText: 'pdf',
                  helperText: 'Press + to add each extension',
                  helperStyle:
                      TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle, color: AppColors.accent),
              tooltip: 'Add extension',
            ),
          ],
        ),
        if (extensions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: extensions.map((ext) {
              return Chip(
                label: Text('.$ext'),
                labelStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                backgroundColor: AppColors.card,
                side: const BorderSide(color: AppColors.cardBorder),
                deleteIcon: const Icon(Icons.close, size: 14),
                deleteIconColor: AppColors.textMuted,
                onDeleted: () => onRemove(ext),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
