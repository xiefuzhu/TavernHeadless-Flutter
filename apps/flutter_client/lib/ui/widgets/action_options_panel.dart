import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/message_derivation.dart';

class ActionOptionsPanel extends StatelessWidget {
  const ActionOptionsPanel({
    super.key,
    required this.options,
    required this.enabled,
    required this.directSend,
    required this.onSelected,
    this.onModeChanged,
    this.footer,
  });

  final List<ActionOption> options;
  final bool enabled;
  final bool directSend;
  final ValueChanged<ActionOption> onSelected;
  final ValueChanged<bool>? onModeChanged;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.68,
      duration: AppMotion.standard,
      child: Container(
        decoration: ShapeDecoration(
          color: context.colors.surfaceContainerHigh,
          shape: AppShapes.superellipse(AppRadius.lg),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  '回应',
                  style: context.texts.labelLarge?.copyWith(color: accent),
                ),
                const SizedBox(width: 6),
                Text(
                  '${options.length}',
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (enabled && onModeChanged != null)
                  _ModeToggle(
                    directSend: directSend,
                    onChanged: onModeChanged!,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < options.length; index++)
              _OptionTile(
                option: options[index],
                enabled: enabled,
                onTap: enabled ? () => onSelected(options[index]) : null,
                showDivider: index != options.length - 1,
              ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  footer!,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.enabled,
    required this.onTap,
    required this.showDivider,
  });

  final ActionOption option;
  final bool enabled;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    option.index.toString().padLeft(2, '0'),
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 10,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      option.text,
                      style: context.texts.bodyMedium?.copyWith(
                        color: enabled
                            ? context.colors.onSurface
                            : context.colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 15,
                    color: context.colors.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: context.palette.hairline.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.directSend, required this.onChanged});

  final bool directSend;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: context.colors.surface,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggle(context, '仅填入', !directSend, () => onChanged(false)),
          _toggle(context, '直接发送', directSend, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _toggle(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: ShapeDecoration(
          color: selected
              ? context.colors.secondaryContainer
              : Colors.transparent,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: selected
                ? context.colors.onSecondaryContainer
                : context.colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 历史消息的行动选项默认只读，折叠起来避免占用阅读空间。
class HistoricalOptions extends StatelessWidget {
  const HistoricalOptions({super.key, required this.options});

  final List<ActionOption> options;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        minTileHeight: 40,
        leading: Icon(
          Icons.history_rounded,
          size: 17,
          color: context.colors.onSurfaceVariant,
        ),
        title: Text(
          '历史行动选项 · ${options.length}',
          style: context.texts.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        iconColor: context.colors.onSurfaceVariant,
        collapsedIconColor: context.colors.onSurfaceVariant,
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${option.index}.',
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      option.text,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
