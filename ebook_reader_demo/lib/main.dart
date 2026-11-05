import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'services/admin_service.dart';
import 'services/api/api_config.dart';
import 'services/api/bookhub_api.dart';
import 'services/api/mock_api.dart';
import 'services/api/rest_api.dart';
import 'services/app_store.dart';
import 'services/auth_service.dart';
import 'services/book_service.dart';
import 'services/local/local_cache.dart';
import 'services/local/token_storage.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/publisher_viewmodel.dart';
import 'viewmodels/reader_viewmodel.dart';
import 'views/auth/splash_screen.dart';
import 'widgets/phone_frame.dart';

/// Điểm bắt đầu của ứng dụng.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final BookHubApi api = ApiConfig.useMock ? MockBookHubApi() : RestBookHubApi();
  runApp(
    createApp(
      store: AppStore(
        api: api,
        tokens: SecureTokenStorage(),
        // Trình duyệt không có sqflite nên bản web dùng bộ nhớ đệm trong RAM.
        cache: kIsWeb ? MemoryLocalCache() : SqfliteLocalCache(),
      ),
    ),
  );
}

/// Tạo cây ứng dụng theo kiến trúc MVVM:
///
///   View (lib/views) → ViewModel (lib/viewmodels) → Service (lib/services) → BookHubApi → REST API → SQL Server
///
/// [MultiProvider] cung cấp các ViewModel cho toàn bộ cây widget. Màn hình đọc
/// dữ liệu bằng `Consumer<...>` / `context.watch` và gọi hành động bằng `context.read`.
/// Hàm này cũng được dùng trong `test/widget_test.dart` với [MockBookHubApi].
Widget createApp({AppStore? store}) {
  final AppStore appStore = store ?? AppStore(api: MockBookHubApi());
  final AuthService authService = AuthService(appStore);
  final BookService bookService = BookService(appStore);
  final AdminService adminService = AdminService(appStore);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthViewModel>(create: (BuildContext _) => AuthViewModel(authService)),
      ChangeNotifierProvider<ReaderViewModel>(create: (BuildContext _) => ReaderViewModel(bookService)),
      ChangeNotifierProvider<PublisherViewModel>(create: (BuildContext _) => PublisherViewModel(bookService)),
      ChangeNotifierProvider<AdminViewModel>(create: (BuildContext _) => AdminViewModel(adminService)),
    ],
    child: const BookHubApp(),
  );
}

class BookHubApp extends StatelessWidget {
  const BookHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookHub',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Khi chạy trên Chrome/Windows, khung PhoneFrame giữ giao diện ở bề rộng điện thoại.
      builder: (BuildContext context, Widget? child) => PhoneFrame(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}
