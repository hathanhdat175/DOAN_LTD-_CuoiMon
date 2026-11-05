/// Định dạng ngày dd/MM/yyyy.
String formatDate(DateTime d) {
  final String dd = d.day.toString().padLeft(2, '0');
  final String mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}
