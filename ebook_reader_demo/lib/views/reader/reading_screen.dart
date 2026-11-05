import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../services/api/bookhub_api.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/common.dart';

/// Màn hình Đọc sách: mở file PDF của sách bằng trình đọc SfPdfViewer.
///
/// - Mở đúng trang đọc lần trước; mỗi lần lật trang, tiến độ được lưu vào SQLite
///   trên máy và đồng bộ lên bảng ReadingProgress (gộp các lần lật trang nhanh).
/// - Sách đã tải về được mở từ file trên máy, đọc được khi không có mạng.
/// - Phóng to / thu nhỏ và ba chế độ nền: sáng, giấy, tối.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.book});

  final Book book;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  static const List<Color> _backgrounds = <Color>[
    Color(0xFFE9ECE8), // sáng
    Color(0xFFE8DDC4), // giấy ngà
    Color(0xFF121514), // tối
  ];
  static const List<Color> _textColors = <Color>[
    Color(0xFF222222),
    Color(0xFF3E3222),
    Color(0xFFE4E4E4),
  ];
  static const List<String> _modeNames = <String>['Nền sáng', 'Nền giấy', 'Nền tối'];

  /// Bộ lọc màu áp lên trang PDF theo chế độ nền.
  /// Luôn bọc trình đọc trong ColorFiltered (kể cả nền sáng dùng ma trận đơn vị) để khi đổi
  /// nền, cây widget giữ nguyên và trình đọc không bị tạo lại / mất trang đang đọc.
  static const List<ColorFilter> _filters = <ColorFilter>[
    ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    // Ngả vàng như giấy cũ.
    ColorFilter.matrix(<double>[
      0.95, 0, 0, 0, 0, //
      0, 0.90, 0, 0, 0, //
      0, 0, 0.78, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    // Đảo màu: chữ sáng trên nền tối.
    ColorFilter.matrix(<double>[
      -0.88, 0, 0, 0, 235, //
      0, -0.88, 0, 0, 235, //
      0, 0, -0.88, 0, 235, //
      0, 0, 0, 1, 0,
    ]),
  ];

  final PdfViewerController _controller = PdfViewerController();
  late Future<Uint8List> _pdf;
  late int _startPage;
  int _page = 1;
  int _total = 1;

  /// Vị trí thanh trượt khi người dùng đang kéo (null = không kéo).
  double? _dragValue;
  int _mode = 0;
  bool _ready = false;
  Timer? _saveTimer;
  late final ReaderViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ReaderViewModel>();
    final int saved = _vm.pageOf(widget.book.id);
    _total = widget.book.totalPages < 1 ? 1 : widget.book.totalPages;
    _startPage = saved < 1 ? 1 : (saved > _total ? _total : saved);
    _page = _startPage;
    _pdf = _vm.openPdf(widget.book);
    if (saved == 0) {
      // Lần đầu mở sách: ghi nhận ngay để sách xuất hiện trong Lịch sử đọc.
      WidgetsBinding.instance.addPostFrameCallback((Duration _) => _save(1));
    }
  }

  @override
  void dispose() {
    // Lưu ngay trang cuối cùng khi rời màn hình.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save(_page);
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(int page) async {
    try {
      await _vm.saveProgress(widget.book.id, page);
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, e.message);
      }
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final int page = details.newPageNumber;
    if (page < 1 || page == _page) {
      return;
    }
    setState(() {
      _page = page;
    });
    // Tự động lưu trang đang đọc (gộp các lần lật trang nhanh liên tiếp).
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _save(page));
  }

  void _zoom(double delta) {
    final double next = (_controller.zoomLevel + delta).clamp(1.0, 3.0);
    _controller.zoomLevel = next;
  }

  void _retry() {
    setState(() {
      _pdf = _vm.openPdf(widget.book);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = _backgrounds[_mode];
    final Color fg = _textColors[_mode];
    final double percent = _page / _total;
    final ColorFilter filter = _filters[_mode];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          widget.book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Thu nhỏ',
            icon: const Icon(Icons.zoom_out),
            onPressed: _ready ? () => _zoom(-0.25) : null,
          ),
          IconButton(
            tooltip: 'Phóng to',
            icon: const Icon(Icons.zoom_in),
            onPressed: _ready ? () => _zoom(0.25) : null,
          ),
          IconButton(
            tooltip: _modeNames[(_mode + 1) % 3],
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () {
              setState(() {
                _mode = (_mode + 1) % 3;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (BuildContext context, AsyncSnapshot<Uint8List> snap) {
          if (snap.hasError) {
            final Object? e = snap.error;
            return ErrorState(
              message: e is ApiException ? e.message : 'Không mở được file PDF: $e',
              onRetry: _retry,
            );
          }
          final Uint8List? data = snap.data;
          if (data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(color: fg),
                  const SizedBox(height: 14),
                  Text('Đang tải nội dung sách...', style: TextStyle(color: fg)),
                ],
              ),
            );
          }
          return ColorFiltered(
            colorFilter: filter,
            // Nền xám nhạt quanh trang: qua bộ lọc nền tối thành xám đậm, nền giấy thành màu ngà
            // (nền tím nhạt mặc định của trình đọc khi đảo màu sẽ thành xanh lục).
            child: SfPdfViewerTheme(
            data: const SfPdfViewerThemeData(backgroundColor: Color(0xFFDCDFDB)),
            child: SfPdfViewer.memory(
            data,
            controller: _controller,
            initialPageNumber: _startPage,
            canShowScrollHead: false,
            canShowPaginationDialog: false,
            enableTextSelection: false,
            pageLayoutMode: PdfPageLayoutMode.single,
            scrollDirection: PdfScrollDirection.horizontal,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _ready = true;
                _total = details.document.pages.count;
              });
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              showSnack(context, 'File PDF bị lỗi: ${details.description}');
            },
            onPageChanged: _onPageChanged,
            ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_total > 1)
                Slider(
                  value: (_dragValue ?? _page.toDouble()).clamp(1, _total.toDouble()),
                  min: 1,
                  max: _total.toDouble(),
                  divisions: _total - 1,
                  activeColor: AppColors.accent,
                  label: 'Trang ${(_dragValue ?? _page).round()}',
                  onChanged: _ready
                      ? (double value) {
                          setState(() {
                            _dragValue = value;
                          });
                        }
                      : null,
                  // Kéo xong mới chuyển trang; onPageChanged sẽ cập nhật và lưu tiến độ.
                  onChangeEnd: _ready
                      ? (double value) {
                          setState(() {
                            _dragValue = null;
                          });
                          _controller.jumpToPage(value.round());
                        }
                      : null,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Trang $_page / $_total', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                    Text(
                      'Đã đọc ${(percent * 100).round()}%',
                      style: TextStyle(color: fg.withAlpha(170), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
