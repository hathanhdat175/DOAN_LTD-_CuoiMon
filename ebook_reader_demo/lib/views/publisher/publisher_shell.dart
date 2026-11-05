import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/publisher_viewmodel.dart';
import '../../widgets/notice_watcher.dart';
import '../notifications_screen.dart';
import '../profile_screen.dart';
import 'my_books_screen.dart';
import 'publisher_dashboard.dart';
import 'upload_book_screen.dart';

/// Khung chính của vai trò Publisher: Tổng quan, Sách của tôi, Tài khoản.
class PublisherShell extends StatefulWidget {
  const PublisherShell({super.key});

  @override
  State<PublisherShell> createState() => _PublisherShellState();
}

class _PublisherShellState extends State<PublisherShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        context.read<PublisherViewModel>().loadMyBooks();
      }
    });
  }

  void _openUpload() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => const UploadBookScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NoticeWatcher(
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: <Widget>[
            PublisherDashboard(
              onSeeAll: () {
                setState(() {
                  _index = 1;
                });
              },
            ),
            const MyBooksScreen(),
            const ProfileScreen(),
          ],
        ),
        // Nút nổi "Đăng sách" hiện ở 2 tab đầu.
        floatingActionButton: _index == 2
            ? null
            : FloatingActionButton.extended(
                onPressed: _openUpload,
                icon: const Icon(Icons.add),
                label: const Text('Đăng sách'),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (int i) {
            setState(() {
              _index = i;
            });
          },
          destinations: const <Widget>[
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_books_outlined),
              selectedIcon: Icon(Icons.library_books),
              label: 'Sách của tôi',
            ),
            NavigationDestination(
              icon: NoticeBadgeIcon(icon: Icons.person_outline),
              selectedIcon: NoticeBadgeIcon(icon: Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}
