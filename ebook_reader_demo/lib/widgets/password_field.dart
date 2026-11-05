import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../utils/password_policy.dart';

/// Ô nhập mật khẩu có nút con mắt để ẩn / hiện mật khẩu.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Mật khẩu',
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      decoration: fieldDecoration(
        widget.label,
        icon: Icons.lock_outline,
        suffix: IconButton(
          tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// Thanh độ mạnh và danh sách điều kiện mật khẩu, cập nhật ngay khi người dùng gõ.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.controller});

  final TextEditingController controller;

  static const List<String> _levels = <String>['Rất yếu', 'Rất yếu', 'Yếu', 'Trung bình', 'Khá', 'Mạnh'];
  static const List<Color> _colors = <Color>[
    AppColors.danger,
    AppColors.danger,
    AppColors.danger,
    AppColors.warning,
    AppColors.warning,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        final String p = value.text;
        final int score = PasswordPolicy.score(p);
        final int total = PasswordPolicy.rules.length;
        final Color color = p.isEmpty ? AppColors.line : _colors[score];
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: p.isEmpty ? 0 : score / total,
                        minHeight: 6,
                        color: color,
                        backgroundColor: AppColors.line,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p.isEmpty ? 'Độ mạnh' : _levels[score],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.isEmpty ? AppColors.muted : color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final PasswordRule r in PasswordPolicy.rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        r.test(p) ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: r.test(p) ? AppColors.success : AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.label,
                          style: TextStyle(fontSize: 13, color: r.test(p) ? AppColors.success : AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
