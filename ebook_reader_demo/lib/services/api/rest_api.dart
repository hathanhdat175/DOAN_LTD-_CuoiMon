import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/models.dart';
import 'api_config.dart';
import 'bookhub_api.dart';

/// Gọi REST API của máy chủ BookHub (Node.js/Express + SQL Server) bằng thư viện Dio.
///
/// Mỗi request được đính kèm header `Authorization: Bearer <JWT>`.
/// Lỗi HTTP được đổi thành [ApiException] chứa thông báo do máy chủ trả về.
class RestBookHubApi implements BookHubApi {
  RestBookHubApi({String? baseUrl, Dio? dio})
      : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = _baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 60);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final String? t = token;
          if (t != null) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
      ),
    );
  }

  final String _baseUrl;
  final Dio _dio;

  @override
  String? token;

  @override
  String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('http')) {
      return path;
    }
    return '$_baseUrl$path';
  }

  // ---------------------------------------------------------------------------
  // Hàm gọi chung
  // ---------------------------------------------------------------------------

  Future<T> _send<T>(Future<Response<dynamic>> Function() request, T Function(dynamic data) parse) async {
    try {
      final Response<dynamic> res = await request();
      return parse(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final Response<dynamic>? res = e.response;
    if (res == null) {
      return ApiException('Không kết nối được máy chủ ($_baseUrl). Kiểm tra mạng hoặc máy chủ API.');
    }
    final dynamic data = res.data;
    String message = 'Có lỗi xảy ra (mã ${res.statusCode}).';
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    }
    return ApiException(message, statusCode: res.statusCode);
  }

  Future<T> _get<T>(String path, T Function(dynamic data) parse, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query), parse);

  Future<T> _post<T>(String path, T Function(dynamic data) parse, {Object? data}) =>
      _send(() => _dio.post<dynamic>(path, data: data), parse);

  Future<T> _put<T>(String path, T Function(dynamic data) parse, {Object? data}) =>
      _send(() => _dio.put<dynamic>(path, data: data), parse);

  Future<T> _patch<T>(String path, T Function(dynamic data) parse, {Object? data}) =>
      _send(() => _dio.patch<dynamic>(path, data: data), parse);

  Future<void> _delete(String path, {Object? data}) =>
      _send(() => _dio.delete<dynamic>(path, data: data), (dynamic _) {});

  static List<Book> _books(dynamic data) =>
      (data as List<dynamic>).map((dynamic e) => Book.fromJson(e as Map<String, dynamic>)).toList();

  static Book _book(dynamic data) => Book.fromJson(data as Map<String, dynamic>);

  static AuthResult _auth(dynamic data) {
    final Map<String, dynamic> map = data as Map<String, dynamic>;
    return AuthResult(token: map['token'] as String, user: AppUser.fromJson(map['user'] as Map<String, dynamic>));
  }

  // ---------------------------------------------------------------------------
  // Xác thực
  // ---------------------------------------------------------------------------

  @override
  Future<AuthResult> login(String email, String password) =>
      _post('/api/auth/login', _auth, data: <String, dynamic>{'email': email, 'password': password});

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) {
    return _post(
      '/api/auth/register',
      _auth,
      data: <String, dynamic>{'fullName': name, 'email': email, 'password': password, 'role': role.code},
    );
  }

  @override
  Future<AppUser> me() => _get('/api/auth/me', (dynamic d) => AppUser.fromJson(d as Map<String, dynamic>));

  // ---------------------------------------------------------------------------
  // Reader
  // ---------------------------------------------------------------------------

  @override
  Future<List<BookCategory>> getCategories() => _get(
        '/api/categories',
        (dynamic d) =>
            (d as List<dynamic>).map((dynamic e) => BookCategory.fromJson(e as Map<String, dynamic>)).toList(),
      );

  @override
  Future<List<Book>> getBooks({String query = '', String? categoryId}) => _get(
        '/api/books',
        _books,
        query: <String, dynamic>{
          if (query.trim().isNotEmpty) 'q': query.trim(),
          if (categoryId != null) 'categoryId': categoryId,
        },
      );

  @override
  Future<Book> getBook(String id) => _get('/api/books/$id', _book);

  @override
  Future<int> addView(String id) =>
      _post('/api/books/$id/view', (dynamic d) => parseInt((d as Map<String, dynamic>)['views']));

  @override
  Future<Uint8List> downloadPdf(String id, {void Function(int received, int total)? onProgress}) {
    return _send(
      () => _dio.get<List<int>>(
        '/api/books/$id/file',
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: onProgress,
      ),
      (dynamic d) => Uint8List.fromList(d as List<int>),
    );
  }

  @override
  Future<List<AppNotice>> getNotifications() => _get(
        '/api/notifications',
        (dynamic d) => (d as List<dynamic>).map((dynamic e) => AppNotice.fromJson(e as Map<String, dynamic>)).toList(),
      );

  @override
  Future<int> getUnreadCount() => _get(
        '/api/notifications/unread-count',
        (dynamic d) => parseInt((d as Map<String, dynamic>)['count']),
      );

  @override
  Future<void> markNotificationsRead() => _post('/api/notifications/read-all', (dynamic _) {});

  @override
  Future<void> registerDevice(String token, String platform) => _put(
        '/api/me/device-token',
        (dynamic _) {},
        data: <String, dynamic>{'token': token, 'platform': platform},
      );

  @override
  Future<void> unregisterDevice(String token) =>
      _delete('/api/me/device-token', data: <String, dynamic>{'token': token});

  @override
  Future<List<Book>> getFavorites() => _get('/api/me/favorites', _books);

  @override
  Future<void> setFavorite(String bookId, bool favorite) => favorite
      ? _put('/api/me/favorites/$bookId', (dynamic _) {})
      : _delete('/api/me/favorites/$bookId');

  @override
  Future<void> setDownloaded(String bookId, bool downloaded) => downloaded
      ? _put('/api/me/downloads/$bookId', (dynamic _) {})
      : _delete('/api/me/downloads/$bookId');

  @override
  Future<List<ReadingRecord>> getProgress() => _get(
        '/api/me/progress',
        (dynamic d) =>
            (d as List<dynamic>).map((dynamic e) => ReadingRecord.fromJson(e as Map<String, dynamic>)).toList(),
      );

  @override
  Future<ReadingRecord> saveProgress(String bookId, int page) => _put(
        '/api/me/progress/$bookId',
        (dynamic d) => ReadingRecord.fromJson(d as Map<String, dynamic>),
        data: <String, dynamic>{'page': page},
      );

  // ---------------------------------------------------------------------------
  // Publisher
  // ---------------------------------------------------------------------------

  FormData _bookForm(BookDraft draft) {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'title': draft.title,
      'author': draft.author,
      'description': draft.description,
      'categoryId': draft.categoryId,
      'totalPages': draft.totalPages.toString(),
      'removeCover': draft.removeCover.toString(),
    });
    final UploadFile? pdf = draft.pdf;
    if (pdf != null) {
      form.files.add(MapEntry<String, MultipartFile>(
        'pdf',
        MultipartFile.fromBytes(pdf.bytes, filename: pdf.name, contentType: DioMediaType('application', 'pdf')),
      ));
    }
    final UploadFile? cover = draft.cover;
    if (cover != null) {
      form.files.add(MapEntry<String, MultipartFile>(
        'cover',
        MultipartFile.fromBytes(cover.bytes, filename: cover.name, contentType: _imageType(cover.name)),
      ));
    }
    return form;
  }

  static DioMediaType _imageType(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) {
      return DioMediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return DioMediaType('image', 'webp');
    }
    if (lower.endsWith('.gif')) {
      return DioMediaType('image', 'gif');
    }
    return DioMediaType('image', 'jpeg');
  }

  @override
  Future<List<Book>> getMyBooks() => _get('/api/publisher/books', _books);

  @override
  Future<Book> createBook(BookDraft draft) => _post('/api/publisher/books', _book, data: _bookForm(draft));

  @override
  Future<Book> updateBook(String id, BookDraft draft) =>
      _put('/api/publisher/books/$id', _book, data: _bookForm(draft));

  @override
  Future<void> deleteMyBook(String id) => _delete('/api/publisher/books/$id');

  // ---------------------------------------------------------------------------
  // Admin
  // ---------------------------------------------------------------------------

  @override
  Future<AdminStats> getAdminStats() =>
      _get('/api/admin/stats', (dynamic d) => AdminStats.fromJson(d as Map<String, dynamic>));

  @override
  Future<List<Book>> getAdminBooks({BookStatus? status}) => _get(
        '/api/admin/books',
        _books,
        query: <String, dynamic>{if (status != null) 'status': status.code},
      );

  @override
  Future<Book> approveBook(String id) => _patch('/api/admin/books/$id/approve', _book);

  @override
  Future<Book> rejectBook(String id, String reason) =>
      _patch('/api/admin/books/$id/reject', _book, data: <String, dynamic>{'reason': reason});

  @override
  Future<void> adminDeleteBook(String id) => _delete('/api/admin/books/$id');

  @override
  Future<List<AppUser>> getUsers() => _get(
        '/api/admin/users',
        (dynamic d) => (d as List<dynamic>).map((dynamic e) => AppUser.fromJson(e as Map<String, dynamic>)).toList(),
      );

  @override
  Future<AppUser> setUserLocked(String id, bool locked) => _patch(
        '/api/admin/users/$id/lock',
        (dynamic d) => AppUser.fromJson(d as Map<String, dynamic>),
        data: <String, dynamic>{'locked': locked},
      );

  @override
  Future<BookCategory> addCategory(String name) => _post(
        '/api/admin/categories',
        (dynamic d) => BookCategory.fromJson(d as Map<String, dynamic>),
        data: <String, dynamic>{'name': name},
      );

  @override
  Future<BookCategory> renameCategory(String id, String name) => _put(
        '/api/admin/categories/$id',
        (dynamic d) => BookCategory.fromJson(d as Map<String, dynamic>),
        data: <String, dynamic>{'name': name},
      );

  @override
  Future<void> deleteCategory(String id) => _delete('/api/admin/categories/$id');

  @override
  Future<void> sendNotification(String title, String body) =>
      _post('/api/admin/notifications', (dynamic _) {}, data: <String, dynamic>{'title': title, 'body': body});

  @override
  Future<AdminReport> getReport(ReportRange range) => _get(
        '/api/admin/reports',
        (dynamic d) => AdminReport.fromJson(d as Map<String, dynamic>),
        query: <String, dynamic>{'range': range.code},
      );
}
