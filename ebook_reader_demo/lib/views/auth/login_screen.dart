import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common.dart';
import '../../widgets/password_field.dart';
import '../role_home.dart';
import 'register_screen.dart';

/// Mật khẩu của các tài khoản demo (đạt chính sách mật khẩu: chữ hoa, chữ thường, số, ký tự đặc biệt).
const String demoPassword = 'Demo@123';

/// Màn hình Đăng nhập.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final AuthViewModel auth = context.read<AuthViewModel>();
    if (auth.busy) {
      return;
    }
    final String? error = await auth.login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) {
      return;
    }
    if (error != null) {
      showSnack(context, error);
      return;
    }
    final AppUser? user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      goToHome(context, user.role);
    }
  }

  /// Điền sẵn tài khoản demo rồi đăng nhập.
  void _quickLogin(String email) {
    _emailCtrl.text = email;
    _passwordCtrl.text = demoPassword;
    _login();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.auto_stories, color: AppColors.accent, size: 32),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chào mừng trở lại',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đăng nhập để tiếp tục đọc sách cùng BookHub.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: fieldDecoration('Email', icon: Icons.email_outlined),
                  validator: (String? value) {
                    final String text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    if (!text.contains('@') || !text.contains('.')) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordCtrl,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.password],
                  onSubmitted: (String _) => _login(),
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: context.watch<AuthViewModel>().busy ? null : _login,
                    child: context.watch<AuthViewModel>().busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                          )
                        : const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                // Wrap tự xuống dòng khi màn hình hẹp hoặc cỡ chữ lớn, tránh tràn chữ.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    const Text('Chưa có tài khoản?', style: TextStyle(color: AppColors.muted)),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (BuildContext _) => const RegisterScreen()),
                        );
                      },
                      child: const Text('Đăng ký'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppCard(
                  color: AppColors.primarySoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Tài khoản demo',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bấm để đăng nhập nhanh theo từng vai trò (mật khẩu: $demoPassword).',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      _DemoAccountTile(
                        icon: Icons.menu_book_outlined,
                        role: 'Reader – Người đọc',
                        email: 'reader@demo.com',
                        onTap: () => _quickLogin('reader@demo.com'),
                      ),
                      const SizedBox(height: 8),
                      _DemoAccountTile(
                        icon: Icons.upload_file,
                        role: 'Publisher – Người đăng',
                        email: 'publisher@demo.com',
                        onTap: () => _quickLogin('publisher@demo.com'),
                      ),
                      const SizedBox(height: 8),
                      _DemoAccountTile(
                        icon: Icons.admin_panel_settings_outlined,
                        role: 'Admin – Quản trị viên',
                        email: 'admin@demo.com',
                        onTap: () => _quickLogin('admin@demo.com'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoAccountTile extends StatelessWidget {
  const _DemoAccountTile({
    required this.icon,
    required this.role,
    required this.email,
    required this.onTap,
  });

  final IconData icon;
  final String role;
  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(role, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                Text(email, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}
