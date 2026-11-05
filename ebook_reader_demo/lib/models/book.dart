import 'enums.dart';
import 'json.dart';

/// Sách điện tử (bảng Books).
class Book {
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.categoryId,
    required this.publisherId,
    required this.totalPages,
    required this.createdAt,
    this.categoryName = '',
    this.publisherName = '',
    this.coverUrl,
    this.status = BookStatus.pending,
    this.rejectReason,
    this.reviewedAt,
    this.views = 0,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categoryId: json['categoryId'].toString(),
      categoryName: json['categoryName'] as String? ?? '',
      publisherId: json['publisherId'].toString(),
      publisherName: json['publisherName'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      totalPages: parseInt(json['totalPages'], 1),
      status: bookStatusFromCode(json['status'] as String? ?? 'Pending'),
      rejectReason: json['rejectReason'] as String?,
      reviewedAt: json['reviewedAt'] == null ? null : parseDate(json['reviewedAt']),
      views: parseInt(json['views']),
      createdAt: parseDate(json['createdAt']),
    );
  }

  /// Dùng để lưu thông tin sách đã tải về máy (đọc offline).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'publisherId': publisherId,
      'publisherName': publisherName,
      'coverUrl': coverUrl,
      'totalPages': totalPages,
      'status': status.code,
      'rejectReason': rejectReason,
      'reviewedAt': reviewedAt?.toUtc().toIso8601String(),
      'views': views,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  final String id;
  final String title;
  final String author;
  final String description;
  final String categoryId;
  final String categoryName;
  final String publisherId;
  final String publisherName;

  /// Đường dẫn ảnh bìa trên máy chủ (ví dụ `/uploads/cover/abc.jpg`);
  /// null thì ứng dụng tự vẽ bìa.
  final String? coverUrl;

  final int totalPages;
  final DateTime createdAt;
  final BookStatus status;
  final String? rejectReason;
  final DateTime? reviewedAt;
  int views;

  /// Số dùng để chọn màu bìa khi sách chưa có ảnh bìa (bìa được vẽ bằng code).
  int get coverSeed => int.tryParse(id) ?? id.hashCode.abs();

  /// Sách đã được Admin duyệt (Reader mới nhìn thấy).
  bool get isApproved => status == BookStatus.approved;
}
