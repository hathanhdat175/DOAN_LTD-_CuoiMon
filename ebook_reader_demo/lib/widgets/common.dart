import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../services/api/bookhub_api.dart';
import 'book_cover.dart';

/// AppBar dùng chung cho các màn hình.
AppBar buildAppBar(
  String title, {
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
    actions: actions,
    bottom: bottom,
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
  );
}

/// Thẻ nền trắng bo góc, có viền mảnh.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Tiêu đề một nhóm nội dung, có thể kèm nút bên phải.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Màu tương ứng với trạng thái duyệt sách.
Color statusColor(BookStatus status) {
  switch (status) {
    case BookStatus.pending:
      return AppColors.warning;
    case BookStatus.approved:
      return AppColors.success;
    case BookStatus.rejected:
      return AppColors.danger;
  }
}

IconData statusIcon(BookStatus status) {
  switch (status) {
    case BookStatus.pending:
      return Icons.hourglass_empty;
    case BookStatus.approved:
      return Icons.check_circle_outline;
    case BookStatus.rejected:
      return Icons.cancel_outlined;
  }
}

/// Nhãn nhỏ dạng viên thuốc (dùng cho trạng thái, vai trò...).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final BookStatus status;

  @override
  Widget build(BuildContext context) {
    return Pill(text: status.label, color: statusColor(status), icon: statusIcon(status));
  }
}

/// Ô thống kê: một con số lớn kèm nhãn.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withAlpha(28), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lưới 2 cột chứa các ô thống kê.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: children,
    );
  }
}

/// Màn hình trống (chưa có dữ liệu).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một dòng sách: bìa nhỏ bên trái, thông tin ở giữa, nút tùy chọn bên phải.
class BookRow extends StatelessWidget {
  const BookRow({
    super.key,
    required this.book,
    this.subtitle,
    this.extra,
    this.trailing,
    this.onTap,
  });

  final Book book;
  final String? subtitle;
  final Widget? extra;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 58, child: BookCover(book: book, radius: 8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle ?? book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                if (extra != null) ...<Widget>[
                  const SizedBox(height: 8),
                  extra!,
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Biểu đồ cột đơn giản (tự vẽ bằng Container, không cần thư viện).
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AppColors.primary,
    this.height = 140,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    int maxValue = 1;
    for (final int v in values) {
      if (v > maxValue) {
        maxValue = v;
      }
    }

    return SizedBox(
      height: height + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      values[i].toString(),
                      maxLines: 1,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 4 + (height - 4) * values[i] / maxValue,
                      decoration: BoxDecoration(
                        color: i == values.length - 1 ? AppColors.accent : color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hiện thông báo ngắn ở cuối màn hình.
void showSnack(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

/// Chạy một thao tác gọi máy chủ: thành công thì hiện [success], lỗi thì hiện
/// thông báo lỗi do máy chủ trả về. Trả về `true` nếu thành công.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  void show(String message) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  try {
    await action();
    if (success != null) {
      show(success);
    }
    return true;
  } on ApiException catch (e) {
    show(e.message);
    return false;
  }
}

/// Hộp thoại "đang xử lý" chặn thao tác trong lúc chờ máy chủ.
Future<T> withProgress<T>(BuildContext context, Future<T> Function() task, {String message = 'Đang xử lý...'}) async {
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext _) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: <Widget>[
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6)),
            const SizedBox(width: 18),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    nav.pop();
  }
}

/// Màn hình lỗi tải dữ liệu kèm nút Thử lại.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 56, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

/// Vòng xoay đang tải ở giữa màn hình.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Hộp thoại xác nhận. Trả về `true` nếu người dùng đồng ý.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'Đồng ý',
  bool danger = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(okLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Hộp thoại nhập một dòng/đoạn văn bản. Trả về `null` nếu người dùng hủy.
Future<String?> promptDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String okLabel = 'Lưu',
  int maxLines = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _PromptDialog(
        title: title,
        label: label,
        initialValue: initialValue,
        okLabel: okLabel,
        maxLines: maxLines,
      );
    },
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.okLabel,
    required this.maxLines,
  });

  final String title;
  final String label;
  final String initialValue;
  final String okLabel;
  final int maxLines;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _error = 'Không được để trống';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.okLabel)),
      ],
    );
  }
}
