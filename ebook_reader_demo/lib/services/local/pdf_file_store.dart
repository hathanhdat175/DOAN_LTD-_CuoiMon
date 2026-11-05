import 'dart:typed_data';

import 'pdf_file_store_memory.dart' if (dart.library.io) 'pdf_file_store_io.dart' as impl;

/// Nơi lưu file PDF đã tải về để đọc offline.
///
/// - Android / iOS: thư mục tài liệu của ứng dụng (path_provider).
/// - Web: giữ trong bộ nhớ (mất khi tải lại trang).
abstract class PdfFileStore {
  /// Tạo bản cài đặt phù hợp với nền tảng đang chạy.
  factory PdfFileStore() => impl.createStore();

  Future<void> save(String userId, String bookId, Uint8List bytes);
  Future<Uint8List?> read(String userId, String bookId);
  Future<void> delete(String userId, String bookId);
}
