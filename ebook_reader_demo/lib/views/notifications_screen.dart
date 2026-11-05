import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../viewmodels/reader_viewmodel.dart';
import '../widgets/common.dart';

/// Màn hình Thông báo (dùng chung cho cả ba vai trò).
///
/// Hiện thông báo hệ thống do Admin gửi và thông báo riêng (kết quả duyệt sách).
/// Thông báo chưa đọc có chấm màu và nền nổi bật; khi mở màn hình, mọi thông báo
/// được đánh dấu đã đọc trên máy chủ (`POST /api/notifications/read-all`) nên huy hiệu
/// số chưa đọc ở tab Tài khoản trở về 0. Kéo xuống để làm mới.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  late final ReaderViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ReaderViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _load());
  }

  Future<void> _load() async {
    final ReaderViewModel vm = context.read<ReaderViewModel>();
    await vm.loadNotices();
    await vm.markNoticesRead();
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    // Thông báo vẫn nổi bật trong lúc đang xem; rời màn hình thì coi như đã đọc.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _vm.markLocalNoticesRead());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderViewModel>(
      builder: (BuildContext context, ReaderViewModel vm, Widget? _) {
        final List<AppNotice> notices = vm.notices;
        final int unread = notices.where((AppNotice n) => !n.isRead).length;

        Widget body;
        if (_loading && notices.isEmpty) {
          body = const LoadingState();
        } else if (notices.isEmpty) {
          body = ListView(
            children: const <Widget>[
              SizedBox(height: 80),
              EmptyState(
                icon: Icons.notifications_none,
                title: 'Chưa có thông báo nào',
                message: 'Thông báo hệ thống và kết quả duyệt sách sẽ hiện ở đây.',
              ),
            ],
          );
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: notices.length + 1,
            separatorBuilder: (BuildContext _, int __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    unread > 0 ? '$unread thông báo mới' : 'Bạn đã xem hết thông báo',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                );
              }
              return NoticeTile(notice: notices[i - 1]);
            },
          );
        }

        return Scaffold(
          appBar: buildAppBar('Thông báo'),
          body: RefreshIndicator(
            onRefresh: () async {
              await vm.loadNotices();
              await vm.markNoticesRead();
            },
            child: body,
          ),
        );
      },
    );
  }
}

/// Một thông báo: biểu tượng theo loại, tiêu đề, nội dung, ngày gửi; chưa đọc thì nổi bật.
class NoticeTile extends StatelessWidget {
  const NoticeTile({super.key, required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final bool fresh = !notice.isRead;
    return AppCard(
      color: fresh ? AppColors.primarySoft : null,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            notice.personal ? Icons.mark_email_unread_outlined : Icons.campaign_outlined,
            color: notice.personal ? AppColors.primary : AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notice.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                    if (fresh)
                      Container(
                        key: const ValueKey<String>('notice-unread-dot'),
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notice.body, style: const TextStyle(color: AppColors.ink, height: 1.4)),
                const SizedBox(height: 4),
                Text(
                  '${notice.personal ? 'Gửi riêng cho bạn · ' : 'Thông báo hệ thống · '}${formatDate(notice.sentAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Biểu tượng kèm huy hiệu số thông báo chưa đọc (dùng cho tab Tài khoản ở thanh điều hướng).
class NoticeBadgeIcon extends StatelessWidget {
  const NoticeBadgeIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final int unread = context.select<ReaderViewModel, int>((ReaderViewModel vm) => vm.unreadNotices);
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: Icon(icon),
    );
  }
}
