import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/common.dart';
import '../reader/reader_shell.dart';
import 'reports_screen.dart';

/// Dashboard của Admin: thống kê toàn hệ thống và các thao tác nhanh.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.onOpenTab});

  /// Chuyển sang tab khác của AdminShell (1 = Duyệt sách, 2 = Người dùng, 3 = Thể loại).
  final ValueChanged<int> onOpenTab;

  Future<void> _sendNotice(BuildContext context) async {
    final String? title = await promptDialog(
      context,
      title: 'Gửi thông báo hệ thống',
      label: 'Tiêu đề',
      okLabel: 'Tiếp tục',
    );
    if (title == null || !context.mounted) {
      return;
    }
    final String? body = await promptDialog(
      context,
      title: 'Nội dung thông báo',
      label: 'Nội dung',
      okLabel: 'Gửi',
      maxLines: 4,
    );
    if (body == null || !context.mounted) {
      return;
    }
    await runAction(
      context,
      () => context.read<AdminViewModel>().sendNotice(title, body),
      success: 'Đã gửi thông báo đến toàn bộ người dùng',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminViewModel>(
      builder: (BuildContext context, AdminViewModel vm, Widget? _) {
        final int pending = vm.countByStatus(BookStatus.pending);
        final int approved = vm.countByStatus(BookStatus.approved);

        return Scaffold(
          appBar: buildAppBar(
            'Quản trị hệ thống',
            actions: <Widget>[
              IconButton(
                tooltip: 'Đọc sách',
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () => openReaderLibrary(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: vm.loadAll,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: <Widget>[
              if (vm.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: AppColors.danger.withAlpha(20),
                    onTap: vm.loadAll,
                    child: Text('${vm.error!}\nChạm để thử lại.', style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
              // Thẻ nhắc việc: số sách đang chờ duyệt
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onOpenTab(1),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Sách đang chờ duyệt',
                                style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$pending',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pending > 0 ? 'Chạm để xem và xử lý' : 'Không còn sách nào cần xử lý',
                                style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.fact_check_outlined, color: AppColors.accent, size: 44),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StatGrid(
                children: <Widget>[
                  StatCard(
                    label: 'Người dùng',
                    value: '${vm.stats.users}',
                    icon: Icons.people_outline,
                  ),
                  StatCard(
                    label: 'Sách đã duyệt',
                    value: '$approved',
                    icon: Icons.library_books_outlined,
                    color: AppColors.success,
                  ),
                  StatCard(
                    label: 'Thể loại',
                    value: '${vm.stats.categories}',
                    icon: Icons.category_outlined,
                    color: AppColors.warning,
                  ),
                  StatCard(
                    label: 'Bị từ chối',
                    value: '${vm.countByStatus(BookStatus.rejected)}',
                    icon: Icons.cancel_outlined,
                    color: AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle('Thao tác nhanh'),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.bar_chart, color: AppColors.primary),
                      title: const Text('Xem báo cáo thống kê'),
                      subtitle: const Text('Lượt đọc, sách mới theo thời gian'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (BuildContext _) => const ReportsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                    ListTile(
                      leading: const Icon(Icons.campaign_outlined, color: AppColors.primary),
                      title: const Text('Gửi thông báo hệ thống'),
                      subtitle: const Text('Gửi đến toàn bộ người dùng'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _sendNotice(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                    ListTile(
                      leading: const Icon(Icons.people_outline, color: AppColors.primary),
                      title: const Text('Quản lý người dùng'),
                      subtitle: const Text('Khóa hoặc mở khóa tài khoản'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onOpenTab(2),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
                      title: const Text('Đọc sách'),
                      subtitle: const Text('Đọc sách như người đọc bình thường'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openReaderLibrary(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle('Sách được đọc nhiều nhất'),
              const SizedBox(height: 10),
              for (final Book book in vm.topBooks(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookRow(
                    book: book,
                    extra: Pill(
                      text: '${book.views} lượt xem',
                      color: AppColors.primary,
                      icon: Icons.visibility_outlined,
                    ),
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
