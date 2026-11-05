import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/reader_viewmodel.dart';
import '../views/notifications_screen.dart';

/// Theo dõi thông báo mới khi ứng dụng đang mở.
///
/// Bọc khung chính của mỗi vai trò (Reader, Publisher, Admin). Cứ [interval] lại hỏi máy chủ
/// số thông báo chưa đọc (`GET /api/notifications/unread-count`), và hỏi ngay khi ứng dụng
/// được mở lại từ nền. Khi số chưa đọc tăng lên, hiện SnackBar "Bạn có thông báo mới" kèm nút Xem.
/// Thông báo đẩy khi ứng dụng đang đóng do Firebase Cloud Messaging đảm nhận (tùy chọn).
class NoticeWatcher extends StatefulWidget {
  const NoticeWatcher({super.key, required this.child, this.interval = const Duration(seconds: 30)});

  final Widget child;
  final Duration interval;

  @override
  State<NoticeWatcher> createState() => _NoticeWatcherState();
}

class _NoticeWatcherState extends State<NoticeWatcher> with WidgetsBindingObserver {
  Timer? _timer;
  int? _last;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _check());
    _timer = Timer.periodic(widget.interval, (Timer _) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking) {
      return;
    }
    _checking = true;
    try {
      final ReaderViewModel vm = context.read<ReaderViewModel>();
      if (vm.currentUser == null) {
        return;
      }
      final int count = await vm.refreshUnread();
      final int? before = _last;
      _last = count;
      if (before != null && count > before && mounted) {
        _showNew(count - before);
      }
    } finally {
      _checking = false;
    }
  }

  void _showNew(int added) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(added == 1 ? 'Bạn có 1 thông báo mới' : 'Bạn có $added thông báo mới'),
        action: SnackBarAction(
          label: 'Xem',
          onPressed: () {
            nav.push(MaterialPageRoute<void>(builder: (BuildContext _) => const NotificationsScreen()));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
