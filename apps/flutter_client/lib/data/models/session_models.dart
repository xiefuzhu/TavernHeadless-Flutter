import 'json_utils.dart';

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.characterName,
    this.characterId,
    this.playerName,
    this.presetId,
    this.regexProfileId,
    this.worldbookProfileId,
    this.promptMode,
    this.modelName,
  });

  factory SessionSummary.fromJson(Map<String, Object?> json) {
    final characterBinding = readMap(json['character_binding']);
    final characterSummary = readMap(characterBinding['snapshot_summary']);
    final userBinding = readMap(json['user_binding']);
    final userSummary = readMap(userBinding['snapshot_summary']);
    return SessionSummary(
      id: readString(json['id']),
      title: readString(json['title']),
      status: readString(json['status'], 'active'),
      characterId: readNullableString(characterBinding['character_id']),
      characterName: readNullableString(characterSummary['name']),
      playerName: readNullableString(userSummary['name']),
      presetId: readNullableString(json['preset_id']),
      regexProfileId: readNullableString(json['regex_profile_id']),
      worldbookProfileId: readNullableString(json['worldbook_profile_id']),
      promptMode: readNullableString(json['prompt_mode']),
      modelName: readNullableString(json['model_name']),
      createdAt: readInt(json['created_at']),
      updatedAt: readInt(json['updated_at']),
    );
  }

  final String id;
  final String title;
  final String status;
  final String? characterId;
  final String? characterName;
  final String? playerName;
  final String? presetId;
  final String? regexProfileId;
  final String? worldbookProfileId;
  final String? promptMode;
  final String? modelName;
  final int createdAt;
  final int updatedAt;

  String get displayTitle {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final character = characterName?.trim();
    return character == null || character.isEmpty ? '未命名故事' : character;
  }

  String get displayCharacter {
    final character = characterName?.trim();
    return character == null || character.isEmpty ? '未知角色' : character;
  }

  bool get isArchived => status == 'archived';

  SessionSummary copyWith({String? title, String? status}) {
    return SessionSummary(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      characterId: characterId,
      characterName: characterName,
      playerName: playerName,
      presetId: presetId,
      regexProfileId: regexProfileId,
      worldbookProfileId: worldbookProfileId,
      promptMode: promptMode,
      modelName: modelName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class SessionTimeline {
  const SessionTimeline({
    required this.sessionId,
    required this.branchId,
    required this.floors,
    required this.total,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  factory SessionTimeline.fromJson(Map<String, Object?> json) {
    final data = readMap(json['data']);
    final meta = readMap(json['meta']);
    final floors = readObjectList(data['floors'])
        .map(TimelineFloor.fromJson)
        .toList(growable: false);
    return SessionTimeline(
      sessionId: readString(data['session_id']),
      branchId: readString(data['branch_id'], 'main'),
      floors: floors,
      total: readInt(meta['total'], floors.length),
      offset: readInt(meta['offset']),
      limit: readInt(meta['limit'], floors.length),
      hasMore: readBool(meta['has_more']),
    );
  }

  final String sessionId;
  final String branchId;
  final List<TimelineFloor> floors;
  final int total;
  final int offset;
  final int limit;
  final bool hasMore;
}

class TimelineFloor {
  const TimelineFloor({
    required this.id,
    required this.floorNo,
    required this.state,
    required this.createdAt,
    required this.pages,
    required this.activePages,
  });

  factory TimelineFloor.fromJson(Map<String, Object?> json) {
    final activePages = readObjectList(json['active_pages']);
    final pages = activePages.isNotEmpty
        ? activePages
        : _fallbackPages(json);
    return TimelineFloor(
      id: readString(json['id']),
      floorNo: readInt(json['floor_no']),
      state: readString(json['state']),
      createdAt: readInt(json['created_at']),
      pages: pages.map(TimelinePage.fromJson).toList(growable: false),
      activePages: pages.map(TimelinePage.fromJson).toList(growable: false),
    );
  }

  static List<Map<String, Object?>> _fallbackPages(
    Map<String, Object?> json,
  ) {
    final activePage = readMap(json['active_page']);
    if (activePage.isNotEmpty) {
      return [activePage];
    }
    return readObjectList(json['pages'])
        .where((page) => readBool(page['is_active']))
        .toList(growable: false);
  }

  final String id;
  final int floorNo;
  final String state;
  final int createdAt;
  final List<TimelinePage> pages;
  final List<TimelinePage> activePages;
}

class TimelinePage {
  const TimelinePage({
    required this.id,
    required this.pageNo,
    required this.kind,
    required this.isActive,
    required this.version,
    required this.messages,
  });

  factory TimelinePage.fromJson(Map<String, Object?> json) {
    return TimelinePage(
      id: readString(json['id']),
      pageNo: readInt(json['page_no']),
      kind: readString(json['page_kind']),
      isActive: readBool(json['is_active'], true),
      version: readInt(json['version'], 1),
      messages: readObjectList(json['messages'])
          .map(TimelineMessage.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final int pageNo;
  final String kind;
  final bool isActive;
  final int version;
  final List<TimelineMessage> messages;
}

class TimelineMessage {
  const TimelineMessage({
    required this.id,
    required this.seq,
    required this.role,
    required this.content,
    required this.contentFormat,
  });

  factory TimelineMessage.fromJson(Map<String, Object?> json) {
    return TimelineMessage(
      id: readString(json['id']),
      seq: readInt(json['seq']),
      role: readString(json['role']),
      content: readString(json['content']),
      contentFormat: readString(json['content_format'], 'text'),
    );
  }

  final String id;
  final int seq;
  final String role;
  final String content;
  final String contentFormat;
}

class ActiveRun {
  const ActiveRun({
    required this.busy,
    required this.branchId,
    required this.updatedAt,
    this.phase,
    this.runId,
    this.runType,
  });

  factory ActiveRun.fromJson(Map<String, Object?> json) {
    return ActiveRun(
      busy: readBool(json['busy']),
      branchId: readString(json['branch_id'], 'main'),
      phase: readNullableString(json['public_phase']),
      runId: readNullableString(json['active_run_id']),
      runType: readNullableString(json['active_run_type']),
      updatedAt: readInt(json['updated_at']),
    );
  }

  const ActiveRun.idle()
    : busy = false,
      branchId = 'main',
      phase = null,
      runId = null,
      runType = null,
      updatedAt = 0;

  final bool busy;
  final String branchId;
  final String? phase;
  final String? runId;
  final String? runType;
  final int updatedAt;

  String get phaseLabel => describeRunPhase(phase) ?? '服务器仍在生成';
}

String? describeRunPhase(String? phase) {
  return switch (phase) {
    'preparing' => '正在整理上下文',
    'generating' => '正在续写',
    'verifying' => '正在核对内容',
    'committing' => '正在保存回合',
    'post_processing' => '正在收尾',
    'failed' => '生成失败',
    null || '' => null,
    _ => '服务器仍在生成',
  };
}

class RespondResult {
  const RespondResult({
    required this.floorId,
    required this.floorNo,
    required this.generatedText,
    required this.finalState,
    this.branchId,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  final String floorId;
  final int floorNo;
  final String generatedText;
  final String finalState;
  final String? branchId;
  final int inputTokens;
  final int outputTokens;
}

class DryRunDiagnostics {
  const DryRunDiagnostics({
    required this.tokenEstimate,
    required this.availableForReply,
    required this.assemblyMode,
    required this.warnings,
    this.presetUsed = false,
    this.worldbookHits = 0,
  });

  factory DryRunDiagnostics.fromJson(Map<String, Object?> json) {
    final assembly = readMap(json['assembly']);
    final warnings = <String>[
      ...readStringList(assembly['preset_warnings']),
      ...readStringList(assembly['unsupported_preset_fields']).map(
        (item) => '未支持的预设字段：$item',
      ),
    ];
    return DryRunDiagnostics(
      tokenEstimate: readInt(json['token_estimate']),
      availableForReply: readInt(json['available_for_reply']),
      assemblyMode: readString(assembly['mode'], 'unknown'),
      presetUsed: readBool(assembly['preset_used']),
      worldbookHits: readInt(assembly['worldbook_hits']),
      warnings: warnings,
    );
  }

  final int tokenEstimate;
  final int availableForReply;
  final String assemblyMode;
  final bool presetUsed;
  final int worldbookHits;
  final List<String> warnings;
}
