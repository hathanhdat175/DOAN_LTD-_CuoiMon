import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'pdf_file_store.dart';
import 'pdf_file_store_memory.dart';

PdfFileStore createStore() => IoPdfFileStore();

/// Lưu file PDF vào thư mục tài liệu của ứng dụng: <documents>/books/<user>_<book>.pdf
class IoPdfFileStore implements PdfFileStore {
  final MemoryPdfFileStore _fallback = MemoryPdfFileStore();

  Future<File?> _file(String userId, String bookId) async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final Directory books = Directory('${dir.path}${Platform.pathSeparator}books');
      if (!books.existsSync()) {
        await books.create(recursive: true);
      }
      return File('${books.path}${Platform.pathSeparator}${userId}_$bookId.pdf');
    } catch (_) {
      return null; // Môi trường không có path_provider (ví dụ khi chạy test).
    }
  }

  @override
  Future<void> save(String userId, String bookId, Uint8List bytes) async {
    final File? f = await _file(userId, bookId);
    if (f == null) {
      return _fallback.save(userId, bookId, bytes);
    }
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read(String userId, String bookId) async {
    final File? f = await _file(userId, bookId);
    if (f == null) {
      return _fallback.read(userId, bookId);
    }
    return f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String userId, String bookId) async {
    final File? f = await _file(userId, bookId);
    if (f == null) {
      return _fallback.delete(userId, bookId);
    }
    if (f.existsSync()) {
      await f.delete();
    }
  }
}
