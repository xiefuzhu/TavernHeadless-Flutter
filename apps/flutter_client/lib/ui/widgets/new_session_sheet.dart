import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/generation_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/asset_item.dart';
import '../../data/models/character_summary.dart';
import '../../data/models/session_models.dart';
import '../../viewmodels/connection_view_model.dart';
import '../../viewmodels/session_list_view_model.dart';
import '../widgets/app_surface.dart';

Future<SessionSummary?> showNewSessionSheet(
  BuildContext context, {
  CharacterSummary? character,
}) {
  return showModalBottomSheet<SessionSummary>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NewSessionSheet(initialCharacter: character),
  );
}

class NewSessionSheet extends StatefulWidget {
  const NewSessionSheet({super.key, this.initialCharacter});

  final CharacterSummary? initialCharacter;

  @override
  State<NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<NewSessionSheet> {
  late final TextEditingController _title;
  final FocusNode _titleFocus = FocusNode();
  String? _characterId;
  AssetSelection _assets = const AssetSelection();
  bool _creating = false;
  bool _titleEdited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final connection = context.read<ConnectionViewModel>();
    _characterId = widget.initialCharacter?.id ??
        (connection.characters.isNotEmpty
            ? connection.characters.first.id
            : null);
    _title = TextEditingController(
      text: widget.initialCharacter?.name ??
          (connection.characters.isNotEmpty
              ? connection.characters.first.name
              : ''),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) {
      return;
    }
    final characterId = _characterId;
    if (characterId == null) {
      setState(() => _error = '先选择一个角色。');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    final list = context.read<SessionListViewModel>();
    final session = await list.createSession(
      characterId: characterId,
      title: _title.text,
      assets: _assets,
    );
    if (!mounted) {
      return;
    }
    if (session == null) {
      setState(() {
        _creating = false;
        _error = list.error ?? '创建会话失败，请稍后重试。';
      });
      return;
    }
    Navigator.of(context).pop(session);
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionViewModel>();
    final characters = connection.characters;
    final assets = connection.assets;
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: FractionallySizedBox(
        heightFactor: insets.bottom > 0 ? 1 : 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xs,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('新的故事', style: context.texts.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          '明确选择角色与资产；不会自动套用其他角色的配置。',
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                children: [
                  const SectionHeader(title: '角色'),
                  if (characters.isEmpty)
                    AppBanner(
                      message: '服务器上还没有角色。先在网页端导入角色卡，再回到这里开始故事。',
                      color: context.palette.warning,
                      icon: Icons.person_off_outlined,
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final character in characters)
                          _CharacterChip(
                            character: character,
                            selected: character.id == _characterId,
                            onTap: () {
                              setState(() {
                                _characterId = character.id;
                                if (!_titleEdited) {
                                  _title.text = character.name;
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: '会话标题',
                    subtitle: '之后可以在会话列表里重命名。',
                  ),
                  TextField(
                    controller: _title,
                    focusNode: _titleFocus,
                    maxLength: 200,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: '例如：雨夜的旅店',
                      counterText: '',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    onChanged: (_) => _titleEdited = true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: '资产组合',
                    subtitle: '默认不绑定任何资产。按需选择预设、世界书与显示正则。',
                  ),
                  _AssetPicker(
                    label: '预设',
                    emptyLabel: '服务器上没有可用预设',
                    items: assets.presets,
                    selectedId: _assets.presetId,
                    onSelected: (id) => setState(
                      () => _assets = _assets.copyWith(
                        presetId: id,
                        clearPreset: id == null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AssetPicker(
                    label: '世界书',
                    emptyLabel: '服务器上没有可用世界书',
                    items: assets.worldbooks,
                    selectedId: _assets.worldbookId,
                    onSelected: (id) => setState(
                      () => _assets = _assets.copyWith(
                        worldbookId: id,
                        clearWorldbook: id == null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AssetPicker(
                    label: '显示正则',
                    emptyLabel: '服务器上没有可用正则配置',
                    items: assets.regexProfiles,
                    selectedId: _assets.regexId,
                    onSelected: (id) => setState(
                      () => _assets = _assets.copyWith(
                        regexId: id,
                        clearRegex: id == null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SurfaceCard(
                    color: context.colors.surfaceContainerHigh,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        _SummaryRow(label: '玩家身份', value: connection.playerName),
                        const SizedBox(height: 8),
                        _SummaryRow(
                          label: '上下文预算',
                          value: '${GenerationDefaults.contextLabel} token',
                        ),
                        const SizedBox(height: 8),
                        _SummaryRow(
                          label: '单次输出上限',
                          value: '${GenerationDefaults.outputLabel} token',
                        ),
                        const SizedBox(height: 8),
                        const _SummaryRow(label: '提示词模式', value: 'compat_strict'),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppBanner(
                      message: _error!,
                      color: context.palette.danger,
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xs,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _creating || characters.isEmpty ? null : _create,
                  child: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('开始新的故事'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterChip extends StatelessWidget {
  const _CharacterChip({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final CharacterSummary character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.colors.secondaryContainer
          : context.colors.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedPadding(
          duration: AppMotion.fast,
          padding: EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: selected
                      ? context.colors.onSecondaryContainer.withValues(
                          alpha: 0.12,
                        )
                      : context.colors.surfaceContainerHighest,
                  shape: AppShapes.superellipse(9),
                ),
                child: Text(
                  character.initial,
                  style: context.texts.labelMedium?.copyWith(
                    color: selected
                        ? context.colors.onSecondaryContainer
                        : context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                character.name,
                style: context.texts.labelLarge?.copyWith(
                  color: selected
                      ? context.colors.onSecondaryContainer
                      : context.colors.onSurface,
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

class _AssetPicker extends StatelessWidget {
  const _AssetPicker({
    required this.label,
    required this.emptyLabel,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final String label;
  final String emptyLabel;
  final List<AssetItem> items;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.texts.labelLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('不绑定'),
                selected: selectedId == null,
                onSelected: (_) => onSelected(null),
              ),
              for (final item in items)
                ChoiceChip(
                  label: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: item.id == selectedId,
                  onSelected: (_) => onSelected(item.id),
                ),
            ],
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: context.texts.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: context.texts.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
