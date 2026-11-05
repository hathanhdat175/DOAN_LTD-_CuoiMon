/// Chính sách mật khẩu – giống `backend/src/utils/password.js` của máy chủ.
///
/// Mật khẩu mới (đăng ký, đổi mật khẩu) phải có ít nhất 8 ký tự, gồm chữ hoa,
/// chữ thường, chữ số và ký tự đặc biệt; không có khoảng trắng.
class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String password) test;
}

class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 8;
  static const int maxLength = 64;

  static final RegExp _upper = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _lower = RegExp(r'\p{Ll}', unicode: true);
  static final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);
  static final RegExp _special = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final RegExp _space = RegExp(r'\s');

  /// Các điều kiện hiển thị dạng danh sách kiểm tra bên dưới ô mật khẩu.
  static final List<PasswordRule> rules = <PasswordRule>[
    PasswordRule('Ít nhất $minLength ký tự', (String p) => p.runes.length >= minLength),
    PasswordRule('Có chữ hoa (A–Z)', (String p) => _upper.hasMatch(p)),
    PasswordRule('Có chữ thường (a–z)', (String p) => _lower.hasMatch(p)),
    PasswordRule('Có chữ số (0–9)', (String p) => _digit.hasMatch(p)),
    PasswordRule('Có ký tự đặc biệt (@ # \$ ! % …)', (String p) => _special.hasMatch(p)),
  ];

  /// Số điều kiện đã đạt (0 – [rules].length), dùng cho thanh độ mạnh.
  static int score(String password) => rules.where((PasswordRule r) => r.test(password)).length;

  /// Trả về thông báo lỗi, hoặc `null` nếu mật khẩu đạt yêu cầu.
  static String? validate(String? value, {String? email}) {
    final String p = value ?? '';
    if (p.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (p.runes.length > maxLength) {
      return 'Mật khẩu tối đa $maxLength ký tự';
    }
    if (_space.hasMatch(p)) {
      return 'Mật khẩu không được chứa khoảng trắng';
    }
    final List<String> missing = <String>[
      for (final PasswordRule r in rules)
        if (!r.test(p)) r.label.toLowerCase(),
    ];
    if (missing.isNotEmpty) {
      return 'Mật khẩu chưa đủ mạnh: ${missing.join(', ')}';
    }
    final String name = (email ?? '').trim().toLowerCase().split('@').first;
    if (name.length >= 4 && p.toLowerCase().contains(name)) {
      return 'Mật khẩu không được chứa tên email của bạn';
    }
    return null;
  }
}
