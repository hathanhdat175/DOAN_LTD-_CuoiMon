import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../role_home.dart';
import 'login_screen.dart';

/// Màn hình chào (Splash): hiện logo khoảng 1,6 giây; nếu trên máy còn JWT hợp lệ
/// thì vào thẳng màn hình chính theo vai trò, ngược lại chuyển sang Đăng nhập.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), _goNext);
  }

  Future<void> _goNext() async {
    if (!mounted) {
      return;
    }
    final AppUser? user = await context.read<AuthViewModel>().restoreSession();
    if (!mounted) {
      return;
    }
    if (user != null) {
      goToHome(context, user.role);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (BuildContext _) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Spacer(flex: 3),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.auto_stories, size: 56, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            const Text(
              'BookHub',
              style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Đọc sách mọi lúc, mọi nơi',
              style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 15),
            ),
            const Spacer(flex: 3),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              'Nhóm 10 · Đồ án Phát triển ứng dụng di động',
              style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
