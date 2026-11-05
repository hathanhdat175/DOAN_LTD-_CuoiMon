/// Hàm tiện ích đọc dữ liệu JSON trả về từ REST API.

/// Đọc ngày giờ dạng ISO 8601 (máy chủ trả về giờ UTC) và đổi sang giờ máy.
DateTime parseDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

/// Đọc số nguyên (chấp nhận cả kiểu chuỗi).
int parseInt(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

/// Đọc danh sách số nguyên.
List<int> parseIntList(Object? value) {
  if (value is List) {
    return value.map((Object? e) => parseInt(e)).toList();
  }
  return <int>[];
}
