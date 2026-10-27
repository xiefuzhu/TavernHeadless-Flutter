import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/glass_nav_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    GlassNavItem(
      label: '故事',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
    ),
    GlassNavItem(
      label: '角色',
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
    ),
    GlassNavItem(
      label: '我的',
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavBarScrim(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: GlassNavigationBar(
                currentIndex: navigationShell.currentIndex,
                items: _items,
                onSelected: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
