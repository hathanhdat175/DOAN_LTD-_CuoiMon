import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/common.dart';

/// Quản lý người dùng: tìm kiếm, khóa hoặc mở khóa tài khoản.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _query = '';

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.reader:
        return AppColors.primary;
      case UserRole.publisher:
        return AppColors.warning;
      case UserRole.admin:
        return AppColors.danger;
    }
  }

  Future<void> _toggleLock(AppUser user) async {
    if (!user.locked) {
      final bool ok = await confirmDialog(
        context,
        title: 'Khóa tài khoản',
        message: 'Khóa tài khoản của ${user.name}? Người dùng này sẽ không thể đăng nhập.',
        okLabel: 'Khóa',
        danger: true,
      );
      if (!ok || !mounted) {
        return;
      }
    }
    final bool lock = !user.locked;
    await runAction(
      context,
      () => context.read<AdminViewModel>().setLocked(user.id, lock),
      success: lock ? 'Đã khóa ${user.name}' : 'Đã mở khóa ${user.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminViewModel>(
      builder: (BuildContext context, AdminViewModel vm, Widget? _) {
        final String q = _query.trim().toLowerCase();
        final List<AppUser> users = <AppUser>[
          for (final AppUser u in vm.users)
            if (q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)) u,
        ];

        return Scaffold(
          appBar: buildAppBar('Người dùng'),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextField(
                  onChanged: (String value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: fieldDecoration('Tìm theo tên hoặc email', icon: Icons.search),
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const EmptyState(icon: Icons.people_outline, title: 'Không tìm thấy người dùng')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: users.length,
                        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final AppUser user = users[index];
                          final bool isAdmin = user.role == UserRole.admin;

                          return AppCard(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: user.locked ? AppColors.line : AppColors.primarySoft,
                                  child: Icon(
                                    user.locked ? Icons.lock_outline : Icons.person_outline,
                                    color: user.locked ? AppColors.muted : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        user.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                                      ),
                                      Text(
                                        user.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: <Widget>[
                                          Pill(text: user.role.code, color: _roleColor(user.role)),
                                          if (user.locked)
                                            const Pill(text: 'Đã khóa', color: AppColors.muted, icon: Icons.lock_outline),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Công tắc: bật = đang hoạt động, tắt = bị khóa
                                Switch(
                                  value: !user.locked,
                                  onChanged: isAdmin ? null : (bool _) => _toggleLock(user),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
