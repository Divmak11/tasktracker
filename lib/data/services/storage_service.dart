import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Service for uploading and managing task attachment images in Firebase Storage.
///
/// Handles:
/// - Client-side image compression (via ImagePicker quality settings)
/// - Upload with progress tracking and cancellation
/// - Deletion of individual files or entire task attachment folders
/// - Orphan cleanup on failed operations
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// Maximum number of attachments per task
  static const int maxAttachments = 3;


  /// Pick images from gallery with compression applied.
  ///
  /// Returns a list of [XFile] with at most [remaining] items.
  /// Images are compressed to 70% quality, max 1920px width.
  /// Uses a [_isPickerOpen] guard to prevent double-tap rapid opens.
  static bool _isPickerOpen = false;

  static Future<List<XFile>> pickImages({required int remaining}) async {
    if (_isPickerOpen || remaining <= 0) return [];
    _isPickerOpen = true;

    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1920,
        limit: remaining,
      );
      return images.take(remaining).toList();
    } finally {
      _isPickerOpen = false;
    }
  }

  /// Upload a single image file to Firebase Storage for a given task.
  ///
  /// Path: `tasks/{taskId}/attachments/{uuid}.jpg`
  ///
  /// Returns a record containing:
  /// - `downloadUrl`: The public download URL
  /// - `uploadTask`: The [UploadTask] for cancellation support
  static ({String path, UploadTask uploadTask}) startUpload({
    required String taskId,
    required File file,
  }) {
    final fileId = _uuid.v4();
    final storagePath = 'tasks/$taskId/attachments/$fileId.jpg';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'taskId': taskId},
    );

    final uploadTask = ref.putFile(file, metadata);
    return (path: storagePath, uploadTask: uploadTask);
  }

  /// Upload multiple files and return their download URLs.
  ///
  /// Supports cancellation via the returned [UploadTask] list.
  /// On failure, cleans up any already-uploaded files (orphan prevention).
  ///
  /// [onProgress] is called with (completedCount, totalCount) for UI updates.
  static Future<List<String>> uploadAll({
    required String taskId,
    required List<File> files,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (files.isEmpty) return [];

    // Declared outside try so catch can access them for cleanup
    final results = files.map((file) => startUpload(taskId: taskId, file: file)).toList();

    try {
      int completedCount = 0;

      // Await all uploads in parallel
      final snapshots = await Future.wait(
        results.map((result) async {
          final snapshot = await result.uploadTask;
          completedCount++;
          onProgress?.call(completedCount, files.length);
          return (snapshot: snapshot, path: result.path);
        }),
      );

      // Collect download URLs in order
      final downloadUrls = await Future.wait(
        snapshots.map((s) => s.snapshot.ref.getDownloadURL()),
      );

      return downloadUrls;
    } catch (e) {
      // Orphan cleanup: delete any files that were uploaded before the failure
      final uploadedPaths = results.map((r) => r.path).toList();
      await _cleanupPaths(uploadedPaths);

      // Cancel any in-progress uploads
      for (final result in results) {
        result.uploadTask.cancel();
      }

      rethrow;
    }
  }

  /// Delete a single file from Storage by its download URL.
  static Future<void> deleteByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } on FirebaseException catch (e) {
      // Ignore "object not found" errors
      if (e.code != 'object-not-found') rethrow;
    }
  }

  /// Delete all attachments for a task (entire folder).
  static Future<void> deleteAllForTask(String taskId) async {
    try {
      final ref = _storage.ref().child('tasks/$taskId/attachments');
      final listResult = await ref.listAll();
      final futures = listResult.items.map((item) => item.delete());
      await Future.wait(futures);
    } on FirebaseException catch (e) {
      // Ignore if folder doesn't exist
      debugPrint('StorageService: cleanup failed for task $taskId: ${e.message}');
    }
  }

  /// Internal: clean up paths that were uploaded during a failed batch upload.
  static Future<void> _cleanupPaths(List<String> paths) async {
    for (final path in paths) {
      try {
        await _storage.ref().child(path).delete();
      } catch (_) {
        // Best-effort cleanup, ignore individual failures
      }
    }
  }
}

/// Custom exception for storage upload errors with user-friendly messages.
class StorageUploadException implements Exception {
  final String message;
  const StorageUploadException(this.message);

  @override
  String toString() => message;
}
