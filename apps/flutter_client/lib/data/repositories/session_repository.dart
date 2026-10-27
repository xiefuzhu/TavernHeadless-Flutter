import '../../core/network/api_error.dart';
import '../../core/network/tavern_api_client.dart';
import '../models/asset_item.dart';
import '../models/json_utils.dart';
import '../models/session_models.dart';

class SessionRepository {
  SessionRepository(this._api);

  final TavernApiClient _api;

  Future<List<SessionSummary>> fetchSessions({
    String status = 'active',
    String? keyword,
    int limit = 100,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      '/sessions',
      query: {
        'status': status,
        'limit': limit,
        'offset': offset,
        'sort_by': 'updated_at',
        'sort_order': 'desc',
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    return readObjectList(json['data'])
        .map(SessionSummary.fromJson)
        .where((session) => session.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<SessionSummary> createSession({
    required String characterId,
    required String title,
    required String playerName,
    required AssetSelection assets,
    String promptMode = 'compat_strict',
  }) async {
    final json = await _api.postJson(
      '/sessions',
      body: {
        'character_id': characterId,
        'title': title,
        'user_snapshot': {'name': playerName},
        'preset_id': assets.presetId,
        'regex_profile_id': assets.regexId,
        'worldbook_profile_id': assets.worldbookId,
        'prompt_mode': promptMode,
      },
    );
    final data = readMap(json['data']);
    if (data.isEmpty) {
      throw const ApiError(message: '创建会话没有返回会话信息');
    }
    return SessionSummary.fromJson(data);
  }

  /// 深链进入会话时补取会话元信息；列表页已有缓存时不会用到这里。
  Future<SessionSummary> fetchSession(String sessionId) async {
    final json = await _api.getJson('/sessions/$sessionId');
    final data = readMap(json['data']);
    if (data.isEmpty) {
      throw const ApiError(message: '会话不存在或已被删除');
    }
    return SessionSummary.fromJson(data);
  }

  Future<SessionSummary> renameSession(String sessionId, String title) async {
    final json = await _api.patchJson(
      '/sessions/$sessionId',
      body: {'title': title},
    );
    return SessionSummary.fromJson(readMap(json['data']));
  }

  Future<SessionSummary> updateStatus(String sessionId, String status) async {
    final json = await _api.patchJson(
      '/sessions/$sessionId',
      body: {'status': status},
    );
    return SessionSummary.fromJson(readMap(json['data']));
  }

  /// 读取一页时间线。服务端按 floor_no 升序返回，offset 从最早的一层开始。
  Future<SessionTimeline> fetchTimeline(
    String sessionId, {
    int limit = 60,
    int offset = 0,
    String branchId = 'main',
  }) async {
    final json = await _api.getJson(
      '/sessions/$sessionId/timeline',
      query: {
        'branch_id': branchId,
        'limit': limit,
        'offset': offset,
      },
    );
    return SessionTimeline.fromJson(json);
  }

  /// 定位最新一页：先用 limit=1 取得总数，再取尾部页，避免只看到最早的历史。
  Future<SessionTimeline> fetchLatestTimeline(
    String sessionId, {
    int pageSize = 60,
    String branchId = 'main',
  }) async {
    final probe = await fetchTimeline(
      sessionId,
      limit: 1,
      offset: 0,
      branchId: branchId,
    );
    if (probe.total <= pageSize) {
      return fetchTimeline(
        sessionId,
        limit: pageSize,
        offset: 0,
        branchId: branchId,
      );
    }
    return fetchTimeline(
      sessionId,
      limit: pageSize,
      offset: probe.total - pageSize,
      branchId: branchId,
    );
  }

  /// 向上补页，不改变已加载消息的阅读锚点。
  Future<SessionTimeline> fetchEarlier(
    String sessionId, {
    required int currentOffset,
    int pageSize = 60,
    String branchId = 'main',
  }) async {
    final offset = currentOffset - pageSize;
    return fetchTimeline(
      sessionId,
      limit: pageSize,
      offset: offset < 0 ? 0 : offset,
      branchId: branchId,
    );
  }

  Future<ActiveRun> fetchActiveRun(String sessionId) async {
    final json = await _api.getJson('/sessions/$sessionId/active-run');
    final activeRun = readMap(readMap(json['data'])['active_run']);
    if (activeRun.isEmpty) {
      return const ActiveRun.idle();
    }
    return ActiveRun.fromJson(activeRun);
  }
}
