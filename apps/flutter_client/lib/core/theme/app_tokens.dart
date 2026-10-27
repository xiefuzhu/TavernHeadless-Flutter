import 'package:flutter/material.dart';

/// 统一的间距刻度，避免页面各自写魔法数字。
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// 页面左右安全边距。
  static const double page = 20;

  /// 底部液态玻璃导航栏为内容预留的高度。
  static const double navBarClearance = 108;
}

/// 圆角刻度。所有大容器使用连续曲率，接近 FlClash / Material You 的观感。
abstract final class AppRadius {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double pill = 999;
}

abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 340);
  static const Duration page = Duration(milliseconds: 380);
  static const Duration breathe = Duration(milliseconds: 2200);

  static const Curve standardCurve = Cubic(0.2, 0, 0, 1);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve accelerate = Cubic(0.3, 0, 0.8, 0.15);
  static const Curve spring = Cubic(0.34, 1.4, 0.64, 1);

  static const Duration staggerStep = Duration(milliseconds: 36);
  static const int staggerMaxItems = 8;
}

abstract final class AppSizes {
  static const double minTouchTarget = 48;
  static const double navBarHeight = 64;
  static const double avatar = 44;
  static const double composerMaxHeight = 168;
}

/// 连续曲率圆角；比普通 RoundedRectangle 更接近 Material You 的大圆角卡片。
abstract final class AppShapes {
  static RoundedSuperellipseBorder superellipse(double radius) {
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
    );
  }

  static RoundedSuperellipseBorder get card => superellipse(AppRadius.lg);

  static RoundedSuperellipseBorder get sheet => superellipse(AppRadius.xl);

  static RoundedSuperellipseBorder get control => superellipse(AppRadius.sm);
}
