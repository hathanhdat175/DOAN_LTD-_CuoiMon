import 'package:flutter/material.dart';

/// Bảng màu dùng chung cho toàn ứng dụng.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2F5D50); // xanh rừng
  static const Color primaryDark = Color(0xFF1D3B33);
  static const Color primarySoft = Color(0xFFE3EEE9);
  static const Color accent = Color(0xFFE0A33B); // vàng hổ phách
  static const Color ink = Color(0xFF1C2523); // màu chữ chính
  static const Color muted = Color(0xFF6B7773); // màu chữ phụ
  static const Color background = Color(0xFFF5F6F3);
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE2E5E0);
  static const Color success = Color(0xFF2E7D4F);
  static const Color warning = Color(0xFFB9770E);
  static const Color danger = Color(0xFFB8452F);
}

/// Theme Material 3 của ứng dụng.
ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.card,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
  );
}

/// Kiểu ô nhập liệu dùng chung (bo góc, nền trắng).
InputDecoration fieldDecoration(
  String label, {
  IconData? icon,
  String? hint,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.card,
    border: border(AppColors.line, 1),
    enabledBorder: border(AppColors.line, 1),
    focusedBorder: border(AppColors.primary, 1.6),
    errorBorder: border(AppColors.danger, 1),
    focusedErrorBorder: border(AppColors.danger, 1.6),
  );
}
