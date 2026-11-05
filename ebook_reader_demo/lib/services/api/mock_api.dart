import 'dart:convert';
import 'dart:typed_data';

import '../../models/models.dart';
import '../../utils/password_policy.dart';
import 'bookhub_api.dart';

/// Máy chủ giả lập trong bộ nhớ, có cùng quy tắc nghiệp vụ với REST API.
///
/// Dùng cho kiểm thử tự động (`flutter test`) và để chạy thử giao diện khi
/// chưa bật máy chủ: `flutter run --dart-define=USE_MOCK=true`.
/// Dữ liệu mẫu giống script `database/bookhub_sqlserver.sql`.
class MockBookHubApi implements BookHubApi {
  MockBookHubApi({bool withSampleData = true, this.latency = Duration.zero}) {
    if (withSampleData) {
      _seed();
    }
  }

  /// Độ trễ giả lập của mỗi request.
  final Duration latency;

  final List<_MUser> _users = <_MUser>[];
  final List<BookCategory> _categories = <BookCategory>[];
  final List<_MBook> _books = <_MBook>[];
  final List<_MNotice> _notices = <_MNotice>[];
  final Map<String, ReadingRecord> _progress = <String, ReadingRecord>{}; // key: userId:bookId
  final Map<String, Set<String>> _favorites = <String, Set<String>>{};

  /// Sách đã tải về theo người dùng (giống bảng Downloads).
  final Map<String, Set<String>> downloadsByUser = <String, Set<String>>{};
  int _counter = 100;

  @override
  String? token;

  String _newId() => (++_counter).toString();

  Future<void> _delay() => latency == Duration.zero ? Future<void>.value() : Future<void>.delayed(latency);

  @override
  String? resolveUrl(String? path) => path;

  // ---------------------------------------------------------------------------
  // Kiểm tra quyền (giống middleware authenticate / requireRole của máy chủ)
  // ---------------------------------------------------------------------------

  _MUser _auth([List<UserRole>? roles]) {
    final String? t = token;
    _MUser? user;
    for (final _MUser u in _users) {
      if ('mock-token-${u.id}' == t) {
        user = u;
      }
    }
    if (user == null) {
      throw ApiException('Vui lòng đăng nhập.', statusCode: 401);
    }
    if (user.locked) {
      throw ApiException('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.', statusCode: 403);
    }
    if (roles != null && !roles.contains(user.role)) {
      throw ApiException('Bạn không có quyền thực hiện thao tác này.', statusCode: 403);
    }
    return user;
  }

  _MBook _findBook(String id) {
    for (final _MBook b in _books) {
      if (b.id == id) {
        return b;
      }
    }
    throw ApiException('Sách không tồn tại hoặc đã bị gỡ.', statusCode: 404);
  }

  String _catName(String id) {
    for (final BookCategory c in _categories) {
      if (c.id == id) {
        return c.name;
      }
    }
    return 'Chưa phân loại';
  }

  String _userName(String id) {
    for (final _MUser u in _users) {
      if (u.id == id) {
        return u.name;
      }
    }
    return 'Không rõ';
  }

  Book _toBook(_MBook b) => Book(
        id: b.id,
        title: b.title,
        author: b.author,
        description: b.description,
        categoryId: b.categoryId,
        categoryName: _catName(b.categoryId),
        publisherId: b.publisherId,
        publisherName: _userName(b.publisherId),
        totalPages: b.totalPages,
        createdAt: b.createdAt,
        status: b.status,
        rejectReason: b.rejectReason,
        reviewedAt: b.reviewedAt,
        views: b.views,
      );

  List<Book> _sorted(Iterable<_MBook> list) {
    final List<_MBook> l = list.toList()..sort((_MBook a, _MBook b) => b.createdAt.compareTo(a.createdAt));
    return l.map(_toBook).toList();
  }

  // ---------------------------------------------------------------------------
  // Xác thực
  // ---------------------------------------------------------------------------

  /// Sai mật khẩu liên tiếp bao nhiêu lần thì tạm khóa, và khóa trong bao lâu (giống máy chủ).
  static const int maxLoginAttempts = 5;
  static const Duration loginLockDuration = Duration(minutes: 15);

