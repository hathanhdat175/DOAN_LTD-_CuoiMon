import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/common.dart';

/// Quản lý thể loại: thêm, sửa, xóa.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final String? name = await promptDialog(
      context,
      title: 'Thêm thể loại',
      label: 'Tên thể loại',
      okLabel: 'Thêm',
    );
    if (name == null || !context.mounted) {
      return;
    }
    await runAction(
      context,
      () => context.read<AdminViewModel>().addCategory(name),
      success: 'Đã thêm thể loại “${name.trim()}”',
    );
  }

  Future<void> _rename(BuildContext context, BookCategory category) async {
    final String? name = await promptDialog(
      context,
      title: 'Sửa thể loại',
      label: 'Tên thể loại',
      initialValue: category.name,
    );
    if (name == null || !context.mounted) {
      return;
    }
    await runAction(
      context,
      () => context.read<AdminViewModel>().renameCategory(category.id, name),
      success: 'Đã cập nhật thể loại',
    );
  }

  Future<void> _delete(BuildContext context, BookCategory category) async {
    final bool ok = await confirmDialog(
      context,
      title: 'Xóa thể loại',
      message: 'Xóa thể loại “${category.name}”?',
      okLabel: 'Xóa',
      danger: true,
    );
    if (!ok || !context.mounted) {
      return;
    }
    // Máy chủ trả lỗi "Không thể xóa: thể loại này vẫn còn sách" nếu còn sách.
    await runAction(
      context,
      () => context.read<AdminViewModel>().deleteCategory(category.id),
      success: 'Đã xóa thể loại',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminViewModel>(
      builder: (BuildContext context, AdminViewModel vm, Widget? _) {
        final List<BookCategory> categories = vm.categories;

        return Scaffold(
          appBar: buildAppBar('Thể loại'),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm thể loại'),
          ),
          body: categories.isEmpty
              ? const EmptyState(icon: Icons.category_outlined, title: 'Chưa có thể loại nào')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: categories.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final BookCategory category = categories[index];
                    final int count = vm.booksInCategory(category.id);

                    return AppCard(
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  category.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                                Text('$count cuốn sách', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sửa',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _rename(context, category),
                          ),
                          IconButton(
                            tooltip: 'Xóa',
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            onPressed: () => _delete(context, category),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
