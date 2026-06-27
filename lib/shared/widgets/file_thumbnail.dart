import 'dart:io';
import 'dart:typed_data';

import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/services/video_thumbnail_service.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

// Generated video thumbnails are cached in-memory by path so list scrolling and
// rebuilds don't regenerate them. `null` means generation failed (show icon).
final Map<String, Uint8List?> _videoThumbCache = {};

/// Shows a real preview of a file:
/// - images render directly,
/// - videos render a generated frame with a play badge,
/// - everything else falls back to a typed, colored icon.
///
/// Use [size] for a fixed rounded square (lists); set [expand] to fill the
/// parent with a cover-cropped preview (large cards).
class FileThumbnail extends StatelessWidget {
  const FileThumbnail({
    super.key,
    required this.path,
    required this.type,
    this.size = 44,
    this.borderRadius = 10,
    this.expand = false,
  });

  final String path;
  final FileType type;
  final double size;
  final double borderRadius;
  final bool expand;

  static const _iconConfig = {
    FileType.image: (Icons.image_outlined, Color(0xFF10B981)),
    FileType.video: (Icons.videocam_outlined, Color(0xFF7C3AED)),
    FileType.audio: (Icons.audiotrack_outlined, Color(0xFF0EA5E9)),
    FileType.document: (Icons.description_outlined, Color(0xFFF59E0B)),
    FileType.archive: (Icons.folder_zip_outlined, Color(0xFF6B7280)),
    FileType.other: (Icons.insert_drive_file_outlined, Color(0xFF475569)),
  };

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      FileType.image => _mediaFrame(_image()),
      FileType.video => _mediaFrame(_video(), withPlayBadge: true),
      _ => _iconFrame(),
    };
  }

  Widget _image() {
    // Decode at a sensible resolution to keep memory low; ~3x covers most DPRs.
    final cacheW = expand ? 800 : (size * 3).round();
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: expand ? double.infinity : size,
      height: expand ? double.infinity : size,
      cacheWidth: cacheW,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _iconContent(),
    );
  }

  Widget _video() {
    return _VideoThumb(
      path: path,
      width: expand ? double.infinity : size,
      height: expand ? double.infinity : size,
      fallback: _iconContent(),
    );
  }

  // Frame for real media (neutral background, clipped, optional play badge).
  Widget _mediaFrame(Widget child, {bool withPlayBadge = false}) {
    final content = withPlayBadge
        ? Stack(
            fit: StackFit.expand,
            children: [child, const Center(child: _PlayBadge())],
          )
        : child;

    if (expand) return content;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: content,
    );
  }

  Widget _iconFrame() {
    final (_, color) = _iconConfig[type]!;
    if (expand) {
      return ColoredBox(
        color: color.withValues(alpha: 0.08),
        child: Center(child: _iconContent(big: true)),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(child: _iconContent()),
    );
  }

  Widget _iconContent({bool big = false}) {
    final (icon, color) = _iconConfig[type]!;
    return Icon(icon, color: color, size: big ? 72 : size * 0.45);
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Color(0x99000000),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _VideoThumb extends StatefulWidget {
  const _VideoThumb({
    required this.path,
    required this.width,
    required this.height,
    required this.fallback,
  });

  final String path;
  final double width;
  final double height;
  final Widget fallback;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  Uint8List? _data;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_videoThumbCache.containsKey(widget.path)) {
      setState(() {
        _data = _videoThumbCache[widget.path];
        _done = true;
      });
      return;
    }
    final data = await VideoThumbnailService.generate(widget.path, maxWidth: 320);
    _videoThumbCache[widget.path] = data;
    if (mounted) {
      setState(() {
        _data = data;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_done) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) return widget.fallback;
    return Image.memory(
      data,
      fit: BoxFit.cover,
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => widget.fallback,
    );
  }
}
