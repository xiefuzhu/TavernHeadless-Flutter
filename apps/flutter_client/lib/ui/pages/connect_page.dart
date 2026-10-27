import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/generation_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../viewmodels/connection_view_model.dart';
import '../feedback.dart';
import '../widgets/app_surface.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  late final TextEditingController _endpoint;
  late final TextEditingController _apiKey;
  late final TextEditingController _player;
  final FocusNode _endpointFocus = FocusNode();
  bool _obscureKey = true;
  bool _remember = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final connection = context.read<ConnectionViewModel>();
    _endpoint = TextEditingController(text: connection.endpoint);
    _apiKey = TextEditingController();
    _player = TextEditingController(text: connection.playerName);
    _remember = connection.remember;
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _apiKey.dispose();
    _player.dispose();
    _endpointFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final connection = context.read<ConnectionViewModel>();
    final ok = await connection.connect(
      endpoint: _endpoint.text,
      apiKey: _apiKey.text,
      playerName: _player.text,
      remember: _remember,
    );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (!ok && connection.error != null) {
      showAppSnack(context, connection.error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionViewModel>();
    final error = connection.error;
    final busy = _submitting || connection.isConnecting;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AuroraBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Entrance(index: 0, child: _BrandHeader()),
                      const SizedBox(height: AppSpacing.xxl),
                      Entrance(
                        index: 1,
                        child: SurfaceCard(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.md,
                          ),
                          color: context.colors.surfaceContainerLow.withValues(
                            alpha: 0.92,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('连接你的酒馆', style: context.texts.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                '填入实例地址与访问密钥。模型密钥始终保存在服务器。',
                                style: context.texts.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              TextField(
                                controller: _endpoint,
                                focusNode: _endpointFocus,
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: '实例地址',
                                  hintText: 'http://192.168.1.10:3000',
                                  prefixIcon: Icon(Icons.link_rounded),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: _apiKey,
                                obscureText: _obscureKey,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: '访问密钥',
                                  hintText: '本地 API Key',
                                  prefixIcon: const Icon(Icons.key_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureKey ? '显示密钥' : '隐藏密钥',
                                    onPressed: () => setState(
                                      () => _obscureKey = !_obscureKey,
                                    ),
                                    icon: Icon(
                                      _obscureKey
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: _player,
                                textInputAction: TextInputAction.done,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                  labelText: '你的名字',
                                  hintText: '旅人',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                  counterText: '',
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              SwitchListTile.adaptive(
                                value: _remember,
                                onChanged: (value) =>
                                    setState(() => _remember = value),
                                contentPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                title: Text(
                                  '记住连接',
                                  style: context.texts.titleSmall,
                                ),
                                subtitle: Text(
                                  _remember
                                      ? '密钥写入本机安全存储，下次自动连接'
                                      : '仅保留在本次运行内存中',
                                  style: context.texts.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                                secondary: Icon(
                                  _remember
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FilledButton(
                                onPressed: busy ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration: AppMotion.fast,
                                  child: busy
                                      ? const SizedBox(
                                          key: ValueKey('loading'),
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : const Row(
                                          key: ValueKey('idle'),
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text('保存并连接'),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppBanner(
                          message: error,
                          color: context.palette.danger,
                          icon: Icons.error_outline_rounded,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      const Entrance(index: 2, child: _BudgetRow()),
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        index: 3,
                        child: Text(
                          '真机调试时 127.0.0.1 指向手机自身，请填写电脑的局域网地址，并确保后端允许局域网访问。',
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: ShapeDecoration(
            shape: AppShapes.superellipse(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.primary,
                context.colors.tertiary,
              ],
            ),
            shadows: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.nights_stay_rounded,
            size: 34,
            color: context.colors.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '天琴',
          style: context.texts.displayMedium?.copyWith(letterSpacing: 2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          'LYRA · PRIVATE TAVERN',
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            letterSpacing: 2.4,
            fontSize: 9.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          '把故事带在身边',
          style: context.texts.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BudgetChip(
            icon: Icons.memory_rounded,
            label: '上下文',
            value: GenerationDefaults.contextLabel,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _BudgetChip(
            icon: Icons.output_rounded,
            label: '单次输出',
            value: GenerationDefaults.outputLabel,
          ),
        ),
      ],
    );
  }
}

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: ShapeDecoration(
        color: context.colors.surfaceContainerLow.withValues(alpha: 0.72),
        shape: AppShapes.control,
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: context.colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: context.texts.labelLarge?.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 柔和极光背景：缓慢漂移的低饱和色块，给玻璃与卡片提供层次。
class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = Curves.easeInOut.transform(_controller.value);
          return Stack(
            children: [
              Positioned(
                left: -120 + value * 30,
                top: -60 + value * 40,
                child: _Blob(
                  color: colors.primary.withValues(
                    alpha: context.isDark ? 0.4 : 0.3,
                  ),
                  size: 340,
                ),
              ),
              Positioned(
                right: -130 - value * 20,
                top: 120 + value * 60,
                child: _Blob(
                  color: colors.tertiary.withValues(
                    alpha: context.isDark ? 0.32 : 0.26,
                  ),
                  size: 320,
                ),
              ),
              Positioned(
                left: 40 - value * 20,
                bottom: -120 + value * 30,
                child: _Blob(
                  color: colors.secondary.withValues(
                    alpha: context.isDark ? 0.24 : 0.2,
                  ),
                  size: 300,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
