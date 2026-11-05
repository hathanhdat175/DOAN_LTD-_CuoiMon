import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';

/// Sách đã tải về máy (đọc offline).
class DownloadedBook {
  DownloadedBook({required this.book, required this.savedAt});

  final Book book;
  final DateTime savedAt;
}

/// Tiến độ đọc lưu trên máy; [synced] = false nghĩa là chưa gửi được lên máy chủ.
class LocalProgress {
  LocalProgress({required this.bookId, required this.page, required this.updatedAt, required this.synced});

  final String bookId;
  final int page;
  final DateTime updatedAt;
  final bool synced;
}

/// CSDL cục bộ trên thiết bị (SQLite – sqflite): danh sách sách đã tải về và
/// tiến độ đọc chờ đồng bộ khi mất mạng.
abstract class LocalCache {
  Future<List<DownloadedBook>> downloads(String userId);
  Future<void> saveDownload(String userId, Book book);
  Future<void> removeDownload(String userId, String bookId);

  Future<List<LocalProgress>> progress(String userId);
  Future<void> saveProgress(String userId, String bookId, int page, {required bool synced});
  Future<void> markSynced(String userId, String bookId);
}

/// Cài đặt bằng sqflite (Android / iOS).
class SqfliteLocalCache implements LocalCache {
  Database? _db;

  Future<Database> _open() async {
    final Database? existing = _db;
    if (existing != null) {
      return existing;
    }
    final String path = '${await getDatabasesPath()}/bookhub_cache.db';
    final Database db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE downloads (
            user_id TEXT NOT NULL,
            book_id TEXT NOT NULL,
            book_json TEXT NOT NULL,
            saved_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, book_id)
          )''');
        await db.execute('''
          CREATE TABLE progress (
            user_id TEXT NOT NULL,
            book_id TEXT NOT NULL,
            page INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (user_id, book_id)
          )''');
      },
    );
    _db = db;
    return db;
  }

  @override
  Future<List<DownloadedBook>> downloads(String userId) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows =
        await db.query('downloads', where: 'user_id = ?', whereArgs: <Object>[userId], orderBy: 'saved_at DESC');
    return rows
        .map((Map<String, Object?> r) => DownloadedBook(
              book: Book.fromJson(jsonDecode(r['book_json']! as String) as Map<String, dynamic>),
              savedAt: DateTime.fromMillisecondsSinceEpoch(r['saved_at']! as int),
            ))
        .toList();
  }

  @override
  Future<void> saveDownload(String userId, Book book) async {
    final Database db = await _open();
    await db.insert(
      'downloads',
      <String, Object?>{
        'user_id': userId,
        'book_id': book.id,
        'book_json': jsonEncode(book.toJson()),
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeDownload(String userId, String bookId) async {
    final Database db = await _open();
    await db.delete('downloads', where: 'user_id = ? AND book_id = ?', whereArgs: <Object>[userId, bookId]);
  }

  @override
  Future<List<LocalProgress>> progress(String userId) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows =
        await db.query('progress', where: 'user_id = ?', whereArgs: <Object>[userId]);
    return rows
        .map((Map<String, Object?> r) => LocalProgress(
              bookId: r['book_id']! as String,
              page: r['page']! as int,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at']! as int),
              synced: r['synced'] == 1,
            ))
        .toList();
  }

  @override
  Future<void> saveProgress(String userId, String bookId, int page, {required bool synced}) async {
    final Database db = await _open();
    await db.insert(
      'progress',
      <String, Object?>{
        'user_id': userId,
        'book_id': bookId,
        'page': page,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'synced': synced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> markSynced(String userId, String bookId) async {
    final Database db = await _open();
    await db.update('progress', <String, Object?>{'synced': 1},
        where: 'user_id = ? AND book_id = ?', whereArgs: <Object>[userId, bookId]);
  }
}

/// Cài đặt trong bộ nhớ: dùng cho bản web (trình duyệt không có sqflite) và kiểm thử.
class MemoryLocalCache implements LocalCache {
  final Map<String, Map<String, DownloadedBook>> _downloads = <String, Map<String, DownloadedBook>>{};
  final Map<String, Map<String, LocalProgress>> _progress = <String, Map<String, LocalProgress>>{};

  @override
  Future<List<DownloadedBook>> downloads(String userId) async {
    final List<DownloadedBook> list = (_downloads[userId] ?? <String, DownloadedBook>{}).values.toList()
      ..sort((DownloadedBook a, DownloadedBook b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  @override
  Future<void> saveDownload(String userId, Book book) async {
    _downloads.putIfAbsent(userId, () => <String, DownloadedBook>{})[book.id] =
        DownloadedBook(book: book, savedAt: DateTime.now());
  }

  @override
  Future<void> removeDownload(String userId, String bookId) async {
    _downloads[userId]?.remove(bookId);
  }

  @override
  Future<List<LocalProgress>> progress(String userId) async =>
      (_progress[userId] ?? <String, LocalProgress>{}).values.toList();

  @override
  Future<void> saveProgress(String userId, String bookId, int page, {required bool synced}) async {
    _progress.putIfAbsent(userId, () => <String, LocalProgress>{})[bookId] =
        LocalProgress(bookId: bookId, page: page, updatedAt: DateTime.now(), synced: synced);
  }

  @override
  Future<void> markSynced(String userId, String bookId) async {
    final LocalProgress? p = _progress[userId]?[bookId];
    if (p != null) {
      _progress[userId]![bookId] = LocalProgress(bookId: bookId, page: p.page, updatedAt: p.updatedAt, synced: true);
    }
  }
}
