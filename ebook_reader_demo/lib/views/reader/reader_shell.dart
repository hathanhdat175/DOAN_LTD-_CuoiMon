import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/notice_watcher.dart';
import '../notifications_screen.dart';
import '../profile_screen.dart';
import 'downloads_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// Mở khu vực đọc sách (Trang chủ, Yêu thích, Lịch sử) cho Publisher và Admin,
/// để hai vai trò này cũng đọc sách được như người đọc bình thường.
/// Bấm nút Back để quay lại màn hình quản lý của vai trò đó.
void openReaderLibrary(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (BuildContext _) => const ReaderShell(showProfileTab: false)),
  );
}

/// Khung chính của vai trò Reader: 4 tab ở thanh điều hướng dưới.
///
/// Khi Publisher/Admin mở khu vực đọc sách thì [showProfileTab] = false,
/// vì họ đã có tab Tài khoản ở màn hình chính của mình; tab thứ tư khi đó là
/// danh sách sách đã tải về.
class ReaderShell extends StatefulWidget {
  const ReaderShell({super.key, this.showProfileTab = true});

  final bool showProfileTab;

  @override
  State<ReaderShell> createState() => _ReaderShellState();
}

class _ReaderShellState extends State<ReaderShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Tải dữ liệu khu vực đọc sách từ máy chủ khi mở khung chính.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        context.read<ReaderViewModel>().loadLibrary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget shell = Scaffold(
      // IndexedStack giữ nguyên trạng thái từng tab khi chuyển qua lại.
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          HomeScreen(showBackButton: !widget.showProfileTab),
          const FavoritesScreen(),
          const HistoryScreen(),
          if (widget.showProfileTab) const ProfileScreen() else const DownloadsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) {
          setState(() {
            _index = i;
          });
        },
        destinations: <Widget>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Yêu thích',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
          if (widget.showProfileTab)
            const NavigationDestination(
              icon: NoticeBadgeIcon(icon: Icons.person_outline),
              selectedIcon: NoticeBadgeIcon(icon: Icons.person),
              label: 'Tài khoản',
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.download_for_offline_outlined),
              selectedIcon: Icon(Icons.download_for_offline),
              label: 'Đã tải',
            ),
        ],
      ),
    );
    // Reader: theo dõi thông báo mới. Khi Publisher/Admin mở khu vực đọc sách thì khung chính
    // của họ (bên dưới) đã theo dõi rồi nên không bọc thêm.
    return widget.showProfileTab ? NoticeWatcher(child: shell) : shell;
  }
}
