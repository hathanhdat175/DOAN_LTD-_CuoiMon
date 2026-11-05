import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/publisher_viewmodel.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/common.dart';

/// Màn hình Đăng sách mới / Chỉnh sửa sách (khi truyền vào [book]).
///
/// - File PDF chọn bằng gói file_picker; số trang được đếm tự động từ file.
/// - Ảnh bìa chọn bằng gói image_picker (thư viện ảnh hoặc camera).
/// - Hai file được gửi lên máy chủ dạng multipart/form-data (Multer lưu vào uploads/).
class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key, this.book});

  final Book? book;

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _pagesCtrl;
  String? _categoryId;
  String? _pdfName;
  UploadFile? _pdf;
  String? _coverName;
  Uint8List? _coverBytes;

  /// Sách đang sửa có ảnh bìa trên máy chủ (chưa bị bỏ / thay).
  bool _keepServerCover = false;
  bool _sending = false;

  bool get _isEdit => widget.book != null;

  @override
  void initState() {
    super.initState();
    final Book? book = widget.book;
    _titleCtrl = TextEditingController(text: book == null ? '' : book.title);
    _authorCtrl = TextEditingController(text: book == null ? '' : book.author);
    _descCtrl = TextEditingController(text: book == null ? '' : book.description);
    _pagesCtrl = TextEditingController(text: book == null ? '' : book.totalPages.toString());
    if (book != null) {
      _categoryId = book.categoryId;
      _pdfName = 'File hiện tại (${book.totalPages} trang)';
      _keepServerCover = book.coverUrl != null;
      _coverName = _keepServerCover ? 'Ảnh bìa hiện tại' : null;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    _pagesCtrl.dispose();
    super.dispose();
  }

  /// Chọn file PDF bằng file_picker và đếm số trang bằng syncfusion_flutter_pdf.
  Future<void> _pickPdf() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: <String>['pdf']);
    } on PlatformException catch (e) {
      if (mounted) {
        showSnack(context, 'Không mở được trình chọn file: ${e.message ?? e.code}');
      }
      return;
    }
    if (file == null) {
      return; // Người dùng bấm Hủy.
    }
    final PlatformFile picked = file;
    final Uint8List bytes = await picked.xFile.readAsBytes();
    if (bytes.length > 50 * 1024 * 1024) {
      if (mounted) {
        showSnack(context, 'File PDF quá lớn (tối đa 50 MB)');
      }
      return;
    }
    int? pages;
    try {
      final PdfDocument doc = PdfDocument(inputBytes: bytes);
      pages = doc.pages.count;
      doc.dispose();
    } catch (_) {
      if (mounted) {
        showSnack(context, 'File PDF bị lỗi hoặc không đọc được');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pdf = UploadFile(name: picked.name, bytes: bytes);
      _pdfName = picked.name;
      _pagesCtrl.text = pages.toString();
    });
  }

  /// Camera chỉ có trên điện thoại; trên web/máy tính chỉ chọn từ thư viện ảnh.
  bool get _canUseCamera =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickCover() async {
    ImageSource? source = ImageSource.gallery;
    final bool hasCover = _coverBytes != null || _keepServerCover;
    if (_canUseCamera || hasCover) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn từ thư viện ảnh'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              if (_canUseCamera)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              if (hasCover)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: const Text('Bỏ ảnh bìa (dùng bìa mặc định)'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _coverBytes = null;
                      _coverName = null;
                      _keepServerCover = false;
                    });
                  },
                ),
            ],
          ),
        ),
      );
    }
    if (source == null) {
      return;
    }

    try {
      // Thu nhỏ ảnh để tiết kiệm bộ nhớ (bìa sách không cần ảnh quá lớn).
      final XFile? file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 1350,
        imageQuality: 85,
      );
      if (file == null) {
        return; // Người dùng bấm Hủy.
      }
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _coverBytes = bytes;
        _coverName = file.name;
        _keepServerCover = false;
      });
    } on PlatformException catch (e) {
      if (mounted) {
        showSnack(context, 'Không mở được ảnh: ${e.message ?? e.code}');
      }
    }
  }

  Future<void> _submit() async {
    if (_sending) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final String? categoryId = _categoryId;
    if (categoryId == null) {
      showSnack(context, 'Vui lòng chọn thể loại');
      return;
    }
    final Book? book = widget.book;
    if (book == null && _pdf == null) {
      showSnack(context, 'Vui lòng chọn file PDF của sách');
      return;
    }
    final Uint8List? coverBytes = _coverBytes;
    final BookDraft draft = BookDraft(
      title: _titleCtrl.text.trim(),
      author: _authorCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      categoryId: categoryId,
      totalPages: int.tryParse(_pagesCtrl.text.trim()) ?? 1,
      pdf: _pdf,
      cover: coverBytes == null ? null : UploadFile(name: _coverName ?? 'cover.jpg', bytes: coverBytes),
      removeCover: book != null && book.coverUrl != null && !_keepServerCover && coverBytes == null,
    );

    setState(() {
      _sending = true;
    });
    final PublisherViewModel vm = context.read<PublisherViewModel>();
    final NavigatorState nav = Navigator.of(context);
    // Lỗi mạng hoặc lỗi dữ liệu: giữ nguyên form để người dùng gửi lại.
    final bool ok = await runAction(
      context,
      () => book == null ? vm.addBook(draft) : vm.updateBook(book.id, draft),
      success: book == null ? 'Đã gửi sách, vui lòng chờ Admin duyệt' : 'Đã cập nhật, sách được gửi duyệt lại',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _sending = false;
    });
    if (ok) {
      nav.pop();
    }
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Không được để trống';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(_isEdit ? 'Chỉnh sửa sách' : 'Đăng sách mới'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: <Widget>[
            const SectionTitle('Tệp đính kèm'),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _FilePickerBox(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'File PDF',
                    fileName: _pdfName,
                    onTap: _pickPdf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FilePickerBox(
                    icon: Icons.image_outlined,
                    label: 'Ảnh bìa',
                    fileName: _coverName,
                    previewBytes: _coverBytes,
                    preview: _keepServerCover && widget.book != null
                        ? SizedBox(width: 43, child: BookCover(book: widget.book!, radius: 6))
                        : null,
                    onTap: _pickCover,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle('Thông tin sách'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: fieldDecoration('Tên sách', icon: Icons.menu_book_outlined),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _authorCtrl,
              textInputAction: TextInputAction.next,
              decoration: fieldDecoration('Tác giả', icon: Icons.person_outline),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pagesCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              readOnly: _pdf != null || _isEdit,
              decoration: fieldDecoration(
                _pdf != null || _isEdit ? 'Số trang (đếm tự động từ file PDF)' : 'Số trang',
                icon: Icons.description_outlined,
              ),
              validator: (String? value) {
                final int? pages = int.tryParse((value ?? '').trim());
                if (pages == null || pages < 1) {
                  return 'Số trang phải là số nguyên lớn hơn 0';
                }
                if (pages > 5000) {
                  return 'Số trang tối đa là 5000';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: fieldDecoration('Mô tả ngắn'),
              validator: _required,
            ),
            const SizedBox(height: 24),
            const SectionTitle('Thể loại'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final BookCategory c in context.watch<PublisherViewModel>().categories)
                  ChoiceChip(
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (bool _) {
                      setState(() {
                        _categoryId = c.id;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Icon(_isEdit ? Icons.save_outlined : Icons.send_outlined),
                label: Text(
                  _sending ? 'Đang tải lên...' : (_isEdit ? 'Lưu và gửi duyệt lại' : 'Gửi duyệt'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sách sau khi gửi sẽ ở trạng thái “Chờ duyệt” cho đến khi Admin kiểm duyệt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô chọn file (PDF hoặc ảnh bìa).
class _FilePickerBox extends StatelessWidget {
  const _FilePickerBox({
    required this.icon,
    required this.label,
    required this.fileName,
    required this.onTap,
    this.previewBytes,
    this.preview,
  });

  final IconData icon;
  final String label;
  final String? fileName;
  final VoidCallback onTap;

  /// Ảnh xem trước (chỉ có ở ô Ảnh bìa sau khi chọn ảnh).
  final Uint8List? previewBytes;

  /// Ảnh xem trước dạng widget (ảnh bìa hiện tại trên máy chủ).
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final bool picked = fileName != null;

    return AppCard(
      onTap: onTap,
      color: picked ? AppColors.primarySoft : AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        children: <Widget>[
          if (preview != null)
            SizedBox(height: 64, child: preview)
          else if (previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(previewBytes!, height: 64, width: 43, fit: BoxFit.cover),
            )
          else
            Icon(
              picked ? Icons.check_circle : icon,
              size: 32,
              color: picked ? AppColors.success : AppColors.primary,
            ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(
            fileName ?? 'Chạm để chọn',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
