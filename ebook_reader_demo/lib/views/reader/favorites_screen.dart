import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/common.dart';
import 'book_detail_screen.dart';

/// Tab Yêu thích: danh sách sách đã đánh dấu yêu thích.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderViewModel>(
      builder: (BuildContext context, ReaderViewModel vm, Widget? _) {
        final List<Book> books = vm.favoriteBooks;

        return Scaffold(
          appBar: buildAppBar('Sách yêu thích'),
          body: books.isEmpty
              ? const EmptyState(
                  icon: Icons.favorite_border,
                  title: 'Chưa có sách yêu thích',
                  message: 'Bấm biểu tượng trái tim ở trang chi tiết sách để lưu lại.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: books.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final Book book = books[index];
                    return BookRow(
                      book: book,
                      extra: Pill(text: vm.categoryName(book.categoryId), color: AppColors.primary),
                      trailing: IconButton(
                        tooltip: 'Bỏ yêu thích',
                        icon: const Icon(Icons.favorite, color: AppColors.danger),
                        onPressed: () => runAction(context, () => vm.toggleFavorite(book.id), success: 'Đã bỏ khỏi yêu thích'),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext _) => BookDetailScreen(bookId: book.id),
                          ),
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
