import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/format.dart';
import '../../data/models/session_models.dart';
import '../../viewmodels/connection_view_model.dart';
import '../../viewmodels/session_list_view_model.dart';
import '../feedback.dart';
import '../widgets/app_surface.dart';
import '../widgets/new_session_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final list = context.read<SessionListViewModel>();
      if (!list.loading && !list.hasSessions) {
        list.load();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _openNewSession() async {
    final session = await showNewSessionSheet(context);
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
      context.read<SessionListViewModel>().setKeyword('');
      _searchFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<SessionListViewModel>();
    final connection = context.watch<ConnectionViewModel>();
    final visible = list.visibleSessions;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => list.load(silent: true),
        edgeOffset: MediaQuery.paddingOf(context).top + 56,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: AppSpacing.page,
              title: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '天琴',
                        style: context.texts.headlineSmall?.copyWith(
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${_greeting()}，${connection.playerName}',
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: _searchOpen ? '关闭搜索' : '搜索会话',
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
                  tooltip: '刷新',
                  onPressed: () => list.load(silent: true),
                  icon: const Icon(Icons.refresh_rounded),
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
                    _ConnectionStrip(
                      connection: connection,
                      onTap: () => context.go('/settings'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '继续你的故事',
                      style: context.texts.displayMedium?.copyWith(
                        fontSize: 29,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '选择一段旅程，或者从新的角色开始。',
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
                                onChanged: (value) {
                                  list.setKeyword(value);
                                  setState(() {});
                                },
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: '搜索标题或角色',
                                  prefixIcon:
                                      const Icon(Icons.search_rounded),
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _search.clear();
                                            list.setKeyword('');
                                            setState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: '进行中',
                      selected: list.filter == SessionFilter.active,
                      onTap: () => list.setFilter(SessionFilter.active),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: '已归档',
                      selected: list.filter == SessionFilter.archived,
                      onTap: () => list.setFilter(SessionFilter.archived),
                    ),
                    const Spacer(),
                    if (list.loading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        '${visible.length} 个会话',
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (list.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.sm,
                  ),
                  child: AppBanner(
                    message: list.error!,
                    color: context.palette.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                ),
              ),
            if (visible.isEmpty && !list.loading)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: list.filter == SessionFilter.archived
                      ? Icons.inventory_2_outlined
                      : Icons.nights_stay_outlined,
                  title: list.keyword.trim().isNotEmpty
                      ? '没有匹配的会话'
                      : list.filter == SessionFilter.archived
                      ? '归档箱是空的'
                      : '还没有故事',
                  message: list.keyword.trim().isNotEmpty
                      ? '换个关键词，或清空搜索。'
                      : list.filter == SessionFilter.archived
                      ? '归档的会话会保留在这里，可以随时恢复。'
                      : '选一个角色，写下第一句话。',
                  action: list.filter == SessionFilter.active
                      ? FilledButton.icon(
                          onPressed: _openNewSession,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('开始新的故事'),
                        )
                      : null,
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
                    final session = visible[index];
                    return Entrance(
                      index: index,
                      child: _SessionCard(
                        session: session,
                        busy: list.mutating,
                        onOpen: () => context.push(
                          '/session/${session.id}',
                          extra: session,
                        ),
                        onRename: () => _rename(session, list),
                        onArchive: () => _toggleArchive(session, list),
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
          onPressed: _openNewSession,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('新的故事'),
        ),
      ),
    );
  }

  Future<void> _rename(
    SessionSummary session,
    SessionListViewModel list,
  ) async {
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
    final ok = await list.renameSession(session, title);
    if (!mounted) {
      return;
    }
    showAppSnack(context, ok ? '已重命名' : (list.error ?? '重命名失败'));
  }

  Future<void> _toggleArchive(
    SessionSummary session,
    SessionListViewModel list,
  ) async {
    final archived = list.filter == SessionFilter.active;
    final confirmed = await confirmAction(
      context,
      title: archived ? '归档会话？' : '恢复会话？',
      message: archived
          ? '“${session.displayTitle}”会从进行中移到已归档，历史不会删除，可随时恢复。'
          : '“${session.displayTitle}”会重新出现在进行中列表。',
      confirmLabel: archived ? '归档' : '恢复',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final ok = archived
        ? await list.archiveSession(session)
        : await list.restoreSession(session);
    if (!mounted) {
      return;
    }
    showAppSnack(
      context,
      ok ? (archived ? '会话已归档' : '会话已恢复') : (list.error ?? '操作失败'),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return '夜深了';
    }
    if (hour < 11) {
      return '早上好';
    }
    if (hour < 14) {
      return '中午好';
    }
    if (hour < 18) {
      return '下午好';
    }
    return '晚上好';
  }
}

class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({required this.connection, required this.onTap});

  final ConnectionViewModel connection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = connection.isConnected;
    return SurfaceCard(
      onTap: onTap,
      animate: true,
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: context.colors.surfaceContainerLow,
      child: Row(
        children: [
          StatusPill(
            label: connected ? '已连接' : '未连接',
            color: connected
                ? context.palette.success
                : context.palette.warning,
            dense: true,
            pulse: connected,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${connection.endpoint} · ${connection.playerName}',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 16 : 14,
            vertical: 8,
          ),
          child: Text(
            label,
            style: context.texts.labelMedium?.copyWith(
              color: selected
                  ? context.colors.onSecondaryContainer
                  : context.colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SessionAction { rename, archive }

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.onOpen,
    required this.onRename,
    required this.onArchive,
  });

  final SessionSummary session;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final archived = session.isArchived;
    return SurfaceCard(
      onTap: busy ? null : onOpen,
      animate: true,
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: AppShapes.superellipse(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: archived
                    ? [
                        context.colors.surfaceContainerHighest,
                        context.colors.surfaceContainerHigh,
                      ]
                    : [
                        context.colors.primaryContainer,
                        context.colors.tertiaryContainer,
                      ],
              ),
            ),
            child: Text(
              session.displayCharacter.characters.first,
              style: context.texts.titleMedium?.copyWith(
                color: archived
                    ? context.colors.onSurfaceVariant
                    : context.colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.displayTitle,
                        style: context.texts.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (archived)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: StatusPill(
                          label: '已归档',
                          color: context.colors.onSurfaceVariant,
                          dense: true,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${session.displayCharacter} · ${formatRelativeTime(session.updatedAt)}',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (session.modelName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    session.modelName!,
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<_SessionAction>(
            enabled: !busy,
            tooltip: '更多操作',
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: context.colors.onSurfaceVariant,
            ),
            onSelected: (action) {
              switch (action) {
                case _SessionAction.rename:
                  onRename();
                case _SessionAction.archive:
                  onArchive();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _SessionAction.rename,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined, size: 18),
                  title: Text('重命名'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: _SessionAction.archive,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 18,
                  ),
                  title: Text(archived ? '恢复会话' : '归档会话'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
