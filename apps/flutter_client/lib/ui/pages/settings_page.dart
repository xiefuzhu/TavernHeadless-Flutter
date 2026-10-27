import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/connection_identity.dart';
import '../../core/config/generation_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/format.dart';
import '../../viewmodels/connection_view_model.dart';
import '../../viewmodels/settings_controller.dart';
import '../feedback.dart';
import '../widgets/app_surface.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _refresh(BuildContext context) async {
    final connection = context.read<ConnectionViewModel>();
    await connection.refreshCatalog();
    if (!context.mounted) {
      return;
    }
    final error = connection.error;
    showAppSnack(
      context,
      error ?? '已读取最新的角色与资产列表',
      isError: error != null,
    );
  }

  Future<void> _reconnect(BuildContext context) async {
    final connection = context.read<ConnectionViewModel>();
    final settings = context.read<SettingsController>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReconnectSheet(
        endpoint: connection.endpoint,
        playerName: connection.playerName,
        remember: settings.value.rememberConnection,
      ),
    );
    if (ok == true && context.mounted) {
      showAppSnack(context, '已重新连接');
    }
  }

  Future<void> _clearDrafts(BuildContext context) async {
    final connection = context.read<ConnectionViewModel>();
    final confirmed = await confirmAction(
      context,
      title: '清理本机草稿？',
      message: '只会删除这台手机上尚未发送的输入文本，不会影响服务器上的会话历史。',
      confirmLabel: '清理',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final removed = await connection.clearDrafts();
    if (!context.mounted) {
      return;
    }
    showAppSnack(
      context,
      removed == 0 ? '没有需要清理的草稿' : '已清理 $removed 份草稿',
    );
  }

  Future<void> _forgetCredential(BuildContext context) async {
    final connection = context.read<ConnectionViewModel>();
    final confirmed = await confirmAction(
      context,
      title: '移除已保存的访问密钥？',
      message: '移除后，下次启动需要重新输入密钥。当前这次连接不会被断开。',
      confirmLabel: '移除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await connection.forgetCredential();
    if (!context.mounted) {
      return;
    }
    showAppSnack(context, connection.notice ?? '已移除本机保存的访问密钥');
  }

  Future<void> _disconnect(BuildContext context) async {
    final choice = await showDialog<_DisconnectChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('断开连接？'),
        content: const Text(
          '断开后需要重新输入访问密钥才能继续。本机草稿不会被删除，可以在“数据与隐私”里单独清理。',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DisconnectChoice.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DisconnectChoice.keepKey),
            child: const Text('仅断开'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.error,
              foregroundColor: dialogContext.colors.onError,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DisconnectChoice.removeKey),
            child: const Text('断开并移除密钥'),
          ),
        ],
      ),
    );
    if (choice == null || choice == _DisconnectChoice.cancel) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await context.read<ConnectionViewModel>().disconnect(
      clearCredential: choice == _DisconnectChoice.removeKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionViewModel>();
    final settings = context.watch<SettingsController>();
    final assets = connection.assets;
    final connected = connection.isConnected;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(context),
          edgeOffset: 8,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.navBarClearance,
            ),
            children: [
              Text(
                '我的',
                style: context.texts.displayMedium?.copyWith(fontSize: 29),
              ),
              const SizedBox(height: 4),
              Text(
                '连接、外观与本机数据都只影响这一台设备。',
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Section(
                title: '连接',
                subtitle: connection.playerName,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusPill(
                          label: connected ? '已连接' : '未连接',
                          color: connected
                              ? context.palette.success
                              : context.palette.warning,
                          pulse: connected,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            endpointLabel(connection.endpoint),
                            style: context.texts.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _reconnect(context),
                          child: const Text('重新连接'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connection.endpoint,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            label: '角色',
                            value: '${connection.characters.length}',
                          ),
                        ),
                        Expanded(
                          child: _Stat(
                            label: '预设',
                            value: '${assets.presets.length}',
                          ),
                        ),
                        Expanded(
                          child: _Stat(
                            label: '世界书',
                            value: '${assets.worldbooks.length}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _refresh(context),
                            icon: const Icon(Icons.sync_rounded, size: 18),
                            label: const Text('检查连接'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _disconnect(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.palette.danger,
                            ),
                            icon: const Icon(Icons.link_off_rounded, size: 18),
                            label: const Text('断开'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Section(
                title: '外观',
                subtitle: 'Material 3 · Manrope 字体 · 连续曲率圆角',
                child: Column(
                  children: [
                    _ThemeSelector(
                      mode: settings.themeMode,
                      onChanged: settings.setThemeMode,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SwitchRow(
                      title: '跟随系统取色',
                      subtitle: settings.dynamicColor
                          ? 'Android 12 及以上从壁纸取色；取色不可用时使用品牌蓝紫'
                          : '使用品牌种子色 #5B6CFF',
                      value: settings.dynamicColor,
                      onChanged: settings.setDynamicColor,
                    ),
                  ],
                ),
              ),
              _Section(
                title: '写作',
                child: _SwitchRow(
                  title: '行动选项直接发送',
                  subtitle: settings.directSend
                      ? '点选选项后立即发出，生成期间只允许一次写入'
                      : '点选选项只填入输入框，可以修改后再发送',
                  value: settings.directSend,
                  onChanged: settings.setDirectSend,
                ),
              ),
              _Section(
                title: '生成预算',
                subtitle: '单次请求只传输出上限，其余由服务端按预设拼装',
                child: Column(
                  children: [
                    _MetricRow(
                      label: '上下文窗口',
                      value:
                          '${formatNumber(GenerationDefaults.contextWindow)} token',
                    ),
                    const SizedBox(height: 10),
                    _MetricRow(
                      label: '输入预算',
                      value:
                          '${formatNumber(GenerationDefaults.inputBudget)} token',
                    ),
                    const SizedBox(height: 10),
                    _MetricRow(
                      label: '单次输出上限',
                      value:
                          '${formatNumber(GenerationDefaults.maxOutputTokens)} token',
                    ),
                    const SizedBox(height: 10),
                    _MetricRow(
                      label: '提示词模式',
                      value:
                          connection.sessions == null ? '未连接' : 'compat_strict',
                    ),
                  ],
                ),
              ),
              _Section(
                title: '数据与隐私',
                subtitle: '访问密钥只写入系统安全存储，不进入偏好或日志',
                child: Column(
                  children: [
                    _ActionRow(
                      icon: Icons.cleaning_services_outlined,
                      title: '清理本机草稿',
                      subtitle: '删除尚未发送的输入文本，不影响服务器历史',
                      onTap: () => _clearDrafts(context),
                    ),
                    const SizedBox(height: 4),
                    _ActionRow(
                      icon: Icons.key_off_outlined,
                      title: '移除已保存的访问密钥',
                      subtitle: settings.value.rememberConnection
                          ? '下次启动需要重新输入密钥'
                          : '当前没有保存密钥',
                      enabled: settings.value.rememberConnection,
                      onTap: () => _forgetCredential(context),
                    ),
                  ],
                ),
              ),
              _Section(
                title: '关于',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MetricRow(label: '应用', value: '天琴'),
                    const SizedBox(height: 10),
                    const _MetricRow(label: '版本', value: '0.1.0 (1)'),
                    const SizedBox(height: 10),
                    const _MetricRow(label: '平台', value: 'Android · Flutter'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '当前版本用原生行动选项替代 HTML 卡面与 JS 显示正则；受控卡面渲染在后续版本实现。'
                      '所有聊天内容以服务器时间线为准。',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DisconnectChoice { cancel, keepKey, removeKey }

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          SurfaceCard(
            borderRadius: AppRadius.lg,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.texts.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      title: Text(title, style: context.texts.titleSmall),
      subtitle: Text(
        subtitle,
        style: context.texts.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? context.colors.onSurface
        : context.colors.onSurfaceVariant.withValues(alpha: 0.6);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled
                    ? context.colors.onSurfaceVariant
                    : context.colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.texts.titleSmall?.copyWith(color: color)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant.withValues(
                          alpha: enabled ? 1 : 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.onSurfaceVariant.withValues(
                  alpha: enabled ? 0.8 : 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (ThemeMode.system, '跟随系统', Icons.brightness_auto_rounded),
    (ThemeMode.light, '浅色', Icons.light_mode_rounded),
    (ThemeMode.dark, '深色', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: context.colors.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final option in _options)
            Expanded(
              child: _ThemeChip(
                label: option.$2,
                icon: option.$3,
                selected: mode == option.$1,
                onTap: () => onChanged(option.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standardCurve,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: ShapeDecoration(
            color: selected
                ? context.colors.secondaryContainer
                : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? context.colors.onSecondaryContainer
                    : context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.texts.labelMedium?.copyWith(
                  color: selected
                      ? context.colors.onSecondaryContainer
                      : context.colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReconnectSheet extends StatefulWidget {
  const _ReconnectSheet({
    required this.endpoint,
    required this.playerName,
    required this.remember,
  });

  final String endpoint;
  final String playerName;
  final bool remember;

  @override
  State<_ReconnectSheet> createState() => _ReconnectSheetState();
}

class _ReconnectSheetState extends State<_ReconnectSheet> {
  late final TextEditingController _endpoint = TextEditingController(
    text: widget.endpoint,
  );
  late final TextEditingController _player = TextEditingController(
    text: widget.playerName,
  );
  final TextEditingController _apiKey = TextEditingController();
  late bool _remember = widget.remember;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _endpoint.dispose();
    _player.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<ConnectionViewModel>().connect(
      endpoint: _endpoint.text,
      apiKey: _apiKey.text,
      playerName: _player.text,
      remember: _remember,
    );
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() {
        _busy = false;
        _error = context.read<ConnectionViewModel>().error ?? '连接失败';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('重新连接', style: context.texts.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '更换实例地址或密钥。连接成功后会重新读取角色与资产。',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _endpoint,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '实例地址',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _apiKey,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '访问密钥',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? '显示密钥' : '隐藏密钥',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _player,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '你的名字',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            SwitchListTile.adaptive(
              value: _remember,
              onChanged: (value) => setState(() => _remember = value),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: Text('记住连接', style: context.texts.titleSmall),
              subtitle: Text(
                _remember ? '密钥写入本机安全存储' : '仅保留在本次运行内存中',
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AppBanner(
                message: _error!,
                color: context.palette.danger,
                icon: Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text('保存并连接'),
            ),
          ],
        ),
      ),
    );
  }
}
