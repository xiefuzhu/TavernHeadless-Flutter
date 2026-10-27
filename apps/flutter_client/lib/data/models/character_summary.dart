import 'json_utils.dart';

class CharacterSummary {
  const CharacterSummary({
    required this.id,
    required this.name,
    required this.source,
    required this.updatedAt,
    this.latestVersionNo,
  });

  factory CharacterSummary.fromJson(Map<String, Object?> json) {
    return CharacterSummary(
      id: readString(json['id']),
      name: readString(json['name'], '未命名角色'),
      source: readString(json['source']),
      latestVersionNo: readNullableInt(json['latest_version_no']),
      updatedAt: readInt(json['updated_at']),
    );
  }

  final String id;
  final String name;
  final String source;
  final int? latestVersionNo;
  final int updatedAt;

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '·' : String.fromCharCode(trimmed.runes.first);
  }
}