  @override
  Future<AuthResult> login(String email, String password) async {
    await _delay();
    const String wrong = 'Email hoặc mật khẩu không đúng.';
    final String mail = email.trim().toLowerCase();
    for (final _MUser u in _users) {
      if (u.email == mail) {
        final DateTime? until = u.lockoutUntil;
        if (until != null && until.isAfter(DateTime.now())) {
          final int minutes = (until.difference(DateTime.now()).inSeconds / 60).ceil();
          throw ApiException(
            'Bạn đã nhập sai mật khẩu quá nhiều lần. Vui lòng thử lại sau $minutes phút.',
            statusCode: 429,
          );
        }
        if (u.password != password) {
          u.failedLogins++;
          if (u.failedLogins >= maxLoginAttempts) {
            u.failedLogins = 0;
            u.lockoutUntil = DateTime.now().add(loginLockDuration);
            throw ApiException(
              'Bạn đã nhập sai mật khẩu $maxLoginAttempts lần. '
              'Đăng nhập bị tạm khóa ${loginLockDuration.inMinutes} phút.',
              statusCode: 429,
            );
          }
          final int left = maxLoginAttempts - u.failedLogins;
          throw ApiException(
            left <= 2 ? '$wrong Còn $left lần thử trước khi bị tạm khóa.' : wrong,
            statusCode: 401,
          );
        }
        if (u.locked) {
          throw ApiException('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.', statusCode: 403);
        }
        u.failedLogins = 0;
        u.lockoutUntil = null;
        return AuthResult(token: 'mock-token-${u.id}', user: u.toUser());
      }
    }
    throw ApiException(wrong, statusCode: 401);
  }

  @override
  Future<AuthResult> changePassword(String currentPassword, String newPassword) async {
    await _delay();
    final _MUser u = _auth();
    if (u.password != currentPassword) {
      throw ApiException('Mật khẩu hiện tại không đúng.', statusCode: 400);
    }
    if (currentPassword == newPassword) {
      throw ApiException('Mật khẩu mới phải khác mật khẩu hiện tại.', statusCode: 400);
    }
    final String? error = PasswordPolicy.validate(newPassword, email: u.email);
    if (error != null) {
      throw ApiException('$error.', statusCode: 400);
    }
    u.password = newPassword;
    return AuthResult(token: 'mock-token-${u.id}', user: u.toUser());
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _delay();
    final String mail = email.trim().toLowerCase();
    if (_users.any((_MUser u) => u.email == mail)) {
      throw ApiException('Email này đã được sử dụng.', statusCode: 409);
    }
    if (role == UserRole.admin) {
      throw ApiException('Chỉ được đăng ký vai trò Reader hoặc Publisher.', statusCode: 400);
    }
    final String? weak = PasswordPolicy.validate(password, email: mail);
    if (weak != null) {
      throw ApiException('$weak.', statusCode: 400);
    }
    final _MUser u = _MUser(_newId(), name.trim(), mail, password, role, DateTime.now());
    _users.add(u);
    return AuthResult(token: 'mock-token-${u.id}', user: u.toUser());
  }

  @override
  Future<AppUser> me() async {
    await _delay();
    return _auth().toUser();
  }

  // ---------------------------------------------------------------------------
  // Reader
  // ---------------------------------------------------------------------------

  @override
  Future<List<BookCategory>> getCategories() async {
    await _delay();
    _auth();
    return _categories
        .map((BookCategory c) => BookCategory(
              id: c.id,
              name: c.name,
              bookCount: _books.where((_MBook b) => b.categoryId == c.id).length,
            ))
        .toList();
  }

