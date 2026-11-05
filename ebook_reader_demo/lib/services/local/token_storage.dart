import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi lưu JWT trên thiết bị để lần sau mở ứng dụng không phải đăng nhập lại.
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String? token);
}

/// Lưu JWT bằng flutter_secure_storage (Keystore trên Android, mã hóa trên web).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'bookhub_jwt';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String? token) async {
    try {
      if (token == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: token);
      }
    } catch (_) {
      // Không lưu được token thì lần sau chỉ cần đăng nhập lại.
    }
  }
}

/// Lưu JWT trong bộ nhớ (dùng cho kiểm thử).
class MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String? token) async => _token = token;
}
