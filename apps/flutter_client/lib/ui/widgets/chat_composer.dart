import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../viewmodels/chat_view_model.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, required this.viewModel});

  final ChatViewModel viewModel;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _focusSignal = 0;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_syncFromViewModel);
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChanged);
    _syncFromViewModel();
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_syncFromViewModel);
      widget.viewModel.addListener(_syncFromViewModel);
      _syncFromViewModel();
    }
  }

  void _handleFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  void _handleTextChanged() {
    widget.viewModel.updateDraft(_controller.text);
  }

  void _syncFromViewModel() {
    if (!mounted) {
      return;
    }
    final viewModel = widget.viewModel;
    final desired = viewModel.draft;
    if (_controller.text != desired) {
      _controller.value = TextEditingValue(
        text: desired,
        selection: TextSelection.collapsed(offset: desired.length),
      );
    }
    if (viewModel.focusSignal != _focusSignal) {
      _focusSignal = viewModel.focusSignal;
      _focusNode.requestFocus();
      final length = _controller.text.length;
      _controller.selection = TextSelection.collapsed(offset: length);
    }
  }

  bool get _composing =>
      _controller.value.composing.isValid &&
      !_controller.value.composing.isCollapsed;

  void _send() {
    if (_composing) {
      return;
    }
    final viewModel = widget.viewModel;
    if (viewModel.busy || viewModel.streaming || viewModel.recovering) {
      return;
    }
    if (_controller.text.trim().isEmpty) {
      return;
    }
    viewModel.send();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_syncFromViewModel);
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleTextChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final locked = viewModel.busy || viewModel.recovering;
    final canSend =
        !locked && !viewModel.streaming && _controller.text.trim().isNotEmpty;
    final hint = viewModel.streaming
        ? (viewModel.phaseLabel ?? '正在接收正文')
        : viewModel.recovering
        ? '正在恢复服务端生成状态'
        : viewModel.busy
        ? '正在提交…'
        : 'Ctrl / ⌘ + Enter 发送';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ): _send,
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        meta: true,
                      ): _send,
                    },
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      curve: AppMotion.standardCurve,
                      constraints: const BoxConstraints(
                        maxHeight: AppSizes.composerMaxHeight,
                      ),
                      decoration: ShapeDecoration(
                        color: context.colors.surfaceContainerHigh,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          side: BorderSide(
                            color: _focused
                                ? context.colors.primary.withValues(alpha: 0.7)
                                : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 2,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enabled: !viewModel.recovering,
                        style: context.texts.bodyLarge?.copyWith(height: 1.5),
                        decoration: InputDecoration(
                          hintText: viewModel.hasSession
                              ? '写下你的回应…'
                              : '先选择一个会话',
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _SendButton(
                  streaming: viewModel.streaming,
                  enabled: canSend,
                  onSend: _send,
                  onStop: viewModel.stopStreaming,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (viewModel.canRegenerate)
                  _MiniAction(
                    icon: Icons.refresh_rounded,
                    label: '重新生成',
                    onTap: viewModel.regenerate,
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                Text(
                  hint,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant.withValues(
                      alpha: 0.75,
                    ),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.colors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.streaming,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final bool streaming;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final active = streaming || enabled;
    return AnimatedScale(
      scale: active ? 1 : 0.94,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: SizedBox(
        width: AppSizes.minTouchTarget,
        height: AppSizes.minTouchTarget,
        child: Material(
          color: streaming
              ? context.palette.dangerContainer
              : enabled
              ? context.colors.primary
              : context.colors.surfaceContainerHighest,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: streaming
                ? onStop
                : enabled
                ? onSend
                : null,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              switchInCurve: AppMotion.standardCurve,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                streaming
                    ? Icons.stop_rounded
                    : Icons.arrow_upward_rounded,
                key: ValueKey(streaming ? 'stop' : 'send'),
                size: 22,
                color: streaming
                    ? context.palette.onDangerContainer
                    : enabled
                    ? context.colors.onPrimary
                    : context.colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
