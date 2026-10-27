import '../../core/network/tavern_api_client.dart';
import '../models/asset_item.dart';
import '../models/character_summary.dart';
import '../models/json_utils.dart';

class CatalogRepository {
  CatalogRepository(this._api);

  final TavernApiClient _api;

  Future<List<CharacterSummary>> fetchCharacters({String? keyword}) async {
    final json = await _api.getJson(
      '/characters',
      query: {
        'limit': 100,
        'offset': 0,
        'sort_by': 'updated_at',
        'sort_order': 'desc',
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    return readObjectList(json['data'])
        .map(CharacterSummary.fromJson)
        .where((character) => character.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<AssetBundle> fetchAssets() async {
    final responses = await Future.wait([
      _api.getJson('/presets'),
      _api.getJson('/worldbooks'),
      _api.getJson('/regex-profiles'),
    ]);
    return AssetBundle(
      presets: _mapItems(responses[0], AssetKind.preset),
      worldbooks: _mapItems(responses[1], AssetKind.worldbook),
      regexProfiles: _mapItems(responses[2], AssetKind.regex),
    );
  }

  List<AssetItem> _mapItems(Map<String, Object?> json, AssetKind kind) {
    return readObjectList(json['data'])
        .map((item) => AssetItem.fromJson(item, kind: kind))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }
}
