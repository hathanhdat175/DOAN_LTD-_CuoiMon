import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api/bookhub_api.dart';
import 'app_store.dart';

/// Xử lý đăng nhập, đăng ký, đăng xuất.
///
/// Gọi `POST /api/auth/login`, `POST /api/auth/register`, lưu JWT trả về bằng
/// flutter_secure_storage và đính kèm token vào mọi request sau đó.
class AuthService {
  AuthService(this._store);

  final AppStore _store;

  /// Nguồn phát tín hiệu khi dữ liệu thay đổi (ViewModel lắng nghe).
  Listenable get changes => _store;

  AppUser? get currentUser => _store.currentUser;

  Future<void> _startSession(AuthResult result) async {
    _store.clearSession();
    _store.api.token = result.token;
    _store.currentUser = result.user;
    await _store.tokens.write(result.token);
    _store.commit();
  }

  /// Trả về `null` nếu thành công, ngược lại trả về thông báo lỗi.
  Future<String?> login(String email, String password) async {
    try {
      await _startSession(await _store.api.login(email.trim(), password));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Đăng ký tài khoản Reader hoặc Publisher rồi đăng nhập luôn.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      await _startSession(
        await _store.api.register(name: name.trim(), email: email.trim(), password: password, role: role),
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Đổi mật khẩu: lưu token mới do máy chủ trả về (giữ nguyên dữ liệu của phiên).
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      final AuthResult result = await _store.api.changePassword(currentPassword, newPassword);
      _store.api.token = result.token;
      _store.currentUser = result.user;
      await _store.tokens.write(result.token);
      _store.commit();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Mở lại phiên đăng nhập từ token đã lưu (màn hình Splash).
  /// Trả về người dùng nếu token còn hợp lệ, ngược lại xóa token và trả về null.
  Future<AppUser?> restoreSession() async {
    final String? token = await _store.tokens.read();
    if (token == null || token.isEmpty) {
      return null;
    }
    _store.api.token = token;
    try {
      final AppUser user = await _store.api.me();
      _store.currentUser = user;
      _store.commit();
      return user;
    } on ApiException catch (e) {
      _store.api.token = null;
      if (!e.isNetworkError) {
        await _store.tokens.write(null); // token hết hạn hoặc tài khoản bị khóa
      }
      return null;
    }
  }

  /// Xóa token khỏi thiết bị và toàn bộ dữ liệu của phiên.
  Future<void> logout() async {
    _store.clearSession();
    await _store.tokens.write(null);
    _store.commit();
  }
}
