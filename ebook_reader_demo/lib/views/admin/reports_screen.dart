import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../services/api/bookhub_api.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/common.dart';

/// Báo cáo thống kê theo thời gian, số liệu lấy từ API `GET /api/admin/reports`:
/// - Lượt đọc: số lần người dùng cập nhật tiến độ đọc (bảng ReadingProgress).
/// - Sách mới: số sách được đăng (bảng Books).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportRange _range = ReportRange.days7;
  late Future<AdminReport> _report;

  @override
  void initState() {
    super.initState();
    _report = context.read<AdminViewModel>().report(_range);
  }

  void _load(ReportRange range) {
    setState(() {
      _range = range;
      _report = context.read<AdminViewModel>().report(range);
    });
  }

  int _sum(List<int> values) => values.fold<int>(0, (int total, int v) => total + v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar('Báo cáo thống kê'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: <Widget>[
          SegmentedButton<ReportRange>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<ReportRange>>[
              ButtonSegment<ReportRange>(value: ReportRange.days7, label: Text('7 ngày')),
              ButtonSegment<ReportRange>(value: ReportRange.weeks4, label: Text('4 tuần')),
              ButtonSegment<ReportRange>(value: ReportRange.months6, label: Text('6 tháng')),
            ],
            selected: <ReportRange>{_range},
            onSelectionChanged: (Set<ReportRange> selection) => _load(selection.first),
          ),
          const SizedBox(height: 16),
          FutureBuilder<AdminReport>(
            future: _report,
            builder: (BuildContext context, AsyncSnapshot<AdminReport> snap) {
              if (snap.hasError) {
                final Object? e = snap.error;
                return ErrorState(
                  message: e is ApiException ? e.message : 'Không tải được báo cáo',
                  onRetry: () => _load(_range),
                );
              }
              final AdminReport? report = snap.data;
              if (report == null) {
                return const Padding(padding: EdgeInsets.all(40), child: LoadingState());
              }
              return _ReportBody(report: report, sum: _sum);
            },
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.sum});

  final AdminReport report;
  final int Function(List<int>) sum;

  @override
  Widget build(BuildContext context) {
    final List<Book> top = report.topBooks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Lượt đọc sách', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              Text(
                '${sum(report.reads)}',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              MiniBarChart(values: report.reads, labels: report.labels),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Sách mới được đăng', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              Text(
                '${sum(report.uploads)}',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              MiniBarChart(values: report.uploads, labels: report.labels, color: AppColors.success, height: 100),
            ],
          ),
        ),
        if (report.usersByRole.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: <Widget>[
                for (final UserRole role in UserRole.values)
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Text(
                          '${report.usersByRole[role.code] ?? 0}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        Text(role.label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionTitle('Top sách theo lượt xem'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: <Widget>[
              if (top.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có sách nào được duyệt.', style: TextStyle(color: AppColors.muted)),
                ),
              for (int i = 0; i < top.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: i == 0 ? AppColors.accent : AppColors.primarySoft,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: i == 0 ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    top[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(top[i].author, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    '${top[i].views}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Lượt đọc = số lần người dùng mở / lật trang sách được ghi vào bảng ReadingProgress.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ],
    );
  }
}
