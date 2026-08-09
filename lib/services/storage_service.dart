import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../models/file_item.dart';
import '../database/db_helper.dart';

/// Handles Android 13 storage permissions and scans real storage
/// to build/refresh the file index. Never moves, copies, or deletes
/// the actual files -- only reads metadata (path, name, size, date).
class StorageService {
  /// Android 13 note:
  /// READ_MEDIA_IMAGES / VIDEO / AUDIO only cover media files.
  /// A general file manager (PDFs, docs, zips, etc.) still needs
  /// MANAGE_EXTERNAL_STORAGE ("All files access"), which requires
  /// the user to flip a switch in system Settings the first time.
  Future<bool> requestAccess() async {
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  Future<bool> hasAccess() async {
    return Permission.manageExternalStorage.status.isGranted;
  }

  /// Directories to skip while scanning (system/cache noise).
  static const _skipDirNames = {
    'Android',
    '.thumbnails',
    '.cache',
    '.trash',
    'cache',
  };

  /// Recursively scans [rootPath] (default: shared storage root) and
  /// upserts every file found into the local index. Safe to re-run --
  /// existing paths are skipped, not duplicated.
  Future<int> scanAndIndex({
    String rootPath = '/storage/emulated/0',
    void Function(int count)? onProgress,
  }) async {
    final db = DBHelper.instance;
    int count = 0;
    final root = Directory(rootPath);
    if (!await root.exists()) return 0;

    final stack = <Directory>[root];

    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      List<FileSystemEntity> entities;
      try {
        entities = dir.listSync();
      } catch (_) {
        continue; // permission-denied subfolders, skip quietly
      }

      for (final entity in entities) {
        final baseName = entity.path.split('/').last;

        if (entity is Directory) {
          if (_skipDirNames.contains(baseName)) continue;
          stack.add(entity);
          continue;
        }

        if (entity is File) {
          try {
            final stat = await entity.stat();
            final ext = baseName.contains('.')
                ? baseName.split('.').last.toLowerCase()
                : '';

            final item = FileItem(
              path: entity.path,
              name: baseName,
              extension: ext,
              sizeBytes: stat.size,
              dateModified: stat.modified.millisecondsSinceEpoch,
            );

            await db.upsertFile(item);
            count++;
            if (onProgress != null && count % 50 == 0) onProgress(count);
          } catch (_) {
            continue; // unreadable file, skip
          }
        }
      }
    }

    return count;
  }

  /// Drops index entries whose underlying file was deleted/moved
  /// outside the app. Keeps virtual folders honest over time.
  Future<int> pruneMissingFiles() async {
    final db = DBHelper.instance;
    final all = await db.getAllFiles();
    int removed = 0;
    for (final f in all) {
      if (!await File(f.path).exists()) {
        await db.deleteFileRecord(f.id!);
        removed++;
      }
    }
    return removed;
  }
}
