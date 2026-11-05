import 'dart:typed_data';

import 'pdf_file_store.dart';

PdfFileStore createStore() => MemoryPdfFileStore();

/// Lưu file PDF trong bộ nhớ (bản web và kiểm thử).
class MemoryPdfFileStore implements PdfFileStore {
  final Map<String, Uint8List> _files = <String, Uint8List>{};

  @override
  Future<void> save(String userId, String bookId, Uint8List bytes) async => _files['$userId/$bookId'] = bytes;

  @override
  Future<Uint8List?> read(String userId, String bookId) async => _files['$userId/$bookId'];

  @override
  Future<void> delete(String userId, String bookId) async => _files.remove('$userId/$bookId');
}
