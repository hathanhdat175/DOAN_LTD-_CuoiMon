import 'json.dart';

/// Thông báo do Admin gửi (bảng Notifications).
///
/// [personal] = true: thông báo riêng cho người dùng (ví dụ kết quả duyệt sách);
/// false: thông báo hệ thống gửi đến toàn bộ người dùng.
/// [isRead] = false: thông báo mới, chưa mở màn hình Thông báo để xem.
class AppNotice {
  AppNotice({
    required this.title,
    required this.body,
    required this.sentAt,
    this.id = '',
    this.personal = false,
    this.isRead = false,
  });

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    return AppNotice(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sentAt: parseDate(json['sentAt']),
      personal: json['personal'] == true,
      isRead: json['isRead'] == true,
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool personal;
  bool isRead;
}
