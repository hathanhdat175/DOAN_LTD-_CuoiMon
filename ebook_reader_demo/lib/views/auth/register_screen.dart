import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../utils/password_policy.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common.dart';
import '../../widgets/password_field.dart';
import '../role_home.dart';

/// Màn hình Đăng ký: người dùng chọn vai trò Reader hoặc Publisher.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  UserRole _role = UserRole.reader;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final AuthViewModel auth = context.read<AuthViewModel>();
    if (auth.busy) {
      return;
    }
    final String? error = await auth.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      role: _role,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      showSnack(context, error);
      return;
    }
    showSnack(context, 'Đăng ký thành công!');
    goToHome(context, _role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar('Tạo tài khoản'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Bạn muốn dùng BookHub với vai trò nào?',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                SegmentedButton<UserRole>(
                  segments: const <ButtonSegment<UserRole>>[
                    ButtonSegment<UserRole>(
                      value: UserRole.reader,
                      icon: Icon(Icons.menu_book_outlined),
                      label: Text('Người đọc'),
                    ),
                    ButtonSegment<UserRole>(
                      value: UserRole.publisher,
                      icon: Icon(Icons.upload_file),
                      label: Text('Người đăng'),
                    ),
                  ],
                  selected: <UserRole>{_role},
                  onSelectionChanged: (Set<UserRole> selection) {
                    setState(() {
                      _role = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _role == UserRole.reader
                      ? 'Người đọc: đọc sách, tải về, lưu tiến độ và đánh dấu yêu thích.'
                      : 'Người đăng: đăng tải sách mới và theo dõi trạng thái duyệt.',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: fieldDecoration('Họ và tên', icon: Icons.person_outline),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Vui lòng nhập họ tên';
                    }
                    if ((value ?? '').trim().length > 100) {
                      return 'Họ tên tối đa 100 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
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
                  autofillHints: const <String>[AutofillHints.newPassword],
                  validator: (String? value) => PasswordPolicy.validate(value, email: _emailCtrl.text),
                ),
                PasswordChecklist(controller: _passwordCtrl),
                const SizedBox(height: 10),
                PasswordField(
                  controller: _confirmCtrl,
                  label: 'Nhập lại mật khẩu',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (String _) => _register(),
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) {
                      return 'Vui lòng nhập lại mật khẩu';
                    }
                    if (value != _passwordCtrl.text) {
                      return 'Mật khẩu nhập lại không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: context.watch<AuthViewModel>().busy ? null : _register,
                    child: context.watch<AuthViewModel>().busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                          )
                        : const Text('Đăng ký', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
