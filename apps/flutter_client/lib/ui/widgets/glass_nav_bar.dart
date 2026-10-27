import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// 底部液态玻璃导航栏：通透模糊、边缘折射高光、选中态自然过渡。
/// 使用 `liquid_glass_renderer`，设备不支持 Flutter GPU 时自动降级为 FakeGlass。
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<GlassNavItem> items;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: LiquidGlassLayer(
        settings: LiquidGlassSettings.ios27Regular(
          brightness: brightness,
          tintAmount: context.isDark ? 0.55 : 0.35,
        ),
        defaultAppearance: LiquidGlassAppearance.ios27Regular(
          brightness: brightness,
          tint: palette.glassTint,
        ),
        child: LiquidGlass(
          shape: const LiquidRoundedSuperellipse(
            borderRadius: AppSizes.navBarHeight / 2,
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.12),
              offset: const Offset(0, 10),
              blurRadius: 28,
              spreadRadius: -6,
            ),
          ],
          child: SizedBox(
            height: AppSizes.navBarHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: AppMotion.emphasized,
                      curve: AppMotion.spring,
                      left: itemWidth * currentIndex + 4,
                      top: 7,
                      width: itemWidth - 8,
                      height: AppSizes.navBarHeight - 14,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: context.colors.primaryContainer.withValues(
                            alpha: context.isDark ? 0.92 : 0.95,
                          ),
                          shape: AppShapes.superellipse(
                            (AppSizes.navBarHeight - 14) / 2,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < items.length; index++)
                          Expanded(
                            child: _NavButton(
                              item: items[index],
                              selected: index == currentIndex,
                              onTap: () => onSelected(index),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colors.onPrimaryContainer
        : context.colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.navBarHeight / 2),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1 : 0.94,
              duration: AppMotion.standard,
              curve: AppMotion.spring,
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.standard,
              curve: AppMotion.standardCurve,
              style:
                  context.texts.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 10.5,
                    letterSpacing: 0.1,
                  ) ??
                  const TextStyle(fontSize: 10.5, color: Colors.black),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

/// 内容底部的柔和渐隐，避免滚动文字直接贴到玻璃边缘。
class NavBarScrim extends StatelessWidget {
  const NavBarScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: AppSpacing.navBarClearance,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.colors.surface.withValues(alpha: 0),
              context.colors.surface.withValues(alpha: 0.85),
            ],
          ),
        ),
      ),
    );
  }
}
