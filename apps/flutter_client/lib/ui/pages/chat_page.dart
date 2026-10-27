import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_error.dart';
import '../../core/config/generation_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/format.dart';
import '../../data/models/session_models.dart';
import '../../services/message_derivation.dart';
import '../../viewmodels/chat_view_model.dart';
import '../../viewmodels/connection_view_model.dart';
import '../../viewmodels/session_list_view_model.dart';
import '../../viewmodels/settings_controller.dart';
import '../feedback.dart';
import '../widgets/app_surface.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_view.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.sessionId, this.initialSession});

  final String sessionId;
  final SessionSummary? initialSession;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

enum _ChatAction { refresh, diagnostics, rename, archive }

class _ChatPageState extends State<ChatPage> {
  late final ChatViewModel _chat;
  late final AppLifecycleListener _lifecycle;
  final ScrollController _scroll = ScrollController();

  SessionSummary? _session;
  bool _resolving = false;
  String? _resolveError;
  bool _following = true;
  bool _showJump = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatViewModel>();
    _session = widget.initialSession;
    _scroll.addListener(_handleScroll);
    _chat.addListener(_handleChatChanged);
    _lifecycle = AppLifecycleListener(onResume: _handleResume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _chat.removeListener(_handleChatChanged);
    _chat.close();
    _lifecycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) {
      return;
    }
    final initial = _session ?? _findCached();
    if (initial != null) {
      _session = initial;
      await _chat.open(initial);
      return;
    }
    await _resolveSession();
  }

  SessionSummary? _findCached() {
    final list = context.read<SessionListViewModel>();
    for (final session in list.sessions) {
      if (session.id == widget.sessionId) {
        return session;
      }
    }
    return null;
  }

  Future<void> _resolveSession() async {
    final repository = context.read<ConnectionViewModel>().sessions;
    if (repository == null) {
      setState(() => _resolveError = '连接已断开，无法读取这个会话。');
      return;
    }
    setState(() {
      _resolving = true;
      _resolveError = null;
    });
    try {
      final session = await repository.fetchSession(widget.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _resolving = false;
      });
      await _chat.open(session);
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolving = false;
        _resolveError = error.userMessage;
      });
    }
  }

  void _handleResume() {
    _chat.refreshFromServer();
  }

  void _handleScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final offset = _scroll.offset;
    _following = offset < 120;
    final showJump = offset > 320;
    if (showJump != _showJump) {
      setState(() => _showJump = showJump);
    }
  }

  void _handleChatChanged() {
    if (!mounted) {
      return;
    }
    final session = _chat.session;
    if (session != null && session.id != _session?.id) {
      setState(() => _session = session);
    }
    final count = _chat.messages.length;
    if (count > _lastMessageCount && _following) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
    _lastMessageCount = count;
  }

  void _scrollToLatest() {
    if (!mounted || !_scroll.hasClients) {
      return;
    }
    _scroll.animateTo(
      0,
      duration: AppMotion.standard,
      curve: AppMotion.standardCurve,
    );
  }

  Future<void> _handleOption(ActionOption option) async {
    final direct = context.read<SettingsController>().directSend;
    final previous = await _chat.applyOption(option, direct: direct);
    if (!mounted || direct) {
      return;
    }
    final canUndo = previous != null && previous.trim().isNotEmpty;
    showAppSnack(
      context,
      '已填入输入框，可以修改后再发送',
      actionLabel: canUndo ? '撤销' : null,
      onAction: canUndo ? () => _chat.updateDraft(previous) : null,
    );
  }

  Future<void> _rename() async {
    final session = _session ?? _chat.session;
    if (session == null) {
      return;
    }
    final title = await promptText(
      context,
      title: '重命名会话',
      helper: '会话标题',
      initialValue: session.displayTitle,
      maxLength: 200,
    );
    if (title == null || title.isEmpty || !mounted) {
      return;
    }
    final list = context.read<SessionListViewModel>();
    final ok = await list.renameSession(session, title);
    if (!mounted) {
      return;
    }
    if (ok) {
      final updated = session.copyWith(title: title);
      setState(() => _session = updated);
      _chat.updateSession(updated);
    }
    showAppSnack(context, ok ? '已重命名' : (list.error ?? '重命名失败'));
  }

  Future<void> _archive() async {
    final session = _session ?? _chat.session;
    if (session == null) {
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: '归档会话？',
      message: '“${session.displayTitle}”会移到已归档，历史不会删除，可以随时恢复。',
      confirmLabel: '归档',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final list = context.read<SessionListViewModel>();
    final ok = await list.archiveSession(session);
    if (!mounted) {
      return;
    }
    if (ok) {
      context.pop();
      return;
    }
    showAppSnack(context, list.error ?? '归档失败', isError: true);
  }

  Future<void> _showDiagnostics() async {
    await _chat.runDryRun();
    if (!mounted) {
      return;
    }
    final error = _chat.error;
    final diagnostics = _chat.diagnostics;
    if (diagnostics == null) {
      showAppSnack(context, error ?? '暂时无法生成预算预览', isError: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DiagnosticsSheet(diagnostics: diagnostics),
    );
  }

  void _handleAction(_ChatAction action) {
    switch (action) {
      case _ChatAction.refresh:
        _chat.refreshFromServer(manual: true);
      case _ChatAction.diagnostics:
        _showDiagnostics();
      case _ChatAction.rename:
        _rename();
      case _ChatAction.archive:
        _archive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatViewModel>();
    final settings = context.watch<SettingsController>();
    final connection = context.watch<ConnectionViewModel>();
    final session = chat.session ?? _session;
    final busy = chat.busy || chat.streaming || chat.recovering;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session?.displayTitle ?? '会话',
              style: context.texts.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (session != null)
              Text(
                [
                  session.displayCharacter,
                  if (chat.totalFloors > 0) '第 ${chat.totalFloors} 层',
                  if (chat.phaseLabel != null) chat.phaseLabel!,
                ].join(' · '),
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '与服务器同步',
            onPressed: chat.loading ? null : () => chat.refreshFromServer(manual: true),
            icon: const Icon(Icons.sync_rounded),
          ),
          PopupMenuButton<_ChatAction>(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: _handleAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ChatAction.refresh,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh_rounded, size: 18),
                  title: Text('刷新时间线'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: _ChatAction.diagnostics,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.analytics_outlined, size: 18),
                  title: Text('提示词预算'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: _ChatAction.rename,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined, size: 18),
                  title: Text('重命名'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: _ChatAction.archive,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.archive_outlined, size: 18),
                  title: Text('归档会话'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          AnimatedAlign(
            alignment: Alignment.topCenter,
            heightFactor: busy ? 1 : 0,
            duration: AppMotion.fast,
            child: const LinearProgressIndicator(minHeight: 2),
          ),
          AnimatedSize(
            duration: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: chat.error != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      0,
                    ),
                    child: AppBanner(
                      message: chat.error!,
                      color: context.palette.danger,
                      icon: Icons.error_outline_rounded,
                      action: TextButton(
                        onPressed: () => chat.refreshFromServer(manual: true),
                        child: const Text('重试'),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          AnimatedSize(
            duration: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: chat.notice != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      0,
                    ),
                    child: AppBanner(
                      message: chat.notice!,
                      color: chat.recovering
                          ? context.colors.primary
                          : context.palette.warning,
                      icon: chat.recovering
                          ? Icons.hourglass_top_rounded
                          : Icons.info_outline_rounded,
                      action: IconButton(
                        tooltip: '关闭提示',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: chat.clearNotice,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(
            child: _buildContent(
              chat: chat,
              settings: settings,
              connection: connection,
              session: session,
            ),
          ),
        ],
      ),
      bottomNavigationBar: ChatComposer(viewModel: chat),
    );
  }

  Widget _buildContent({
    required ChatViewModel chat,
    required SettingsController settings,
    required ConnectionViewModel connection,
    required SessionSummary? session,
  }) {
    if (_resolving) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_resolveError != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: '无法打开会话',
        message: _resolveError!,
        action: FilledButton.icon(
          onPressed: () {
            setState(() => _resolveError = null);
            _bootstrap();
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('重试'),
        ),
      );
    }
    final messages = chat.messages;
    if (chat.loading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: '故事还没有开始',
        message: '在下面写下第一句话。内容保存在服务器，不会只留在这台手机上。',
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          itemCount: messages.length + 1,
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return _TimelineHead(viewModel: chat);
            }
            final message = messages[messages.length - 1 - index];
            return _MemoMessage(
              key: ValueKey(message.id),
              message: message,
              playerName: connection.playerName,
              characterName: session?.displayCharacter ?? '角色',
              canUseOptions: chat.canUseOptions(message),
              directSend: settings.directSend,
              onSelected: _handleOption,
              onModeChanged: (direct) =>
                  context.read<SettingsController>().setDirectSend(direct),
            );
          },
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.sm,
          child: AnimatedScale(
            scale: _showJump ? 1 : 0.7,
            duration: AppMotion.fast,
            curve: AppMotion.spring,
            child: AnimatedOpacity(
              opacity: _showJump ? 1 : 0,
              duration: AppMotion.fast,
              child: IgnorePointer(
                ignoring: !_showJump,
                child: Material(
                  color: context.colors.secondaryContainer,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _scrollToLatest,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                        size: 20,
                        color: context.colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineHead extends StatelessWidget {
  const _TimelineHead({required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.hasEarlier) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Center(
          child: viewModel.loadingEarlier
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton.icon(
                  onPressed: viewModel.loadEarlier,
                  icon: const Icon(Icons.expand_less_rounded, size: 18),
                  label: Text('加载更早的 ${viewModel.loadedOffset} 层'),
                ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg, top: AppSpacing.xs),
      child: Center(
        child: Text(
          '故事从这里开始',
          style: context.texts.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// 流式刷新时避免重复解析未变化的 Markdown。
/// 只有内容、选项、权限、主题或字号变化时才重建整条消息。
class _MemoMessage extends StatefulWidget {
  const _MemoMessage({
    super.key,
    required this.message,
    required this.playerName,
    required this.characterName,
    required this.canUseOptions,
    required this.directSend,
    required this.onSelected,
    required this.onModeChanged,
  });

  final DisplayMessage message;
  final String playerName;
  final String characterName;
  final bool canUseOptions;
  final bool directSend;
  final ValueChanged<ActionOption> onSelected;
  final ValueChanged<bool> onModeChanged;

  @override
  State<_MemoMessage> createState() => _MemoMessageState();
}

class _MemoMessageState extends State<_MemoMessage> {
  Widget? _cached;
  String? _content;
  String? _markdown;
  int _optionCount = -1;
  bool _canUse = false;
  bool _direct = false;
  bool _streaming = false;
  bool _unconfirmed = false;
  String _character = '';
  String _player = '';
  ThemeData? _theme;
  TextScaler? _textScaler;

  bool _isFresh() {
    final message = widget.message;
    return _cached != null &&
        _content == message.content &&
        _markdown == message.derived.markdown &&
        _optionCount == message.derived.options.length &&
        _canUse == widget.canUseOptions &&
        _direct == widget.directSend &&
        _streaming == message.isStreaming &&
        _unconfirmed == message.isUnconfirmed &&
        _character == widget.characterName &&
        _player == widget.playerName &&
        _theme == Theme.of(context) &&
        _textScaler == MediaQuery.textScalerOf(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFresh()) {
      return _cached!;
    }
    final message = widget.message;
    _content = message.content;
    _markdown = message.derived.markdown;
    _optionCount = message.derived.options.length;
    _canUse = widget.canUseOptions;
    _direct = widget.directSend;
    _streaming = message.isStreaming;
    _unconfirmed = message.isUnconfirmed;
    _character = widget.characterName;
    _player = widget.playerName;
    _theme = Theme.of(context);
    _textScaler = MediaQuery.textScalerOf(context);
    _cached = MessageView(
      message: message,
      playerName: widget.playerName,
      characterName: widget.characterName,
      canUseOptions: widget.canUseOptions,
      directSend: widget.directSend,
      onSelected: widget.onSelected,
      onModeChanged: widget.onModeChanged,
    );
    return _cached!;
  }
}

class _DiagnosticsSheet extends StatelessWidget {
  const _DiagnosticsSheet({required this.diagnostics});

  final DryRunDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('提示词预算预览', style: context.texts.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '只读取服务端的拼装结果，不会写入会话，也不会触发模型生成。',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SurfaceCard(
              color: context.colors.surfaceContainerHigh,
              child: Column(
                children: [
                  _MetricRow(
                    label: '估算输入 token',
                    value: formatNumber(diagnostics.tokenEstimate),
                  ),
                  const SizedBox(height: 10),
                  _MetricRow(
                    label: '可用于回复',
                    value: formatNumber(diagnostics.availableForReply),
                  ),
                  const SizedBox(height: 10),
                  _MetricRow(
                    label: '拼装模式',
                    value: diagnostics.assemblyMode,
                  ),
                  const SizedBox(height: 10),
                  _MetricRow(
                    label: '使用预设',
                    value: diagnostics.presetUsed ? '是' : '否',
                  ),
                  const SizedBox(height: 10),
                  _MetricRow(
                    label: '世界书命中',
                    value: '${diagnostics.worldbookHits} 条',
                  ),
                ],
              ),
            ),
            if (diagnostics.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final warning in diagnostics.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AppBanner(
                    message: warning,
                    color: context.palette.warning,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              '单次输出上限 ${formatNumber(GenerationDefaults.maxOutputTokens)} token；预算不足时先精简预设或世界书。',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
