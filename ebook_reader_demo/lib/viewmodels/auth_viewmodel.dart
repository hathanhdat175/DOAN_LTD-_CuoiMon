import '../models/models.dart';
import '../services/auth_service.dart';
import 'base_viewmodel.dart';

/// ViewModel cho Đăng nhập / Đăng ký / Hồ sơ.
class AuthViewModel extends BaseViewModel {
  AuthViewModel(this._auth) : super(_auth.changes);

  final AuthService _auth;

  AppUser? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  /// Đang gửi yêu cầu đăng nhập / đăng ký (để View khóa nút bấm).
  bool busy = false;

  Future<String?> _busy(Future<String?> Function() task) async {
    busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Trả về `null` nếu thành công, ngược lại trả về thông báo lỗi.
  Future<String?> login(String email, String password) => _busy(() => _auth.login(email, password));

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) {
    return _busy(() => _auth.register(name: name, email: email, password: password, role: role));
  }

  /// Đổi mật khẩu; trả về `null` nếu thành công.
  Future<String?> changePassword(String currentPassword, String newPassword) =>
      _busy(() => _auth.changePassword(currentPassword, newPassword));

  /// Dùng ở màn hình Splash: đăng nhập lại bằng token đã lưu.
  Future<AppUser?> restoreSession() => _auth.restoreSession();

  Future<void> logout() => _auth.logout();
}
