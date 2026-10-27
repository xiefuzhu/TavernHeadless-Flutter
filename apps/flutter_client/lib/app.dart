import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'ui/router.dart';
import 'viewmodels/chat_view_model.dart';
import 'viewmodels/connection_view_model.dart';
import 'viewmodels/session_list_view_model.dart';
import 'viewmodels/settings_controller.dart';

/// 应用根：注入控制器、动态取色与路由。
class TavernApp extends StatefulWidget {
  const TavernApp({
    super.key,
    required this.settings,
    required this.connection,
    required this.sessions,
    required this.chat,
  });

  final SettingsController settings;
  final ConnectionViewModel connection;
  final SessionListViewModel sessions;
  final ChatViewModel chat;

  @override
  State<TavernApp> createState() => _TavernAppState();
}

class _TavernAppState extends State<TavernApp> {
  late final GoRouter _router = createRouter(
    connection: widget.connection,
    sessionList: widget.sessions,
    chat: widget.chat,
  );

  @override
  void initState() {
    super.initState();
    // 首帧之后再静默恢复连接，避免启动阶段弹加载态。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.connection.bootstrap();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: widget.settings),
        ChangeNotifierProvider<ConnectionViewModel>.value(
          value: widget.connection,
        ),
        ChangeNotifierProvider<SessionListViewModel>.value(
          value: widget.sessions,
        ),
        ChangeNotifierProvider<ChatViewModel>.value(value: widget.chat),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final useDynamic = settings.dynamicColor;
              final ColorScheme? dynamicLight = useDynamic ? lightDynamic : null;
              final ColorScheme? dynamicDark = useDynamic ? darkDynamic : null;
              final lightScheme =
                  dynamicLight ??
                  ColorScheme.fromSeed(seedColor: AppTheme.seed);
              final darkScheme =
                  dynamicDark ??
                  ColorScheme.fromSeed(
                    seedColor: AppTheme.seed,
                    brightness: Brightness.dark,
                  );
              return MaterialApp.router(
                title: '天琴',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(
                  scheme: lightScheme,
                  brightness: Brightness.light,
                ),
                darkTheme: AppTheme.build(
                  scheme: darkScheme,
                  brightness: Brightness.dark,
                ),
                themeMode: settings.themeMode,
                themeAnimationDuration: AppMotion.standard,
                themeAnimationCurve: AppMotion.standardCurve,
                routerConfig: _router,
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      textScaler: media.textScaler.clamp(
                        minScaleFactor: 0.9,
                        maxScaleFactor: 1.3,
                      ),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
