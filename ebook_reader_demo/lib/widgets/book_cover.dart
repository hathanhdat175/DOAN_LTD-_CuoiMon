import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../viewmodels/reader_viewmodel.dart';

/// Bìa sách: tải ảnh bìa từ máy chủ; nếu sách chưa có ảnh bìa hoặc tải lỗi thì vẽ bìa
/// bằng code (nền chuyển màu + tên sách).
///
/// - Android / iOS: cached_network_image (lưu đệm ảnh trên máy).
/// - Web: Image.network (trình duyệt tự lưu đệm). cached_network_image trên web có lúc vẽ
///   ảnh thành ô đen sau khi đăng xuất / đăng nhập tài khoản khác trong cùng phiên.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.radius = 10});

  final Book book;
  final double radius;

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF2F5D50), Color(0xFF16332B)],
    <Color>[Color(0xFF8A4B2D), Color(0xFF4E2613)],
    <Color>[Color(0xFF2E4A6B), Color(0xFF14263D)],
    <Color>[Color(0xFF6B3A5B), Color(0xFF391A30)],
    <Color>[Color(0xFF7A6A2E), Color(0xFF423814)],
    <Color>[Color(0xFF3C5A2E), Color(0xFF1D3013)],
    <Color>[Color(0xFF7B3434), Color(0xFF421717)],
    <Color>[Color(0xFF34606B), Color(0xFF17333A)],
  ];

  @override
  Widget build(BuildContext context) {
    final String? url = book.coverUrl == null ? null : context.read<ReaderViewModel>().coverUrl(book);
    if (url != null) {
      return AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: kIsWeb
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) =>
                      progress == null ? child : _painted(),
                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) => _painted(),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (BuildContext context, String url) => _painted(),
                  errorWidget: (BuildContext context, String url, Object error) => _painted(),
                ),
        ),
      );
    }
    return AspectRatio(aspectRatio: 2 / 3, child: _painted());
  }

  Widget _painted() {
    final List<Color> colors = _palettes[book.coverSeed % _palettes.length];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final double barHeight = w * 0.02 < 2 ? 2 : w * 0.02;

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Gáy sách
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: w * 0.07,
                  child: ColoredBox(color: Colors.black.withAlpha(46)),
                ),
                // Vòng tròn trang trí
                Positioned(
                  right: -w * 0.25,
                  top: -w * 0.25,
                  child: Container(
                    width: w * 0.7,
                    height: w * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(20),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(w * 0.16, w * 0.14, w * 0.1, w * 0.12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(width: w * 0.18, height: barHeight, color: AppColors.accent),
                      SizedBox(height: w * 0.08),
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: w * 0.125,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (w > 70)
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha(215),
                            fontSize: w * 0.075,
                          ),
                        ),
                    ],
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
