import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/reader_viewmodel.dart';
import '../widgets/common.dart';
import 'auth/login_screen.dart';
import 'notifications_screen.dart';
import 'reader/downloads_screen.dart';
import 'reader/reader_shell.dart';

/// Tab Tài khoản (dùng chung cho cả ba vai trò): thông tin người dùng,
/// thông báo hệ thống / kết quả duyệt sách và nút Đăng xuất.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        context.read<ReaderViewModel>().loadNotices();
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    final bool ok = await confirmDialog(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc muốn đăng xuất khỏi tài khoản này?',
      okLabel: 'Đăng xuất',
    );
    if (!ok || !context.mounted) {
      return;
    }
    // Xóa JWT khỏi thiết bị rồi về màn hình Đăng nhập.
    final NavigatorState nav = Navigator.of(context);
    await context.read<AuthViewModel>().logout();
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (BuildContext _) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => const NotificationsScreen()),
    );
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(' ');
    if (parts.isEmpty || parts.last.isEmpty) {
      return '?';
    }
    return parts.last.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Consumer2 lắng nghe cùng lúc hai ViewModel: thông tin tài khoản và dữ liệu đọc sách.
    return Consumer2<AuthViewModel, ReaderViewModel>(
      builder: (BuildContext context, AuthViewModel auth, ReaderViewModel vm, Widget? _) {
        final AppUser? user = auth.currentUser;
        if (user == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        return Scaffold(
          appBar: buildAppBar('Tài khoản'),
          body: RefreshIndicator(
            onRefresh: vm.loadNotices,
            child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              AppCard(
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        _initials(user.name),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(user.email, style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 8),
                          Pill(
                            text: '${user.role.code} · ${user.role.label}',
                            color: AppColors.primary,
                            icon: Icons.verified_user_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.event_outlined, color: AppColors.primary),
                      title: const Text('Ngày tham gia'),
                      trailing: Text(formatDate(user.joinedAt), style: const TextStyle(color: AppColors.muted)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                    ListTile(
                      leading: Badge(
                        isLabelVisible: vm.unreadNotices > 0,
                        label: Text('${vm.unreadNotices}'),
                        child: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                      ),
                      title: const Text('Thông báo'),
                      subtitle: Text(
                        vm.unreadNotices > 0 ? '${vm.unreadNotices} thông báo chưa đọc' : 'Không có thông báo mới',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openNotifications(context),
                    ),
                    // Mọi vai trò đều đọc sách được nên đều có thống kê đọc sách.
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                    ListTile(
                      leading: const Icon(Icons.download_done, color: AppColors.primary),
                      title: const Text('Sách đã tải về'),
                      subtitle: const Text('Đọc khi không có mạng'),
                      trailing: Text(
                        '${vm.downloadCount} cuốn',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (BuildContext _) => const DownloadsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                    ListTile(
                      leading: const Icon(Icons.favorite_border, color: AppColors.primary),
                      title: const Text('Sách yêu thích'),
                      trailing: Text(
                        '${vm.favoriteBooks.length} cuốn',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    if (user.role != UserRole.reader) ...<Widget>[
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                      ListTile(
                        leading: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
                        title: const Text('Đọc sách'),
                        subtitle: const Text('Trang chủ, yêu thích và lịch sử đọc'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => openReaderLibrary(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionTitle(
                'Thông báo hệ thống',
                trailing: TextButton(
                  onPressed: () => _openNotifications(context),
                  child: Text(vm.unreadNotices > 0 ? 'Xem tất cả (${vm.unreadNotices} mới)' : 'Xem tất cả'),
                ),
              ),
              const SizedBox(height: 10),
              if (vm.notices.isEmpty)
                const AppCard(
                  child: Text('Chưa có thông báo nào.', style: TextStyle(color: AppColors.muted)),
                )
              else
                // Ba thông báo mới nhất; xem đầy đủ ở màn hình Thông báo.
                for (final AppNotice notice in vm.notices.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NoticeTile(notice: notice),
                  ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: auth.busy ? null : () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'BookHub · Nhóm 10',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}
