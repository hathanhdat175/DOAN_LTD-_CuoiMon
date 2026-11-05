import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/publisher_viewmodel.dart';
import '../../widgets/common.dart';
import '../reader/reader_shell.dart';

/// Dashboard của Publisher: thống kê tổng quan các sách đã đăng.
class PublisherDashboard extends StatelessWidget {
  const PublisherDashboard({super.key, required this.onSeeAll});

  /// Được gọi khi bấm "Xem tất cả" để chuyển sang tab Sách của tôi.
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Consumer<PublisherViewModel>(
      builder: (BuildContext context, PublisherViewModel vm, Widget? _) {
        final AppUser? user = vm.currentUser;
        if (user == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final List<Book> mine = vm.myBooks();
        int approved = 0;
        int pending = 0;
        int rejected = 0;
        int views = 0;
        for (final Book b in mine) {
          views += b.views;
          switch (b.status) {
            case BookStatus.approved:
              approved++;
              break;
            case BookStatus.pending:
              pending++;
              break;
            case BookStatus.rejected:
              rejected++;
              break;
          }
        }
        final List<Book> recent = mine.length > 3 ? mine.sublist(0, 3) : mine;

        return Scaffold(
          appBar: buildAppBar(
            'Tổng quan',
            actions: <Widget>[
              IconButton(
                tooltip: 'Đọc sách',
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () => openReaderLibrary(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: vm.loadMyBooks,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            children: <Widget>[
              if (vm.error != null && !vm.loaded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: AppColors.danger.withAlpha(20),
                    child: Text(vm.error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
              Text(
                'Xin chào, ${user.name}',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 14),
              // Thẻ lớn: tổng số sách + tổng lượt xem
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Sách đã đăng',
                            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${mine.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        const Icon(Icons.visibility_outlined, color: AppColors.accent),
                        const SizedBox(height: 4),
                        Text(
                          '$views',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'lượt xem',
                          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SmallStat(
                      value: approved,
                      label: 'Đã duyệt',
                      color: AppColors.success,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallStat(
                      value: pending,
                      label: 'Chờ duyệt',
                      color: AppColors.warning,
                      icon: Icons.hourglass_empty,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallStat(
                      value: rejected,
                      label: 'Từ chối',
                      color: AppColors.danger,
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionTitle(
                'Sách đăng gần đây',
                trailing: TextButton(onPressed: onSeeAll, child: const Text('Xem tất cả')),
              ),
              const SizedBox(height: 4),
              if (recent.isEmpty && vm.loading)
                const Padding(padding: EdgeInsets.all(24), child: LoadingState())
              else if (recent.isEmpty)
                const AppCard(
                  child: Text(
                    'Bạn chưa đăng cuốn sách nào. Bấm nút “Đăng sách” để bắt đầu.',
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                )
              else
                for (final Book book in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BookRow(
                      book: book,
                      subtitle: '${vm.categoryName(book.categoryId)} · ${formatDate(book.createdAt)}',
                      extra: StatusPill(book.status),
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

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
