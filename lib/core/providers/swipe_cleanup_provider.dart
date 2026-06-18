import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SwipeCleanupState {
  const SwipeCleanupState({
    this.reviewFiles = const [],
    this.pendingDeletions = const [],
    this.isProcessingBatch = false,
  });

  final List<TrackedFile> reviewFiles;
  final List<TrackedFile> pendingDeletions;
  final bool isProcessingBatch;

  SwipeCleanupState copyWith({
    List<TrackedFile>? reviewFiles,
    List<TrackedFile>? pendingDeletions,
    bool? isProcessingBatch,
  }) {
    return SwipeCleanupState(
      reviewFiles: reviewFiles ?? this.reviewFiles,
      pendingDeletions: pendingDeletions ?? this.pendingDeletions,
      isProcessingBatch: isProcessingBatch ?? this.isProcessingBatch,
    );
  }
}

class SwipeCleanupNotifier extends AsyncNotifier<SwipeCleanupState> {
  @override
  Future<SwipeCleanupState> build() async {
    final fileDao = ref.read(trackedFileDaoProvider);
    final pendingDao = ref.read(pendingDeletionDaoProvider);

    final allFiles = await fileDao.getAll();
    final pendingIds = await pendingDao.getAllFileIds();
    final pendingFiles = await pendingDao.getAllWithFiles();

    final reviewFiles = allFiles
        .where((f) => !f.isStarred && !pendingIds.contains(f.id))
        .toList()
      ..sort((a, b) => b.size.compareTo(a.size));

    return SwipeCleanupState(
      reviewFiles: reviewFiles,
      pendingDeletions: pendingFiles,
    );
  }

  Future<void> keepFile(TrackedFile file) async {
    final fileDao = ref.read(trackedFileDaoProvider);
    await fileDao.setStarred(file.id, starred: true);
    state = AsyncData(
      state.value!.copyWith(
        reviewFiles: state.value!.reviewFiles
            .where((f) => f.id != file.id)
            .toList(),
      ),
    );
  }

  Future<void> queueForDeletion(TrackedFile file) async {
    final pendingDao = ref.read(pendingDeletionDaoProvider);
    await pendingDao.add(file.id);

    final updatedPending = [...state.value!.pendingDeletions, file];
    state = AsyncData(
      state.value!.copyWith(
        reviewFiles: state.value!.reviewFiles
            .where((f) => f.id != file.id)
            .toList(),
        pendingDeletions: updatedPending,
      ),
    );
  }

  Future<void> undoDelete(TrackedFile file) async {
    final pendingDao = ref.read(pendingDeletionDaoProvider);
    await pendingDao.remove(file.id);

    final updatedPending = state.value!.pendingDeletions
        .where((f) => f.id != file.id)
        .toList();

    final updatedReview = [...state.value!.reviewFiles, file]
      ..sort((a, b) => b.size.compareTo(a.size));

    state = AsyncData(
      state.value!.copyWith(
        reviewFiles: updatedReview,
        pendingDeletions: updatedPending,
      ),
    );
  }

  Future<void> removeFromQueue(TrackedFile file) async {
    final pendingDao = ref.read(pendingDeletionDaoProvider);
    await pendingDao.remove(file.id);

    final updatedPending = state.value!.pendingDeletions
        .where((f) => f.id != file.id)
        .toList();

    final updatedReview = [...state.value!.reviewFiles, file]
      ..sort((a, b) => b.size.compareTo(a.size));

    state = AsyncData(
      state.value!.copyWith(
        reviewFiles: updatedReview,
        pendingDeletions: updatedPending,
      ),
    );
  }

  Future<void> confirmBatchDelete() async {
    final current = state.value;
    if (current == null || current.pendingDeletions.isEmpty) return;

    state = AsyncData(current.copyWith(isProcessingBatch: true));

    final deletionService = ref.read(deletionServiceProvider);
    final pendingDao = ref.read(pendingDeletionDaoProvider);

    for (final file in current.pendingDeletions) {
      try {
        await deletionService.deleteFileNow(file);
      } on Exception {
        // Log and continue — don't block the rest
      }
    }

    await pendingDao.clearAll();

    state = AsyncData(
      current.copyWith(pendingDeletions: [], isProcessingBatch: false),
    );
  }

  Future<void> restoreAll() async {
    final pendingDao = ref.read(pendingDeletionDaoProvider);
    await pendingDao.clearAll();

    final restored = state.value!.pendingDeletions;
    final updatedReview = [...state.value!.reviewFiles, ...restored]
      ..sort((a, b) => b.size.compareTo(a.size));

    state = AsyncData(
      state.value!.copyWith(
        reviewFiles: updatedReview,
        pendingDeletions: [],
      ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final swipeCleanupProvider =
    AsyncNotifierProvider<SwipeCleanupNotifier, SwipeCleanupState>(
  SwipeCleanupNotifier.new,
);
