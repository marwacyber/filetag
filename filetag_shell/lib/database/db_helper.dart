import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/file_item.dart';
import '../models/tag.dart';

/// Single source of truth for the virtual-tagging layer.
/// IMPORTANT: this database never touches real files on disk.
/// It only stores references (paths) + tags. Moving/copying never happens.
class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  DBHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'filetag.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            extension TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            date_modified INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            color_value INTEGER NOT NULL
          )
        ''');

        // Many-to-many join table: one file <-> many tags, one tag <-> many files
        await db.execute('''
          CREATE TABLE file_tags (
            file_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            PRIMARY KEY (file_id, tag_id),
            FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ---------- FILES ----------

  /// Insert file reference if new; ignore if the path is already indexed.
  Future<int> upsertFile(FileItem file) async {
    final db = await database;
    return db.insert(
      'files',
      file.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<FileItem>> getAllFiles() async {
    final db = await database;
    final rows = await db.query('files', orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => FileItem.fromMap(r)).toList();
  }

  Future<void> deleteFileRecord(int fileId) async {
    final db = await database;
    await db.delete('files', where: 'id = ?', whereArgs: [fileId]);
  }

  /// Remove index entries whose real file no longer exists at that path.
  /// Call periodically (e.g. on app open) to keep the index honest.
  Future<int?> getFileIdByPath(String path) async {
    final db = await database;
    final rows = await db.query('files', where: 'path = ?', whereArgs: [path]);
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  // ---------- TAGS ----------

  Future<int> createTag(Tag tag) async {
    final db = await database;
    return db.insert(
      'tags',
      tag.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Tag>> getAllTags() async {
    final db = await database;
    final rows = await db.query('tags', orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => Tag.fromMap(r)).toList();
  }

  Future<void> deleteTag(int tagId) async {
    final db = await database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }

  // ---------- FILE <-> TAG LINKS (the core feature) ----------

  /// Attach a tag to a file. A file can have unlimited tags simultaneously
  /// -- this is what lets one exam paper live under "Physics" AND
  /// "Exams 2025" AND "Form Six" at once, with zero duplication on disk.
  Future<void> tagFile(int fileId, int tagId) async {
    final db = await database;
    await db.insert(
      'file_tags',
      {'file_id': fileId, 'tag_id': tagId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> untagFile(int fileId, int tagId) async {
    final db = await database;
    await db.delete(
      'file_tags',
      where: 'file_id = ? AND tag_id = ?',
      whereArgs: [fileId, tagId],
    );
  }

  /// All tags currently attached to one file.
  Future<List<Tag>> getTagsForFile(int fileId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT tags.* FROM tags
      INNER JOIN file_tags ON tags.id = file_tags.tag_id
      WHERE file_tags.file_id = ?
      ORDER BY tags.name COLLATE NOCASE
    ''', [fileId]);
    return rows.map((r) => Tag.fromMap(r)).toList();
  }

  /// The "virtual folder" query: every file that carries a given tag.
  Future<List<FileItem>> getFilesForTag(int tagId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT files.* FROM files
      INNER JOIN file_tags ON files.id = file_tags.file_id
      WHERE file_tags.tag_id = ?
      ORDER BY files.name COLLATE NOCASE
    ''', [tagId]);
    return rows.map((r) => FileItem.fromMap(r)).toList();
  }

  /// Files matching ALL given tags at once (e.g. Physics AND Exams 2025).
  Future<List<FileItem>> getFilesMatchingAllTags(List<int> tagIds) async {
    if (tagIds.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(tagIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT files.* FROM files
      INNER JOIN file_tags ON files.id = file_tags.file_id
      WHERE file_tags.tag_id IN ($placeholders)
      GROUP BY files.id
      HAVING COUNT(DISTINCT file_tags.tag_id) = ?
      ORDER BY files.name COLLATE NOCASE
    ''', [...tagIds, tagIds.length]);
    return rows.map((r) => FileItem.fromMap(r)).toList();
  }

  /// Files that have no tags at all yet -- your "inbox" of unsorted files.
  Future<List<FileItem>> getUntaggedFiles() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT files.* FROM files
      LEFT JOIN file_tags ON files.id = file_tags.file_id
      WHERE file_tags.file_id IS NULL
      ORDER BY files.name COLLATE NOCASE
    ''');
    return rows.map((r) => FileItem.fromMap(r)).toList();
  }

  // ---------- FOLDER BROWSING (over the index, real paths unchanged) ----------

  /// Files whose parent directory is exactly [dirPath].
  Future<List<FileItem>> getFilesInDirectory(String dirPath) async {
    final db = await database;
    final normalized = dirPath.endsWith('/') ? dirPath.substring(0, dirPath.length - 1) : dirPath;
    final rows = await db.query(
      'files',
      where: "path LIKE ? AND path NOT LIKE ?",
      whereArgs: ['$normalized/%', '$normalized/%/%'],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((r) => FileItem.fromMap(r)).toList();
  }

  /// Immediate subdirectory names that contain at least one indexed file
  /// directly under [dirPath] (at any depth below it).
  Future<List<String>> getSubdirectories(String dirPath) async {
    final db = await database;
    final normalized = dirPath.endsWith('/') ? dirPath.substring(0, dirPath.length - 1) : dirPath;
    final rows = await db.query(
      'files',
      columns: ['path'],
      where: 'path LIKE ?',
      whereArgs: ['$normalized/%'],
    );
    final subdirs = <String>{};
    for (final row in rows) {
      final path = row['path'] as String;
      final rest = path.substring(normalized.length + 1);
      final slashIndex = rest.indexOf('/');
      if (slashIndex > 0) {
        subdirs.add(rest.substring(0, slashIndex));
      }
    }
    final list = subdirs.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Global filename search across every indexed file, regardless of tags.
  Future<List<FileItem>> searchFiles(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    final rows = await db.query(
      'files',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name COLLATE NOCASE',
      limit: 100,
    );
    return rows.map((r) => FileItem.fromMap(r)).toList();
  }

  /// Search restricted to files already carrying [tagId] -- used for the
  /// search box inside a tag's virtual folder view.
  Future<List<FileItem>> searchFilesInTag(int tagId, String query) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT files.* FROM files
      INNER JOIN file_tags ON files.id = file_tags.file_id
      WHERE file_tags.tag_id = ? AND files.name LIKE ?
      ORDER BY files.name COLLATE NOCASE
    ''', [tagId, '%$query%']);
    return rows.map((r) => FileItem.fromMap(r)).toList();
  }
}
