import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/publisher_viewmodel.dart';
import '../../widgets/common.dart';
import 'upload_book_screen.dart';

/// Sách của tôi: theo dõi trạng thái duyệt, sửa và xóa sách do mình đăng.
class MyBooksScreen extends StatelessWidget {
  const MyBooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: buildAppBar(
          'Sách của tôi',
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: 'Tất cả'),
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Đã duyệt'),
              Tab(text: 'Bị từ chối'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _MyBookList(status: null),
            _MyBookList(status: BookStatus.pending),
            _MyBookList(status: BookStatus.approved),
            _MyBookList(status: BookStatus.rejected),
          ],
        ),
      ),
    );
  }
}

class _MyBookList extends StatelessWidget {
  const _MyBookList({required this.status});

  /// null = hiện tất cả trạng thái.
  final BookStatus? status;

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
    await runAction(context, () => context.read<PublisherViewModel>().deleteBook(book.id), success: 'Đã xóa sách');
  }

  void _edit(BuildContext context, Book book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => UploadBookScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PublisherViewModel>(
      builder: (BuildContext context, PublisherViewModel vm, Widget? _) {
        final AppUser? user = vm.currentUser;
        final List<Book> books =
            user == null ? <Book>[] : vm.myBooks(status: status);

        if (books.isEmpty && vm.loading) {
          return const LoadingState();
        }
        if (books.isEmpty && vm.error != null) {
          return ErrorState(message: vm.error!, onRetry: vm.loadMyBooks);
        }
        if (books.isEmpty) {
          return const EmptyState(
            icon: Icons.library_books_outlined,
            title: 'Không có sách nào',
            message: 'Sách bạn đăng sẽ hiển thị ở đây cùng trạng thái duyệt.',
          );
        }

        return RefreshIndicator(
          onRefresh: vm.loadMyBooks,
          child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          itemCount: books.length,
          separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final Book book = books[index];
            final String? reason = book.rejectReason;

            return BookRow(
              book: book,
              subtitle: '${vm.categoryName(book.categoryId)} · ${book.totalPages} trang',
              extra: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  StatusPill(book.status),
                  // Lý do từ chối do Admin nhập
                  if (book.status == BookStatus.rejected && reason != null && reason.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Lý do: $reason',
                        style: const TextStyle(fontSize: 13, color: AppColors.danger, height: 1.35),
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                onSelected: (String action) {
                  if (action == 'edit') {
                    _edit(context, book);
                  } else if (action == 'delete') {
                    _delete(context, book);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Chỉnh sửa'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Xóa sách'),
                      ),
                    ),
                  ];
                },
              ),
            );
          },
          ),
        );
      },
    );
  }
}
