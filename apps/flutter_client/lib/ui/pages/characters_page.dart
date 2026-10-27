import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/format.dart';
import '../../data/models/character_summary.dart';
import '../../viewmodels/connection_view_model.dart';
import '../feedback.dart';
import '../widgets/app_surface.dart';
import '../widgets/new_session_sheet.dart';

class CharactersPage extends StatefulWidget {
  const CharactersPage({super.key});

  @override
  State<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends State<CharactersPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;
  bool _refreshing = false;
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    final connection = context.read<ConnectionViewModel>();
    await connection.refreshCatalog();
    if (!mounted) {
      return;
    }
    setState(() => _refreshing = false);
    final error = connection.error;
    if (error != null) {
      showAppSnack(context, error, isError: true);
    }
  }

  List<CharacterSummary> _filter(List<CharacterSummary> source) {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return source;
    }
    return source
        .where((character) => character.name.toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  Future<void> _start(CharacterSummary? character) async {
    final session = await showNewSessionSheet(context, character: character);
    if (session != null && mounted) {
      context.push('/session/${session.id}', extra: session);
    }
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          _searchFocus.requestFocus();
        }
      });
    } else {
      _search.clear();
      _searchFocus.unfocus();
      setState(() => _keyword = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionViewModel>();
    final all = connection.characters;
    final visible = _filter(all);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: MediaQuery.paddingOf(context).top + 56,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: AppSpacing.page,
              title: Text(
                '角色',
                style: context.texts.headlineSmall?.copyWith(
                  letterSpacing: 0.5,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: _searchOpen ? '关闭搜索' : '搜索角色',
                  onPressed: _toggleSearch,
                  icon: AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: Icon(
                      _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                      key: ValueKey(_searchOpen),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新角色',
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onSurfaceVariant,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '与谁同行',
                      style: context.texts.displayMedium?.copyWith(
                        fontSize: 29,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '角色来自服务器上的角色卡。选择一位，开启新的故事线。',
                      style: context.texts.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    AnimatedSize(
                      duration: AppMotion.standard,
                      curve: AppMotion.standardCurve,
                      alignment: Alignment.topCenter,
                      child: !_searchOpen
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: TextField(
                                controller: _search,
                                focusNode: _searchFocus,
                                onChanged: (value) =>
                                    setState(() => _keyword = value),
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: '搜索角色名',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _search.clear();
                                            setState(() => _keyword = '');
                                          },
                                          icon: const Icon(Icons.clear_rounded),
                                        ),
                                ),
                              ),
                            ),
                    ),
                    if (all.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          '${all.length} 位角色 · 最后更新 ${formatRelativeTime(all.first.updatedAt)}',
                          style: context.texts.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (connection.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.sm,
                  ),
                  child: AppBanner(
                    message: connection.error!,
                    color: context.palette.danger,
                    icon: Icons.error_outline_rounded,
                    action: TextButton(
                      onPressed: _refresh,
                      child: const Text('重试'),
                    ),
                  ),
                ),
              ),
            if (visible.isEmpty)
              SliverToBoxAdapter(
                child: _keyword.trim().isNotEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: '没有匹配的角色',
                        message: '换个关键词，或清空搜索。',
                        action: TextButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _keyword = '');
                          },
                          child: const Text('清空搜索'),
                        ),
                      )
                    : EmptyState(
                        icon: Icons.people_alt_outlined,
                        title: '服务器上还没有角色',
                        message: '先在网页端导入角色卡，再回到这里开始故事。',
                        action: FilledButton.icon(
                          onPressed: _refreshing ? null : _refresh,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('重新读取'),
                        ),
                      ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final character = visible[index];
                    return Entrance(
                      index: index,
                      child: _CharacterCard(
                        character: character,
                        onTap: () => _start(character),
                      ),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.navBarClearance),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        duration: AppMotion.standard,
        curve: AppMotion.spring,
        scale: _searchOpen ? 0.85 : 1,
        child: FloatingActionButton.extended(
          onPressed: () => _start(null),
          icon: const Icon(Icons.auto_stories_rounded, size: 20),
          label: const Text('新的故事'),
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, required this.onTap});

  final CharacterSummary character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final version = character.latestVersionNo;
    final meta = [
      if (version != null && version > 0) '版本 $version',
      if (character.source.trim().isNotEmpty) character.source.trim(),
      if (character.updatedAt > 0)
        '更新于 ${formatRelativeTime(character.updatedAt)}',
    ].join(' · ');

    return SurfaceCard(
      onTap: onTap,
      animate: true,
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: AppShapes.superellipse(17),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.tertiaryContainer,
                  context.colors.primaryContainer,
                ],
              ),
            ),
            child: Text(
              character.initial,
              style: context.texts.headlineSmall?.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: ShapeDecoration(
              color: context.colors.secondaryContainer,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  size: 15,
                  color: context.colors.onSecondaryContainer,
                ),
                const SizedBox(width: 2),
                Text(
                  '开始',
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
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
