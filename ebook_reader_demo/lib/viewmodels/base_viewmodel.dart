import 'package:flutter/foundation.dart';

import '../services/api/bookhub_api.dart';

/// Lớp cha của mọi ViewModel.
///
/// ViewModel lắng nghe nguồn dữ liệu [_source] (do Service cung cấp). Khi dữ liệu
/// thay đổi, ViewModel gọi [notifyListeners] để các widget `Consumer` vẽ lại.
/// [load] chạy một tác vụ tải dữ liệu và giữ trạng thái [loading] / [error] cho View.
abstract class BaseViewModel extends ChangeNotifier {
  BaseViewModel(this._source) {
    _source.addListener(notifyListeners);
  }

  final Listenable _source;
  bool _disposed = false;

  /// Đang tải dữ liệu lần đầu / làm mới.
  bool loading = false;

  /// Thông báo lỗi của lần tải gần nhất (null = không lỗi).
  String? error;

  /// Đã tải dữ liệu thành công ít nhất một lần.
  bool loaded = false;

  /// Chạy [task], cập nhật [loading] và [error]; lỗi được giữ lại để View hiển thị.
  Future<void> load(Future<void> Function() task) async {
    loading = true;
    error = null;
    _notify();
    try {
      await task();
      loaded = true;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _source.removeListener(notifyListeners);
    super.dispose();
  }
}
