import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Giới hạn bề rộng giao diện ở cỡ điện thoại khi chạy trên màn hình lớn
/// (Chrome, Windows...). Trên điện thoại thật, widget này không làm gì cả.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const double maxPhoneWidth = 430;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 600) {
          return child;
        }
        final MediaQueryData mq = MediaQuery.of(context);
        return ColoredBox(
          color: AppColors.ink,
          child: Center(
            child: SizedBox(
              width: maxPhoneWidth,
              height: constraints.maxHeight,
              child: MediaQuery(
                data: mq.copyWith(size: Size(maxPhoneWidth, mq.size.height)),
                child: ClipRect(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
