import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../utils/password_policy.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/common.dart';
import '../widgets/password_field.dart';

/// Màn hình Đổi mật khẩu (mở từ tab Tài khoản của cả ba vai trò).
///
/// Gọi `PUT /api/me/password`. Đổi xong, các thiết bị khác đang đăng nhập
/// tài khoản này bị đăng xuất; thiết bị hiện tại nhận token mới.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final AuthViewModel auth = context.read<AuthViewModel>();
    if (auth.busy) {
      return;
    }
    final String? error = await auth.changePassword(_currentCtrl.text, _newCtrl.text);
    if (!mounted) {
      return;
    }
    if (error != null) {
      showSnack(context, error);
      return;
    }
    showSnack(context, 'Đã đổi mật khẩu. Các thiết bị khác đã được đăng xuất.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: buildAppBar('Đổi mật khẩu'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Sau khi đổi mật khẩu, tài khoản sẽ tự đăng xuất trên các thiết bị khác.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                PasswordField(
                  controller: _currentCtrl,
                  label: 'Mật khẩu hiện tại',
                  autofillHints: const <String>[AutofillHints.password],
                  validator: (String? value) =>
                      (value ?? '').isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _newCtrl,
                  label: 'Mật khẩu mới',
                  autofillHints: const <String>[AutofillHints.newPassword],
                  validator: (String? value) {
                    if (value != null && value.isNotEmpty && value == _currentCtrl.text) {
                      return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                    }
                    return PasswordPolicy.validate(value, email: auth.currentUser?.email);
                  },
                ),
                PasswordChecklist(controller: _newCtrl),
                const SizedBox(height: 10),
                PasswordField(
                  controller: _confirmCtrl,
                  label: 'Nhập lại mật khẩu mới',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (String _) => _submit(),
                  validator: (String? value) {
                    if ((value ?? '').isEmpty) {
                      return 'Vui lòng nhập lại mật khẩu mới';
                    }
                    if (value != _newCtrl.text) {
                      return 'Mật khẩu nhập lại không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: auth.busy ? null : _submit,
                    child: auth.busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                          )
                        : const Text('Đổi mật khẩu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
