import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../services/local/local_cache.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/common.dart';
import 'book_detail_screen.dart';
import 'reading_screen.dart';

/// Trang chủ của Reader: tìm kiếm, lọc thể loại, lưới sách 2 cột.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.showBackButton = false});

  /// Publisher/Admin mở khu vực đọc sách từ màn hình của họ → hiện nút quay lại.
  /// (Không dùng Navigator.canPop() vì khi màn hình Chi tiết / Đọc sách đang mở đè lên,
  /// Trang chủ vẽ lại cũng thấy "có thể quay lại" và giữ nhầm nút này.)
  final bool showBackButton;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openBook(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => BookDetailScreen(bookId: book.id)),
    );
  }

  void _continueReading(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => ReadingScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Consumer vẽ lại giao diện mỗi khi ViewModel báo dữ liệu thay đổi.
    return Consumer<ReaderViewModel>(
      builder: (BuildContext context, ReaderViewModel vm, Widget? _) {
        final AppUser? user = vm.currentUser;
        final String query = vm.query;
        final String? categoryId = vm.categoryId;
        // Mất mạng: chỉ hiện các sách đã tải về máy.
        final List<Book> books = vm.offline ? <Book>[for (final DownloadedBook d in vm.downloads) d.book] : vm.books;
        final List<ReadingRecord> history = vm.history;
        final Book? lastBook = history.isEmpty ? null : (history.first.book ?? vm.bookById(history.first.bookId));

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: vm.loadLibrary,
              child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (widget.showBackButton)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: TextButton.icon(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back),
                              label: Text('Quay lại trang ${user?.role.label ?? ''}'.trim()),
                            ),
                          ),
                        Text(
                          'Xin chào, ${user == null ? 'bạn' : user.name}',
                          style: const TextStyle(fontSize: 14, color: AppColors.muted),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Hôm nay đọc gì?',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          onChanged: (String value) => vm.search(query: value),
                          onSubmitted: (String value) => vm.search(query: value, immediate: true),
                          decoration: fieldDecoration(
                            'Tìm theo tên sách hoặc tác giả',
                            icon: Icons.search,
                            suffix: query.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      vm.search(query: '', immediate: true);
                                    },
                                  ),
                          ),
                        ),
                        if (vm.offline)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Pill(
                              text: 'Không có mạng · đang hiện sách đã tải về',
                              color: AppColors.warning,
                              icon: Icons.wifi_off,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Dải chip chọn thể loại (cuộn ngang)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: categoryId == null,
                            onSelected: (bool _) => vm.search(clearCategory: true, immediate: true),
                          ),
                        ),
                        for (final BookCategory c in vm.categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: categoryId == c.id,
                              onSelected: (bool _) => vm.search(categoryId: c.id, immediate: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (lastBook != null && query.isEmpty && categoryId == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _ContinueCard(
                        book: lastBook,
                        page: vm.pageOf(lastBook.id),
                        onTap: () => _continueReading(lastBook),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: SectionTitle(
                      categoryId == null ? 'Sách mới cập nhật' : vm.categoryName(categoryId),
                      trailing: vm.searching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              '${books.length} cuốn',
                              style: const TextStyle(color: AppColors.muted, fontSize: 13),
                            ),
                    ),
                  ),
                ),
                if (books.isEmpty && vm.loading)
                  const SliverFillRemaining(hasScrollBody: false, child: LoadingState())
                else if (books.isEmpty && vm.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(message: vm.error!, onRetry: vm.loadLibrary),
                  )
                else if (books.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'Không tìm thấy sách phù hợp',
                      message: 'Thử từ khóa khác hoặc chọn thể loại khác.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverGrid(
                      // Lưới 2 cột theo yêu cầu chức năng của Reader
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.56,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final Book book = books[index];
                          return BookCard(book: book, onTap: () => _openBook(book));
                        },
                        childCount: books.length,
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

/// Thẻ sách trong lưới: bìa + tên sách + tác giả.
class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                BookCover(book: book, radius: 12),
                if (context.watch<ReaderViewModel>().isFavorite(book.id))
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.favorite, size: 15, color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Thẻ "Đọc tiếp" cuốn sách đang đọc dở.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.book, required this.page, required this.onTap});

  final Book book;
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double percent = book.totalPages == 0 ? 0 : page / book.totalPages;

    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              SizedBox(width: 52, child: BookCover(book: book, radius: 8)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ĐỌC TIẾP',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        backgroundColor: Colors.white.withAlpha(50),
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Trang $page / ${book.totalPages}',
                      style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 38),
            ],
          ),
        ),
      ),
    );
  }
}
