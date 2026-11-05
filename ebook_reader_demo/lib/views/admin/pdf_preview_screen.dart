import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/models.dart';
import '../../services/api/bookhub_api.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/common.dart';

/// Admin xem nội dung file PDF của sách (kể cả sách đang chờ duyệt) trước khi duyệt.
/// Màn hình này không ghi tiến độ đọc.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key, required this.book});

  final Book book;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late Future<Uint8List> _pdf;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _pdf = context.read<ReaderViewModel>().openPdf(widget.book);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(
        widget.book.title,
        actions: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('Trang $_page / ${widget.book.totalPages}'),
            ),
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
              onRetry: () => setState(() {
                _pdf = context.read<ReaderViewModel>().openPdf(widget.book);
              }),
            );
          }
          final Uint8List? data = snap.data;
          if (data == null) {
            return const LoadingState();
          }
          return SfPdfViewer.memory(
            data,
            canShowPaginationDialog: false,
            onPageChanged: (PdfPageChangedDetails details) {
              setState(() {
                _page = details.newPageNumber;
              });
            },
          );
        },
      ),
    );
  }
}
