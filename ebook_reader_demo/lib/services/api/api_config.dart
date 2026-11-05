import 'package:flutter/foundation.dart';

/// Địa chỉ máy chủ REST API.
///
/// Đổi khi chạy:  flutter run --dart-define=API_URL=http://192.168.1.10:3000
/// Mặc định: web / máy tính dùng localhost, máy ảo Android dùng 10.0.2.2
/// (địa chỉ của máy tính chạy máy ảo).
class ApiConfig {
  static const String _fromEnv = String.fromEnvironment('API_URL');

  /// Chạy bằng dữ liệu giả lập trong bộ nhớ (không cần máy chủ):
  /// flutter run --dart-define=USE_MOCK=true
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) {
      return _fromEnv;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
