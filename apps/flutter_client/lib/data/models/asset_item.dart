import 'json_utils.dart';

enum AssetKind {
  preset('预设'),
  worldbook('世界书'),
  regex('显示正则');

  const AssetKind(this.label);

  final String label;
}

class AssetItem {
  const AssetItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.updatedAt,
    this.version = 0,
    this.source = '',
  });

  factory AssetItem.fromJson(
    Map<String, Object?> json, {
    required AssetKind kind,
  }) {
    return AssetItem(
      id: readString(json['id']),
      name: readString(json['name'], '未命名${kind.label}'),
      kind: kind,
      source: readString(json['source']),
      version: readInt(json['version']),
      updatedAt: readInt(json['updated_at']),
    );
  }

  final String id;
  final String name;
  final AssetKind kind;
  final String source;
  final int version;
  final int updatedAt;
}

class AssetSelection {
  const AssetSelection({
    this.presetId,
    this.worldbookId,
    this.regexId,
  });

  factory AssetSelection.fromJson(Map<String, Object?> json) {
    return AssetSelection(
      presetId: readNullableString(json['presetId']),
      worldbookId: readNullableString(json['worldbookId']),
      regexId: readNullableString(json['regexId']),
    );
  }

  final String? presetId;
  final String? worldbookId;
  final String? regexId;

  bool get isEmpty => presetId == null && worldbookId == null && regexId == null;

  Map<String, Object?> toJson() => {
    'presetId': presetId,
    'worldbookId': worldbookId,
    'regexId': regexId,
  };

  AssetSelection copyWith({
    String? presetId,
    String? worldbookId,
    String? regexId,
    bool clearPreset = false,
    bool clearWorldbook = false,
    bool clearRegex = false,
  }) {
    return AssetSelection(
      presetId: clearPreset ? null : presetId ?? this.presetId,
      worldbookId: clearWorldbook ? null : worldbookId ?? this.worldbookId,
      regexId: clearRegex ? null : regexId ?? this.regexId,
    );
  }
}

class AssetBundle {
  const AssetBundle({
    required this.presets,
    required this.worldbooks,
    required this.regexProfiles,
  });

  const AssetBundle.empty()
    : presets = const [],
      worldbooks = const [],
      regexProfiles = const [];

  final List<AssetItem> presets;
  final List<AssetItem> worldbooks;
  final List<AssetItem> regexProfiles;

  AssetItem? presetById(String? id) => _find(presets, id);

  AssetItem? worldbookById(String? id) => _find(worldbooks, id);

  AssetItem? regexById(String? id) => _find(regexProfiles, id);

  static AssetItem? _find(List<AssetItem> items, String? id) {
    if (id == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}
