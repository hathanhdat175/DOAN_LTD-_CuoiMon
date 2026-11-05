import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/common.dart';
import 'reading_screen.dart';

/// Tab Lịch sử: các sách đã đọc gần đây kèm tiến độ đọc.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderViewModel>(
      builder: (BuildContext context, ReaderViewModel vm, Widget? _) {
        final List<ReadingRecord> records = vm.history;

        return Scaffold(
          appBar: buildAppBar('Lịch sử đọc'),
          body: records.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'Chưa có lịch sử đọc',
                  message: 'Những cuốn sách bạn mở đọc sẽ xuất hiện ở đây.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: records.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final ReadingRecord record = records[index];
                    final Book? book = record.book ?? vm.bookById(record.bookId);
                    if (book == null) {
                      return const SizedBox.shrink();
                    }
                    final double percent = book.totalPages == 0 ? 0 : record.page / book.totalPages;

                    return BookRow(
                      book: book,
                      subtitle: '${book.author} · ${formatDate(record.updatedAt)}',
                      extra: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 6,
                              backgroundColor: AppColors.line,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Trang ${record.page} / ${book.totalPages} · ${(percent * 100).round()}%',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
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