  @override
  Future<List<Book>> getBooks({String query = '', String? categoryId}) async {
    await _delay();
    _auth();
    final String q = query.trim().toLowerCase();
    return _sorted(_books.where((_MBook b) =>
        b.status == BookStatus.approved &&
        (categoryId == null || b.categoryId == categoryId) &&
        (q.isEmpty || b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q))));
  }

  _MBook _visibleBook(String id) {
    final _MUser u = _auth();
    final _MBook b = _findBook(id);
    if (b.status != BookStatus.approved && u.role != UserRole.admin && b.publisherId != u.id) {
      throw ApiException('Sách chưa được duyệt hoặc đã bị gỡ.', statusCode: 403);
    }
    return b;
  }

  @override
  Future<Book> getBook(String id) async {
    await _delay();
    return _toBook(_visibleBook(id));
  }

  @override
  Future<int> addView(String id) async {
    await _delay();
    final _MBook b = _visibleBook(id);
    b.views++;
    return b.views;
  }

  @override
  Future<Uint8List> downloadPdf(String id, {void Function(int received, int total)? onProgress}) async {
    await _delay();
    final _MBook b = _visibleBook(id);
    final Uint8List bytes = buildSamplePdf(b.title, b.totalPages);
    onProgress?.call(bytes.length, bytes.length);
    return bytes;
  }

  @override
  Future<List<AppNotice>> getNotifications() async {
    await _delay();
    final _MUser u = _auth();
    final List<_MNotice> list = _notices.where((_MNotice n) => n.recipientId == null || n.recipientId == u.id).toList()
      ..sort((_MNotice a, _MNotice b) => b.sentAt.compareTo(a.sentAt));
    return list
        .map((_MNotice n) => AppNotice(
              id: n.id,
              title: n.title,
              body: n.body,
              sentAt: n.sentAt,
              personal: n.recipientId != null,
              isRead: int.parse(n.id) <= u.lastReadNotice,
            ))
        .toList();
  }

  Iterable<_MNotice> _visibleNotices(_MUser u) =>
      _notices.where((_MNotice n) => n.recipientId == null || n.recipientId == u.id);

  @override
  Future<int> getUnreadCount() async {
    await _delay();
    final _MUser u = _auth();
    return _visibleNotices(u).where((_MNotice n) => int.parse(n.id) > u.lastReadNotice).length;
  }

  @override
  Future<void> markNotificationsRead() async {
    await _delay();
    final _MUser u = _auth();
    for (final _MNotice n in _visibleNotices(u)) {
      final int id = int.parse(n.id);
      if (id > u.lastReadNotice) {
        u.lastReadNotice = id;
      }
    }
  }

  /// Mã thiết bị nhận thông báo đẩy (giống bảng DeviceTokens): token → mã người dùng.
  final Map<String, String> deviceTokens = <String, String>{};

  @override
  Future<void> registerDevice(String token, String platform) async {
    await _delay();
    final _MUser u = _auth();
    if (token.trim().isEmpty) {
      throw ApiException('Mã thiết bị (token) không hợp lệ.', statusCode: 400);
    }
    deviceTokens[token] = u.id;
  }

  @override
  Future<void> unregisterDevice(String token) async {
    await _delay();
    final _MUser u = _auth();
    if (deviceTokens[token] == u.id) {
      deviceTokens.remove(token);
    }
  }

  @override
  Future<List<Book>> getFavorites() async {
    await _delay();
    final _MUser u = _auth();
    final Set<String> ids = _favorites[u.id] ?? <String>{};
    return _sorted(_books.where((_MBook b) => ids.contains(b.id) && b.status == BookStatus.approved));
  }

  @override
  Future<void> setFavorite(String bookId, bool favorite) async {
    await _delay();
    final _MUser u = _auth();
    final Set<String> ids = _favorites.putIfAbsent(u.id, () => <String>{});
    if (favorite) {
      if (_findBook(bookId).status != BookStatus.approved) {
        throw ApiException('Sách không tồn tại hoặc chưa được duyệt.', statusCode: 404);
      }
      ids.add(bookId);
    } else {
      ids.remove(bookId);
    }
  }

  @override
  Future<void> setDownloaded(String bookId, bool downloaded) async {
    await _delay();
    final _MUser u = _auth();
    final Set<String> ids = downloadsByUser.putIfAbsent(u.id, () => <String>{});
    if (downloaded) {
      if (_findBook(bookId).status != BookStatus.approved) {
        throw ApiException('Sách không tồn tại hoặc chưa được duyệt.', statusCode: 404);
      }
      ids.add(bookId);
    } else {
      ids.remove(bookId);
    }
  }

  @override
  Future<List<ReadingRecord>> getProgress() async {
    await _delay();
    final _MUser u = _auth();
    final List<ReadingRecord> list = <ReadingRecord>[];
    _progress.forEach((String key, ReadingRecord r) {
      if (key.startsWith('${u.id}:')) {
        final _MBook b = _findBook(r.bookId);
        if (b.status == BookStatus.approved) {
          list.add(ReadingRecord(bookId: r.bookId, page: r.page, updatedAt: r.updatedAt, book: _toBook(b)));
        }
      }
    });
    list.sort((ReadingRecord a, ReadingRecord b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<ReadingRecord> saveProgress(String bookId, int page) async {
    await _delay();
    final _MUser u = _auth();
    final _MBook b = _findBook(bookId);
    if (b.status != BookStatus.approved) {
      throw ApiException('Sách không tồn tại hoặc chưa được duyệt.', statusCode: 404);
    }
    final int p = page < 1 ? 1 : (page > b.totalPages ? b.totalPages : page);
    final ReadingRecord r = ReadingRecord(bookId: bookId, page: p, updatedAt: DateTime.now());
    _progress['${u.id}:$bookId'] = r;
    return ReadingRecord(bookId: bookId, page: p, updatedAt: r.updatedAt);
  }

  // ---------------------------------------------------------------------------
  // Publisher
  // ---------------------------------------------------------------------------

  void _validateDraft(BookDraft d) {
    if (d.title.trim().isEmpty) {
      throw ApiException('Vui lòng nhập tên sách.', statusCode: 400);
    }
    if (d.author.trim().isEmpty) {
      throw ApiException('Vui lòng nhập tác giả.', statusCode: 400);
    }
    if (d.totalPages < 1) {
      throw ApiException('Số trang phải là số nguyên từ 1 đến 5000.', statusCode: 400);
    }
    if (!_categories.any((BookCategory c) => c.id == d.categoryId)) {
      throw ApiException('Thể loại không tồn tại.', statusCode: 400);
    }
  }

  _MBook _ownBook(_MUser u, String id) {
    final _MBook b = _findBook(id);
    if (b.publisherId != u.id) {
      throw ApiException('Bạn chỉ được thao tác trên sách do mình đăng.', statusCode: 403);
    }
    return b;
  }

  @override
  Future<List<Book>> getMyBooks() async {
    await _delay();
    final _MUser u = _auth(<UserRole>[UserRole.publisher]);
    return _sorted(_books.where((_MBook b) => b.publisherId == u.id));
  }

  @override
  Future<Book> createBook(BookDraft draft) async {
    await _delay();
    final _MUser u = _auth(<UserRole>[UserRole.publisher]);
    if (draft.pdf == null) {
      throw ApiException('Vui lòng chọn file PDF của sách.', statusCode: 400);
    }
    _validateDraft(draft);
    final _MBook b = _MBook(
      id: _newId(),
      title: draft.title.trim(),
      author: draft.author.trim(),
      description: draft.description.trim(),
      categoryId: draft.categoryId,
      publisherId: u.id,
      totalPages: draft.totalPages,
      createdAt: DateTime.now(),
    );
    _books.add(b);
    return _toBook(b);
  }

  @override
  Future<Book> updateBook(String id, BookDraft draft) async {
    await _delay();
    final _MUser u = _auth(<UserRole>[UserRole.publisher]);
    final _MBook b = _ownBook(u, id);
    _validateDraft(draft);
    b
      ..title = draft.title.trim()
      ..author = draft.author.trim()
      ..description = draft.description.trim()
      ..categoryId = draft.categoryId
      ..totalPages = draft.pdf == null ? b.totalPages : draft.totalPages
      ..status = BookStatus.pending
      ..rejectReason = null
      ..reviewedAt = null;
    return _toBook(b);
  }

  void _removeBook(String id) {
    _books.removeWhere((_MBook b) => b.id == id);
    _progress.removeWhere((String _, ReadingRecord r) => r.bookId == id);
    for (final Set<String> s in _favorites.values) {
      s.remove(id);
    }
  }

  @override
  Future<void> deleteMyBook(String id) async {
    await _delay();
    final _MUser u = _auth(<UserRole>[UserRole.publisher]);
    _ownBook(u, id);
    _removeBook(id);
  }

  // ---------------------------------------------------------------------------
  // Admin
  // ---------------------------------------------------------------------------

  _MUser _admin() => _auth(<UserRole>[UserRole.admin]);

  @override
  Future<AdminStats> getAdminStats() async {
    await _delay();
    _admin();
    int count(BookStatus s) => _books.where((_MBook b) => b.status == s).length;
    return AdminStats(
      users: _users.length,
      lockedUsers: _users.where((_MUser u) => u.locked).length,
      categories: _categories.length,
      pending: count(BookStatus.pending),
      approved: count(BookStatus.approved),
      rejected: count(BookStatus.rejected),
      views: _books.fold<int>(0, (int sum, _MBook b) => sum + b.views),
    );
  }

  @override
  Future<List<Book>> getAdminBooks({BookStatus? status}) async {
    await _delay();
    _admin();
    return _sorted(_books.where((_MBook b) => status == null || b.status == status));
  }

  void _notify(String recipientId, String senderId, String title, String body) {
    _notices.add(_MNotice(_newId(), title, body, DateTime.now(), senderId, recipientId));
  }

  @override
  Future<Book> approveBook(String id) async {
    await _delay();
    final _MUser a = _admin();
    final _MBook b = _findBook(id);
    b
      ..status = BookStatus.approved
      ..rejectReason = null
      ..reviewedAt = DateTime.now();
    _notify(b.publisherId, a.id, 'Sách đã được duyệt', 'Sách “${b.title}” đã được duyệt và hiển thị cho người đọc.');
    return _toBook(b);
  }

  @override
  Future<Book> rejectBook(String id, String reason) async {
    await _delay();
    final _MUser a = _admin();
    if (reason.trim().isEmpty) {
      throw ApiException('Vui lòng nhập lý do từ chối.', statusCode: 400);
    }
    final _MBook b = _findBook(id);
    b
      ..status = BookStatus.rejected
      ..rejectReason = reason.trim()
      ..reviewedAt = DateTime.now();
    _notify(b.publisherId, a.id, 'Sách bị từ chối', 'Sách “${b.title}” bị từ chối. Lý do: ${reason.trim()}');
    return _toBook(b);
  }

  @override
  Future<void> adminDeleteBook(String id) async {
    await _delay();
    _admin();
    _findBook(id);
    _removeBook(id);
  }

  @override
  Future<List<AppUser>> getUsers() async {
    await _delay();
    _admin();
    return _users.map((_MUser u) => u.toUser()).toList();
  }

  @override
  Future<AppUser> setUserLocked(String id, bool locked) async {
    await _delay();
    _admin();
    for (final _MUser u in _users) {
      if (u.id == id) {
        if (u.role == UserRole.admin) {
          throw ApiException('Không thể khóa tài khoản quản trị viên.', statusCode: 400);
        }
        u.locked = locked;
        return u.toUser();
      }
    }
    throw ApiException('Người dùng không tồn tại.', statusCode: 404);
  }

  void _checkCategoryName(String name, [String exceptId = '']) {
    if (name.trim().isEmpty) {
      throw ApiException('Vui lòng nhập tên thể loại.', statusCode: 400);
    }
    if (_categories.any((BookCategory c) => c.id != exceptId && c.name == name.trim())) {
      throw ApiException('Tên thể loại đã tồn tại.', statusCode: 409);
    }
  }

  @override
  Future<BookCategory> addCategory(String name) async {
    await _delay();
    _admin();
    _checkCategoryName(name);
    final BookCategory c = BookCategory(id: _newId(), name: name.trim());
    _categories.add(c);
    return BookCategory(id: c.id, name: c.name);
  }

  @override
  Future<BookCategory> renameCategory(String id, String name) async {
    await _delay();
    _admin();
    _checkCategoryName(name, id);
    for (final BookCategory c in _categories) {
      if (c.id == id) {
        c.name = name.trim();
        return BookCategory(id: c.id, name: c.name);
      }
    }
    throw ApiException('Thể loại không tồn tại.', statusCode: 404);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _delay();
    _admin();
    if (_books.any((_MBook b) => b.categoryId == id)) {
      throw ApiException('Không thể xóa: thể loại này vẫn còn sách.', statusCode: 409);
    }
    _categories.removeWhere((BookCategory c) => c.id == id);
  }

  @override
  Future<void> sendNotification(String title, String body) async {
    await _delay();
    final _MUser a = _admin();
    if (title.trim().isEmpty || body.trim().isEmpty) {
      throw ApiException('Vui lòng nhập tiêu đề và nội dung thông báo.', statusCode: 400);
    }
    _notices.add(_MNotice(_newId(), title.trim(), body.trim(), DateTime.now(), a.id, null));
  }

  @override
  Future<AdminReport> getReport(ReportRange range) async {
    await _delay();
    _admin();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<String> labels = <String>[];
    final List<DateTime> starts = <DateTime>[];
    final List<DateTime> ends = <DateTime>[];
    const List<String> weekdays = <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    switch (range) {
      case ReportRange.days7:
        for (int i = 6; i >= 0; i--) {
          final DateTime s = today.subtract(Duration(days: i));
          starts.add(s);
          ends.add(s.add(const Duration(days: 1)));
          labels.add(weekdays[s.weekday - 1]);
        }
      case ReportRange.weeks4:
        for (int i = 3; i >= 0; i--) {
          final DateTime e = today.add(const Duration(days: 1)).subtract(Duration(days: i * 7));
          starts.add(e.subtract(const Duration(days: 7)));
          ends.add(e);
          labels.add('Tuần ${4 - i}');
        }
      case ReportRange.months6:
        for (int i = 5; i >= 0; i--) {
          final DateTime s = DateTime(today.year, today.month - i);
          starts.add(s);
          ends.add(DateTime(s.year, s.month + 1));
          labels.add('Th${s.month}');
        }
    }
    List<int> bucket(Iterable<DateTime> dates) => <int>[
          for (int i = 0; i < starts.length; i++)
            dates.where((DateTime d) => !d.isBefore(starts[i]) && d.isBefore(ends[i])).length,
        ];
    final List<_MBook> top = _books.where((_MBook b) => b.status == BookStatus.approved).toList()
      ..sort((_MBook a, _MBook b) => b.views.compareTo(a.views));
    return AdminReport(
      labels: labels,
      reads: bucket(_progress.values.map((ReadingRecord r) => r.updatedAt)),
      uploads: bucket(_books.map((_MBook b) => b.createdAt)),
      topBooks: top.take(5).map(_toBook).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // DỮ LIỆU MẪU
  // ---------------------------------------------------------------------------

  void _seed() {
    final DateTime now = DateTime.now();
    DateTime ago(int days) => now.subtract(Duration(days: days));

    void addUser(String id, String name, String email, UserRole role, int daysAgo, {bool locked = false}) {
      _users.add(_MUser(id, name, email, 'Demo@123', role, ago(daysAgo), locked: locked));
    }

    addUser('1', 'Hà Thành Đạt', 'reader@demo.com', UserRole.reader, 40);
    addUser('2', 'Nguyễn Huy Gia Bảo', 'publisher@demo.com', UserRole.publisher, 35);
    addUser('3', 'Nguyễn Đắc Anh Khôi', 'admin@demo.com', UserRole.admin, 60);
    addUser('4', 'Người đọc mẫu 01', 'reader01@demo.com', UserRole.reader, 21);
    addUser('5', 'Người đọc mẫu 02', 'reader02@demo.com', UserRole.reader, 12, locked: true);
    addUser('6', 'Nhà xuất bản mẫu', 'nxb@demo.com', UserRole.publisher, 18);

    _categories.addAll(<BookCategory>[
      BookCategory(id: '1', name: 'Văn học'),
      BookCategory(id: '2', name: 'Công nghệ'),
      BookCategory(id: '3', name: 'Kỹ năng'),
      BookCategory(id: '4', name: 'Lịch sử'),
      BookCategory(id: '5', name: 'Thiếu nhi'),
    ]);

    void addBook(String id, String title, String author, String cat, String pub, int pages, int daysAgo, int views,
        String desc,
        {BookStatus status = BookStatus.approved, String? reason}) {
      _books.add(_MBook(
        id: id,
        title: title,
        author: author,
        description: desc,
        categoryId: cat,
        publisherId: pub,
        totalPages: pages,
        createdAt: ago(daysAgo),
        status: status,
        rejectReason: reason,
        views: views,
      ));
    }

    addBook('1', 'Dế Mèn Phiêu Lưu Ký', 'Tô Hoài', '5', '2', 24, 30, 1280,
        'Hành trình phiêu lưu của chú Dế Mèn qua nhiều vùng đất, gặp gỡ nhiều bạn bè và rút ra bài học về lòng nhân ái, sự khiêm tốn.');
    addBook('2', 'Số Đỏ', 'Vũ Trọng Phụng', '1', '2', 32, 28, 964,
        'Tiểu thuyết trào phúng nổi tiếng của văn học Việt Nam, khắc họa xã hội thành thị đầu thế kỷ XX.');
    addBook('3', 'Tắt Đèn', 'Ngô Tất Tố', '1', '6', 20, 26, 742,
        'Tác phẩm hiện thực viết về cuộc sống cùng cực của người nông dân trước Cách mạng.');
    addBook('4', 'Truyện Kiều', 'Nguyễn Du', '1', '6', 40, 25, 1530,
        'Kiệt tác truyện thơ Nôm gồm 3.254 câu lục bát, kể về cuộc đời nàng Thúy Kiều.');
    addBook('5', 'Lập trình Flutter cơ bản', 'Nhóm 10', '2', '2', 36, 20, 2110,
        'Tài liệu nhập môn Flutter và Dart: widget, layout, điều hướng, quản lý trạng thái và kết nối REST API.');
    addBook('6', 'Nhập môn Cơ sở dữ liệu', 'Khoa CNTT', '2', '6', 28, 18, 835,
        'Các khái niệm nền tảng về mô hình quan hệ, chuẩn hóa dữ liệu và ngôn ngữ truy vấn SQL.');
    addBook('7', 'Cấu trúc dữ liệu và giải thuật', 'Khoa CNTT', '2', '6', 44, 15, 1176,
        'Danh sách, ngăn xếp, hàng đợi, cây, đồ thị và các giải thuật sắp xếp, tìm kiếm thường dùng.');
    addBook('8', 'Kỹ năng học tập hiệu quả', 'Nhóm 10', '3', '2', 16, 12, 498,
        'Phương pháp ghi chú, quản lý thời gian và ôn tập dành cho sinh viên.');
    addBook('9', 'Lịch sử Việt Nam giản lược', 'Nhóm 10', '4', '2', 30, 10, 611,
        'Tóm lược các giai đoạn chính của lịch sử Việt Nam từ thời dựng nước đến hiện đại.');
    addBook('10', 'Chí Phèo', 'Nam Cao', '1', '6', 12, 8, 889,
        'Truyện ngắn kinh điển về bi kịch bị cự tuyệt quyền làm người của một người nông dân.');
    addBook('11', 'Thiết kế giao diện di động', 'Nhóm 10', '2', '2', 22, 3, 0,
        'Nguyên tắc Material Design 3, bố cục, màu sắc và kiểu chữ cho ứng dụng di động.',
        status: BookStatus.pending);
    addBook('12', 'Kỹ năng thuyết trình', 'Nhà xuất bản mẫu', '3', '6', 18, 2, 0,
        'Cách chuẩn bị nội dung, thiết kế slide và trình bày trước đám đông.',
        status: BookStatus.pending);
    addBook('13', 'Tuyển tập bài tập SQL', 'Nhóm 10', '2', '2', 14, 6, 0, 'Tuyển tập bài tập truy vấn SQL có lời giải.',
        status: BookStatus.rejected, reason: 'File PDF bị lỗi ở trang 5–8, vui lòng tải lại file đầy đủ.');

    _favorites['1'] = <String>{'1', '5'};
    _progress['1:5'] = ReadingRecord(bookId: '5', page: 14, updatedAt: ago(0));
    _progress['1:4'] = ReadingRecord(bookId: '4', page: 6, updatedAt: ago(2));
    _notices.add(_MNotice('1', 'Chào mừng đến với BookHub',
        'Thư viện sách điện tử của Nhóm 10. Chúc bạn có những giờ đọc sách thú vị!', ago(1), '3', null));
  }
}

class _MUser {
  _MUser(this.id, this.name, this.email, this.password, this.role, this.createdAt, {this.locked = false});

  final String id;
  final String name;
  final String email;
  String password;
  final UserRole role;
  final DateTime createdAt;
  bool locked;

  /// Giống cột Users.FailedLoginCount / Users.LockoutUntil.
  int failedLogins = 0;
  DateTime? lockoutUntil;

  /// Giống cột Users.LastReadNotificationId.
  int lastReadNotice = 0;

  AppUser toUser() => AppUser(id: id, name: name, email: email, role: role, joinedAt: createdAt, locked: locked);
}

class _MBook {
  _MBook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.categoryId,
    required this.publisherId,
    required this.totalPages,
    required this.createdAt,
    this.status = BookStatus.pending,
    this.rejectReason,
    this.views = 0,
  });

  final String id;
  String title;
  String author;
  String description;
  String categoryId;
  final String publisherId;
  int totalPages;
  final DateTime createdAt;
  BookStatus status;
  String? rejectReason;
  DateTime? reviewedAt;
  int views;
}

class _MNotice {
  _MNotice(this.id, this.title, this.body, this.sentAt, this.sentBy, this.recipientId);

  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  final String sentBy;
  final String? recipientId;
}

/// Tạo một file PDF đơn giản (chữ không dấu) có [pages] trang, dùng ở chế độ giả lập.
Uint8List buildSamplePdf(String title, int pages) {
  final String safeTitle = _ascii(title);
  final List<String> objects = <String>[];
  final int pageCount = pages < 1 ? 1 : pages;
  // 1: catalog, 2: pages, 3: font, sau đó mỗi trang gồm 1 page + 1 content.
  objects.add('<< /Type /Catalog /Pages 2 0 R >>');
  final List<String> kids = <String>[for (int i = 0; i < pageCount; i++) '${4 + i * 2} 0 R'];
  objects.add('<< /Type /Pages /Kids [${kids.join(' ')}] /Count $pageCount >>');
  objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  for (int i = 0; i < pageCount; i++) {
    final String text = 'BT /F1 18 Tf 50 520 Td ($safeTitle) Tj 0 -40 Td /F1 14 Tf (Trang ${i + 1} / $pageCount) Tj '
        '0 -30 Td /F1 11 Tf (Ban PDF mau - che do gia lap USE_MOCK) Tj ET';
    objects.add('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 420 595] '
        '/Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + i * 2} 0 R >>');
    objects.add('<< /Length ${text.length} >>\nstream\n$text\nendstream');
  }
  final StringBuffer sb = StringBuffer('%PDF-1.4\n');
  final List<int> offsets = <int>[];
  for (int i = 0; i < objects.length; i++) {
    offsets.add(sb.length);
    sb.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final int xref = sb.length;
  sb.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final int o in offsets) {
    sb.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  sb.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(latin1.encode(sb.toString()));
}

String _ascii(String s) {
  const String from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  final String to = '${'a' * 17}${'e' * 11}${'i' * 5}${'o' * 17}${'u' * 11}${'y' * 5}d';
  final StringBuffer out = StringBuffer();
  for (final int rune in s.runes) {
    final String ch = String.fromCharCode(rune);
    final String lower = ch.toLowerCase();
    final int idx = from.indexOf(lower);
    String mapped = idx >= 0 ? to[idx] : ch;
    if (idx >= 0 && ch != lower) {
      mapped = mapped.toUpperCase();
    }
    if (mapped == 'Đ' || ch == 'Đ') {
      mapped = 'D';
    }
    if (mapped.codeUnitAt(0) > 126 || mapped == '(' || mapped == ')' || mapped == r'\') {
      mapped = ' ';
    }
    out.write(mapped);
  }
  return out.toString();
}
