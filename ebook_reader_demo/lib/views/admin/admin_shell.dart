import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/notice_watcher.dart';
import '../notifications_screen.dart';
import '../profile_screen.dart';
import 'admin_dashboard.dart';
import 'approval_screen.dart';
import 'categories_screen.dart';
import 'users_screen.dart';

/// Khung chính của vai trò Admin: 5 tab ở thanh điều hướng dưới.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        context.read<AdminViewModel>().loadAll();
      }
    });
  }

  void _goTo(int index) {
    setState(() {
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NoticeWatcher(
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: <Widget>[
            AdminDashboard(onOpenTab: _goTo),
            const ApprovalScreen(),
            const UsersScreen(),
            const CategoriesScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Consumer<AdminViewModel>(
        builder: (BuildContext context, AdminViewModel vm, Widget? _) {
            final int pending = vm.countByStatus(BookStatus.pending);

            return NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _goTo,
              destinations: <Widget>[
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Tổng quan',
                ),
                // Huy hiệu số sách đang chờ duyệt
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pending > 0,
                    label: Text('$pending'),
                    child: const Icon(Icons.fact_check_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: pending > 0,
                    label: Text('$pending'),
                    child: const Icon(Icons.fact_check),
                  ),
                  label: 'Duyệt sách',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Người dùng',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: 'Thể loại',
                ),
                const NavigationDestination(
                  icon: NoticeBadgeIcon(icon: Icons.person_outline),
                  selectedIcon: NoticeBadgeIcon(icon: Icons.person),
                  label: 'Tài khoản',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
