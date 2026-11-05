import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/common.dart';
import 'reading_screen.dart';

/// Màn hình Chi tiết sách: bìa, mô tả, nút Đọc / Tải về / Yêu thích.
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  /// Tải PDF về máy để đọc offline, hoặc xóa bản đã tải.
  Future<void> _toggleDownload(BuildContext context, ReaderViewModel vm, Book book, bool downloaded) async {
    if (downloaded) {
      final bool ok = await confirmDialog(
        context,
        title: 'Xóa bản tải về',
        message: 'Xóa file PDF của “${book.title}” khỏi máy? Bạn vẫn đọc online được.',
        okLabel: 'Xóa',
      );
      if (!ok || !context.mounted) {
        return;
      }
      await runAction(context, () => vm.removeDownload(book.id), success: 'Đã xóa bản tải về');
      return;
    }
    await runAction(
      context,
      () => vm.download(book),
      success: kIsWeb
          ? 'Đã tải sách (bản web chỉ lưu đến khi tải lại trang)'
          : 'Đã tải sách về máy, có thể đọc khi không có mạng',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderViewModel>(
      builder: (BuildContext context, ReaderViewModel vm, Widget? _) {
        final Book? book = vm.bookById(bookId);
        if (book == null) {
          return Scaffold(
            appBar: buildAppBar('Chi tiết sách'),
            body: FutureBuilder<Book>(
              future: vm.refreshBook(bookId),
              builder: (BuildContext context, AsyncSnapshot<Book> snap) => snap.hasError
                  ? const EmptyState(icon: Icons.menu_book_outlined, title: 'Sách không còn tồn tại')
                  : const LoadingState(),
            ),
          );
        }

        final bool favorite = vm.isFavorite(book.id);
        final bool downloaded = vm.isDownloaded(book.id);
        final double? progress = vm.downloadProgress[book.id];
        final int page = vm.pageOf(book.id);

        return Scaffold(
          appBar: buildAppBar(
            'Chi tiết sách',
            actions: <Widget>[
              IconButton(
                tooltip: favorite ? 'Bỏ yêu thích' : 'Yêu thích',
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? AppColors.danger : AppColors.ink,
                ),
                onPressed: () => runAction(
                  context,
                  () => vm.toggleFavorite(book.id),
                  success: favorite ? 'Đã bỏ khỏi yêu thích' : 'Đã thêm vào yêu thích',
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              Center(
                child: Container(
                  width: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withAlpha(46),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: BookCover(book: book, radius: 14),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                book.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                book.author,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Center(
                child: Pill(
                  text: book.categoryName.isEmpty ? vm.categoryName(book.categoryId) : book.categoryName,
                  color: AppColors.primary,
                  icon: Icons.category_outlined,
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: <Widget>[
                    Expanded(child: _InfoItem(value: '${book.totalPages}', label: 'Trang')),
                    const SizedBox(height: 32, child: VerticalDivider(width: 1, color: AppColors.line)),
                    Expanded(child: _InfoItem(value: '${book.views}', label: 'Lượt xem')),
                    const SizedBox(height: 32, child: VerticalDivider(width: 1, color: AppColors.line)),
                    const Expanded(child: _InfoItem(value: 'PDF', label: 'Định dạng')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('Giới thiệu'),
              const SizedBox(height: 8),
              Text(
                book.description,
                style: const TextStyle(fontSize: 15, height: 1.55, color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              Text(
                'Đăng bởi ${book.publisherName} · ${formatDate(book.createdAt)}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: <Widget>[
                  // Nút tải về (đọc offline)
                  SizedBox(
                    height: 52,
                    child: progress != null
                        ? OutlinedButton.icon(
                            onPressed: null,
                            icon: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.4, value: progress > 0 ? progress : null),
                            ),
                            label: Text('${(progress * 100).round()}%'),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _toggleDownload(context, vm, book, downloaded),
                            icon: Icon(downloaded ? Icons.download_done : Icons.download_outlined),
                            label: Text(downloaded ? 'Đã tải' : 'Tải về'),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (page == 0) {
                            vm.increaseViews(book.id);
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (BuildContext _) => ReadingScreen(book: book)),
                          );
                        },
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text(
                          page > 0 ? 'Đọc tiếp trang $page' : 'Đọc sách',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      ],
    );
  }
}
