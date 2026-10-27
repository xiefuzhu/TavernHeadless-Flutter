import 'package:flutter/foundation.dart';

import '../core/config/connection_identity.dart';
import '../core/network/api_error.dart';
import '../core/network/tavern_api_client.dart';
import '../core/storage/credential_store.dart';
import '../core/storage/draft_store.dart';
import '../data/models/asset_item.dart';
import '../data/models/character_summary.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/session_repository.dart';
import 'settings_controller.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class ConnectionViewModel extends ChangeNotifier {
  ConnectionViewModel({
    required this._settings,
    required this._credentials,
    required this._drafts,
  }) {
    final stored = _settings.value;
    _endpoint = stored.endpoint;
    _playerName = stored.playerName;
    _remember = stored.rememberConnection;
  }

  final SettingsController _settings;
  final CredentialStore _credentials;
  final DraftStore _drafts;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  TavernApiClient? _client;
  CatalogRepository? _catalog;
  SessionRepository? _sessions;
  ChatRepository? _chat;
  String? _connectionId;
  String? _error;
  String? _notice;
  String _endpoint = '';
  String _playerName = '旅人';
  bool _remember = false;
  bool _bootstrapped = false;
  List<CharacterSummary> _characters = const [];
  AssetBundle _assets = const AssetBundle.empty();

  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isConnecting => _status == ConnectionStatus.connecting;
  bool get isBusy => _status == ConnectionStatus.connecting;
  String get endpoint => _endpoint;
  String get playerName => _playerName;
  bool get remember => _remember;
  String? get error => _error;
  String? get notice => _notice;
  String? get connectionId => _connectionId;
  bool get bootstrapped => _bootstrapped;
  List<CharacterSummary> get characters => _characters;
  AssetBundle get assets => _assets;
  CatalogRepository? get catalog => _catalog;
  SessionRepository? get sessions => _sessions;
  ChatRepository? get chat => _chat;
  TavernApiClient? get client => _client;

  /// 启动时静默恢复已保存的连接；没有保存凭证时不做任何事。
  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;
    if (!_remember) {
      return;
    }
    final id = connectionIdFor(_endpoint, _playerName);
    final key = await _credentials.read(id);
    if (key == null || key.isEmpty) {
      return;
    }
    await connect(
      endpoint: _endpoint,
      apiKey: key,
      playerName: _playerName,
      remember: true,
      silent: true,
    );
  }

  Future<bool> connect({
    required String endpoint,
    required String apiKey,
    required String playerName,
    required bool remember,
    bool silent = false,
  }) async {
    if (_status == ConnectionStatus.connecting) {
      return false;
    }
    final normalized = normalizeEndpoint(endpoint);
    final validation = _validate(normalized, apiKey);
    if (validation != null) {
      _status = ConnectionStatus.disconnected;
      _error = validation;
      notifyListeners();
      return false;
    }

    _status = ConnectionStatus.connecting;
    _error = null;
    _notice = null;
    _endpoint = normalized;
    _playerName = playerName.trim().isEmpty ? '旅人' : playerName.trim();
    _remember = remember;
    notifyListeners();

    final client = TavernApiClient(
      baseUri: Uri.parse(normalized),
      apiKey: apiKey.trim(),
    );
    try {
      final catalog = CatalogRepository(client);
      final characters = await catalog.fetchCharacters();
      final assets = await catalog.fetchAssets();
      final sessions = SessionRepository(client);
      final chat = ChatRepository(client);

      _client?.close();
      _client = client;
      _catalog = catalog;
      _sessions = sessions;
      _chat = chat;
      _characters = characters;
      _assets = assets;
      _connectionId = connectionIdFor(normalized, _playerName);
      _status = ConnectionStatus.connected;
      _error = null;
      _notice = null;

      await _settings.setEndpoint(normalized);
      await _settings.setPlayerName(_playerName);
      await _settings.setRememberConnection(remember);
      if (remember) {
        await _credentials.write(_connectionId!, apiKey.trim());
      } else {
        await _credentials.delete(_connectionId!);
      }
      notifyListeners();
      return true;
    } on ApiError catch (error) {
      client.close();
      _status = ConnectionStatus.disconnected;
      _error = _connectionFailureMessage(error);
      if (!silent) {
        _notice = null;
      }
      notifyListeners();
      return false;
    } on Object catch (error) {
      client.close();
      _status = ConnectionStatus.disconnected;
      _error = '无法连接实例：$error';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCatalog() async {
    final catalog = _catalog;
    if (catalog == null) {
      return;
    }
    try {
      final results = await Future.wait([
        catalog.fetchCharacters(),
        catalog.fetchAssets(),
      ]);
      _characters = results[0] as List<CharacterSummary>;
      _assets = results[1] as AssetBundle;
      _error = null;
      notifyListeners();
    } on ApiError catch (error) {
      _error = error.userMessage;
      notifyListeners();
    }
  }

  Future<void> disconnect({
    bool clearCredential = false,
    bool clearDrafts = false,
  }) async {
    final id = _connectionId;
    _client?.close();
    _client = null;
    _catalog = null;
    _sessions = null;
    _chat = null;
    _connectionId = null;
    _characters = const [];
    _assets = const AssetBundle.empty();
    _status = ConnectionStatus.disconnected;
    _error = null;
    _notice = null;
    _bootstrapped = false;
    if (id != null && clearCredential) {
      await _credentials.delete(id);
    }
    if (id != null && clearDrafts) {
      await _drafts.clearConnection(id);
    }
    await _settings.setLastSession(null);
    notifyListeners();
  }

  /// 只清除本机保存的访问密钥，不影响当前运行中的连接。
  Future<void> forgetCredential() async {
    final id = _connectionId;
    if (id == null) {
      return;
    }
    await _credentials.delete(id);
    await _settings.setRememberConnection(false);
    _remember = false;
    _notice = '已移除本机保存的访问密钥，本次运行仍保持连接。';
    notifyListeners();
  }

  /// 清理当前连接范围内的本机草稿，返回删除的文件数。
  Future<int> clearDrafts() async {
    final id = _connectionId;
    if (id == null) {
      return 0;
    }
    return _drafts.clearConnection(id);
  }

  void updateIdentity({String? endpoint, String? playerName, bool? remember}) {
    if (endpoint != null) {
      _endpoint = endpoint;
    }
    if (playerName != null) {
      _playerName = playerName;
    }
    if (remember != null) {
      _remember = remember;
    }
    notifyListeners();
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  void setNotice(String? notice) {
    if (_notice == notice) {
      return;
    }
    _notice = notice;
    notifyListeners();
  }

  String? _validate(String endpoint, String apiKey) {
    if (apiKey.trim().isEmpty) {
      return '请填写访问密钥；模型密钥只保存在服务器上。';
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.host.isEmpty) {
      return '请输入完整实例地址，例如 https://tavern.example/api';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '实例地址必须以 http:// 或 https:// 开头';
    }
    return null;
  }

  String _connectionFailureMessage(ApiError error) {
    if (error.isAuthError) {
      return '认证失败：访问密钥与服务端不匹配。请检查密钥或实例地址。';
    }
    if (error.isNetworkError) {
      return '无法连接实例：${error.message}。真机调试时 127.0.0.1 指向手机自身，请填写电脑的局域网地址。';
    }
    return error.userMessage;
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
