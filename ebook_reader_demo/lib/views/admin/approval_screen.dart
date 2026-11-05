import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/common.dart';
import 'pdf_preview_screen.dart';

/// Duyệt sách: Admin chấp nhận, từ chối (kèm lý do) hoặc xóa sách.
class ApprovalScreen extends StatelessWidget {
  const ApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: buildAppBar(
          'Duyệt sách',
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Đã duyệt'),
              Tab(text: 'Từ chối'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _ApprovalList(status: BookStatus.pending),
            _ApprovalList(status: BookStatus.approved),
            _ApprovalList(status: BookStatus.rejected),
          ],
        ),
      ),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.status});

  final BookStatus status;

  Future<void> _approve(BuildContext context, Book book) async {
    await runAction(
      context,
      () => context.read<AdminViewModel>().approveBook(book.id),
      success: 'Đã duyệt “${book.title}”, đã gửi thông báo cho người đăng',
    );
  }

  Future<void> _reject(BuildContext context, Book book) async {
    final String? reason = await promptDialog(
      context,
      title: 'Từ chối sách',
      label: 'Lý do từ chối',
      okLabel: 'Từ chối',
      maxLines: 3,
    );
    if (reason == null || !context.mounted) {
      return;
    }
    await runAction(
      context,
      () => context.read<AdminViewModel>().rejectBook(book.id, reason),
      success: 'Đã từ chối “${book.title}”',
    );
  }

  Future<void> _delete(BuildContext context, Book book) async {
    final bool ok = await confirmDialog(
      context,
      title: 'Xóa sách',
      message: 'Xóa “${book.title}” khỏi hệ thống? Thao tác này không thể hoàn tác.',
      okLabel: 'Xóa',
      danger: true,
    );
    if (!ok || !context.mounted) {
      return;
    }
    await runAction(context, () => context.read<AdminViewModel>().deleteBook(book.id), success: 'Đã xóa sách');
  }

  /// Admin mở file PDF để xem nội dung sách (kể cả sách chưa duyệt).
  void _preview(BuildContext context, Book book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => PdfPreviewScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminViewModel>(
      builder: (BuildContext context, AdminViewModel vm, Widget? _) {
        final List<Book> books = vm.booksByStatus(status);

        if (books.isEmpty && vm.loading) {
          return const LoadingState();
        }
        if (books.isEmpty && vm.error != null) {
          return ErrorState(message: vm.error!, onRetry: vm.loadAll);
        }
        if (books.isEmpty) {
          return EmptyState(
            icon: statusIcon(status),
            title: 'Không có sách ${status.label.toLowerCase()}',
          );
        }

        return RefreshIndicator(
          onRefresh: vm.loadAll,
          child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: books.length,
          separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final Book book = books[index];
            final String? reason = book.rejectReason;

            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  InkWell(
                    onTap: () => _preview(context, book),
                    child: BookRowContent(book: book),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    book.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4),
                  ),
                  if (status == BookStatus.rejected && reason != null && reason.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Lý do từ chối: $reason',
                      style: const TextStyle(fontSize: 13, color: AppColors.danger, height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Xóa sách',
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => _delete(context, book),
                      ),
                      const Spacer(),
                      if (status != BookStatus.rejected)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                          onPressed: () => _reject(context, book),
                          child: const Text('Từ chối'),
                        ),
                      if (status != BookStatus.approved) ...<Widget>[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _approve(context, book),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Duyệt'),
                        ),
                      ],
                    ],
                  ),
                  if (status != BookStatus.approved)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _preview(context, book),
                        icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
                        label: const Text('Xem nội dung trước khi duyệt'),
                      ),
                    ),
                ],
              ),
            );
          },
          ),
        );
      },
    );
  }
}

/// Phần thông tin sách trong thẻ duyệt: bìa, tên, tác giả, người đăng, trạng thái.
class BookRowContent extends StatelessWidget {
  const BookRowContent({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 58, child: BookCover(book: book, radius: 8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${book.author} · ${book.categoryName} · ${book.totalPages} trang',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                'Đăng bởi ${book.publisherName} · ${formatDate(book.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              StatusPill(book.status),
            ],
          ),
        ),
      ],
    );
  }
}
