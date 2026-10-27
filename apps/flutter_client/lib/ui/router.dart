import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import '../data/models/session_models.dart';
import '../viewmodels/chat_view_model.dart';
import '../viewmodels/connection_view_model.dart';
import '../viewmodels/session_list_view_model.dart';
import 'pages/characters_page.dart';
import 'pages/chat_page.dart';
import 'pages/connect_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'shell.dart';

GoRouter createRouter({
  required ConnectionViewModel connection,
  required SessionListViewModel sessionList,
  required ChatViewModel chat,
}) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: connection,
    redirect: (context, state) {
      final connected = connection.isConnected;
      final atConnect = state.uri.path == '/connect';
      if (!connected && !atConnect) {
        return '/connect';
      }
      if (connected && atConnect) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/connect',
        pageBuilder: (context, state) => _fadePage(
          state,
          const ConnectPage(),
          vertical: true,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/characters',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const CharactersPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SettingsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/session/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final extra = state.extra;
          final session = extra is SessionSummary
              ? extra
              : _findSession(sessionList, id);
          return _fadePage(
            state,
            ChatPage(sessionId: id, initialSession: session),
            slide: true,
          );
        },
      ),
    ],
  );
}

SessionSummary? _findSession(SessionListViewModel list, String id) {
  for (final session in list.sessions) {
    if (session.id == id) {
      return session;
    }
  }
  return null;
}

CustomTransitionPage<void> _fadePage(
  GoRouterState state,
  Widget child, {
  bool vertical = false,
  bool slide = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.standard,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.decelerate,
        reverseCurve: AppMotion.accelerate,
      );
      final begin = vertical
          ? const Offset(0, 0.04)
          : slide
          ? const Offset(0.055, 0)
          : Offset.zero;
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
            curved,
          ),
          child: child,
        ),
      );
    },
  );
}
