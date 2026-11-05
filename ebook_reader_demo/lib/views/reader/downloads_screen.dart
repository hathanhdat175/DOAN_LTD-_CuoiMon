import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../services/local/local_cache.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/common.dart';
import 'reading_screen.dart';

/// Sách đã tải về máy: mở đọc được cả khi không có kết nối mạng.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _remove(BuildContext context, ReaderViewModel vm, Book book) async {
    final bool ok = await confirmDialog(
      context,
      title: 'Xóa bản tải về',
      message: 'Xóa file PDF của “${book.title}” khỏi máy?',
      okLabel: 'Xóa',
    );
    if (!ok || !context.mounted) {
      return;
    }
    await runAction(context, () => vm.removeDownload(book.id), success: 'Đã xóa bản tải về');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderViewModel>(
      builder: (BuildContext context, ReaderViewModel vm, Widget? _) {
        final List<DownloadedBook> list = vm.downloads;

        return Scaffold(
          appBar: buildAppBar('Sách đã tải về'),
          body: list.isEmpty
              ? EmptyState(
                  icon: Icons.download_for_offline_outlined,
                  title: 'Chưa tải sách nào',
                  message: kIsWeb
                      ? 'Bấm “Tải về” ở trang chi tiết sách. Bản web chỉ giữ sách đến khi tải lại trang.'
                      : 'Bấm “Tải về” ở trang chi tiết sách để đọc khi không có mạng.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final Book book = list[index].book;
                    final int page = vm.pageOf(book.id);
                    return BookRow(
                      book: book,
                      subtitle: '${book.author} · tải ngày ${formatDate(list[index].savedAt)}',
                      extra: Pill(
                        text: page > 0 ? 'Đang đọc trang $page / ${book.totalPages}' : 'Chưa đọc',
                        color: AppColors.primary,
                        icon: Icons.offline_pin_outlined,
                      ),
                      trailing: IconButton(
                        tooltip: 'Xóa bản tải về',
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => _remove(context, vm, book),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (BuildContext _) => ReadingScreen(book: book)),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
