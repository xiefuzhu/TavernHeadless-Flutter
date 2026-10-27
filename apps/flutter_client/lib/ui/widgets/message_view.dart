import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/message_derivation.dart';
import '../../viewmodels/chat_view_model.dart';
import '../feedback.dart';
import 'action_options_panel.dart';
import 'app_surface.dart';

class MessageView extends StatelessWidget {
  const MessageView({
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
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _UserBubble(message: message, playerName: playerName);
    }
    return _AssistantBubble(
      message: message,
      characterName: characterName,
      canUseOptions: canUseOptions,
      directSend: directSend,
      onSelected: onSelected,
      onModeChanged: onModeChanged,
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.playerName});

  final DisplayMessage message;
  final String playerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: ShapeDecoration(
              color: context.colors.primaryContainer,
              shape: AppShapes.superellipse(22),
            ),
            child: SelectionArea(
              child: Text(
                message.content,
                style: context.texts.bodyLarge?.copyWith(
                  color: context.colors.onPrimaryContainer,
                  height: 1.55,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              message.isPending ? '发送中…' : playerName,
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.message,
    required this.characterName,
    required this.canUseOptions,
    required this.directSend,
    required this.onSelected,
    required this.onModeChanged,
  });

  final DisplayMessage message;
  final String characterName;
  final bool canUseOptions;
  final bool directSend;
  final ValueChanged<ActionOption> onSelected;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final initial = characterName.trim().isEmpty
        ? '·'
        : String.fromCharCode(characterName.trim().runes.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: context.colors.tertiaryContainer,
                  shape: AppShapes.superellipse(9),
                ),
                child: Text(
                  initial,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                characterName,
                style: context.texts.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message.isStreaming || message.isUnconfirmed) ...[
                const SizedBox(width: 8),
                StatusPill(
                  label: message.isStreaming ? '续写中' : '未确认',
                  color: message.isStreaming
                      ? context.colors.primary
                      : context.palette.warning,
                  dense: true,
                  pulse: message.isStreaming,
                ),
              ],
              const Spacer(),
              if (message.content.trim().isNotEmpty)
                IconButton(
                  tooltip: '复制正文',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: message.content),
                    );
                    if (context.mounted) {
                      showAppSnack(context, '正文已复制');
                    }
                  },
                  icon: Icon(
                    Icons.copy_rounded,
                    color: context.colors.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            decoration: ShapeDecoration(
              color: context.colors.surfaceContainerLow,
              shape: AppShapes.superellipse(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.content.trim().isEmpty)
                  _EmptyBody(message: message)
                else
                  MarkdownBody(
                    data: message.derived.markdown,
                    selectable: true,
                    softLineBreak: true,
                    styleSheet: appMarkdownStyle(context),
                    onTapLink: (text, href, title) {
                      if (href == null || href.isEmpty) {
                        return;
                      }
                      _showLinkDialog(context, href);
                    },
                    imageBuilder: (uri, title, alt) =>
                        _ImagePlaceholder(uri: uri, alt: alt),
                  ),
                if (message.derived.hasCard)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '此消息包含 HTML 卡面；当前版本用原生行动选项代替，受控卡面渲染在 M3 实现。',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                if (message.derived.optionsUnclosed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: AppBanner(
                      message: '行动选项没有闭合，可能已达到模型输出上限。可以重新生成，或降低预设字数要求。',
                      color: context.palette.warning,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
              ],
            ),
          ),
          if (message.derived.hasOptions) ...[
            const SizedBox(height: AppSpacing.sm),
            if (canUseOptions)
              ActionOptionsPanel(
                options: message.derived.options,
                enabled: true,
                directSend: directSend,
                onSelected: onSelected,
                onModeChanged: onModeChanged,
                footer: directSend
                    ? '点选后立即发出；生成期间只允许一次写入。'
                    : '点选后只填入输入框，不会立即发送。',
              )
            else
              HistoricalOptions(options: message.derived.options),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              message.isStreaming
                  ? '正在接收…'
                  : message.floorNo > 0
                  ? '第 ${message.floorNo} 层'
                  : '',
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.message});

  final DisplayMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isStreaming) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '正在等待第一段正文…',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return AppBanner(
      message: message.isUnconfirmed
          ? '这段内容没有在服务端确认提交。如需保留，请复制后重新发送。'
          : '模型没有返回正文，可能已用尽输出预算。可以重新生成，或降低预设的字数要求。',
      color: context.palette.warning,
      icon: Icons.text_snippet_outlined,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.uri, required this.alt});

  final Uri uri;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: ShapeDecoration(
        color: context.colors.surfaceContainerHighest,
        shape: AppShapes.control,
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 18,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alt?.isNotEmpty == true ? '图片：$alt（不会自动加载远程资源）' : '图片不会自动加载远程资源',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showLinkDialog(BuildContext context, String href) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('外部链接'),
      content: SelectableText(href),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: href));
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
              showAppSnack(context, '链接已复制，请自行在浏览器打开');
            }
          },
          child: const Text('复制链接'),
        ),
      ],
    ),
  );
}

MarkdownStyleSheet appMarkdownStyle(BuildContext context) {
  final base =
      context.texts.bodyLarge ??
      const TextStyle(fontSize: 16, height: 1.62);
  final body = base.copyWith(
    color: context.colors.onSurface,
    fontSize: 15.5,
    height: 1.72,
  );
  final heading = body.copyWith(fontWeight: FontWeight.w700, height: 1.32);
  return MarkdownStyleSheet(
    p: body,
    pPadding: const EdgeInsets.only(bottom: 10),
    a: body.copyWith(
      color: context.colors.primary,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.primary.withValues(alpha: 0.5),
    ),
    em: body.copyWith(fontStyle: FontStyle.italic),
    strong: body.copyWith(fontWeight: FontWeight.w700),
    del: body.copyWith(decoration: TextDecoration.lineThrough),
    h1: heading.copyWith(fontSize: 21),
    h1Padding: const EdgeInsets.only(top: 6, bottom: 6),
    h2: heading.copyWith(fontSize: 19),
    h2Padding: const EdgeInsets.only(top: 6, bottom: 5),
    h3: heading.copyWith(fontSize: 17),
    h3Padding: const EdgeInsets.only(top: 5, bottom: 4),
    h4: heading.copyWith(fontSize: 16),
    h5: heading.copyWith(fontSize: 15),
    h6: heading.copyWith(fontSize: 14.5),
    code: body.copyWith(
      fontFamily: 'monospace',
      fontSize: 13.5,
      backgroundColor: context.colors.surfaceContainerHighest,
      color: context.colors.onSurface,
    ),
    codeblockPadding: const EdgeInsets.all(AppSpacing.sm),
    codeblockDecoration: BoxDecoration(
      color: context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    blockquote: body.copyWith(color: context.colors.onSurfaceVariant),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    blockquoteDecoration: BoxDecoration(
      color: context.colors.primary.withValues(alpha: 0.05),
      border: Border(
        left: BorderSide(color: context.colors.primary, width: 3),
      ),
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    listBullet: body.copyWith(color: context.colors.onSurfaceVariant),
    listIndent: 22,
    tableBorder: TableBorder.all(
      color: context.palette.hairline,
      width: 0.8,
    ),
    tableHead: body.copyWith(fontWeight: FontWeight.w700),
    tableBody: body.copyWith(fontSize: 14.5),
    tablePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.palette.hairline)),
    ),
  );
}
