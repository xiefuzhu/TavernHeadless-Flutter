import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/asset_item.dart';
import '../data/models/session_models.dart';
import 'connection_view_model.dart';
import 'settings_controller.dart';

enum SessionFilter {
  active('进行中'),
  archived('已归档');

  const SessionFilter(this.label);

  final String label;

  String get status => this == SessionFilter.active ? 'active' : 'archived';
}

class SessionListViewModel extends ChangeNotifier {
  SessionListViewModel({
    required this._connection,
    required this._settings,
  }) {
    _connection.addListener(_handleConnectionChange);
    _lastConnectionId = _connection.connectionId;
  }

  final ConnectionViewModel _connection;
  final SettingsController _settings;

  List<SessionSummary> _sessions = const [];
  SessionFilter _filter = SessionFilter.active;
  String _keyword = '';
  bool _loading = false;
  bool _creating = false;
  bool _mutating = false;
  String? _error;
  String? _lastConnectionId;
  int _epoch = 0;

  List<SessionSummary> get sessions => _sessions;
  SessionFilter get filter => _filter;
  String get keyword => _keyword;
  bool get loading => _loading;
  bool get creating => _creating;
  bool get mutating => _mutating;
  String? get error => _error;
  bool get hasSessions => _sessions.isNotEmpty;

  List<SessionSummary> get visibleSessions {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _sessions;
    }
    return _sessions
        .where(
          (session) =>
              session.displayTitle.toLowerCase().contains(keyword) ||
              session.displayCharacter.toLowerCase().contains(keyword),
        )
        .toList(growable: false);
  }

  SessionSummary? get lastSession {
    final id = _settings.value.lastSessionId;
    if (id == null) {
      return null;
    }
    for (final session in _sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  void _handleConnectionChange() {
    final id = _connection.connectionId;
    if (id == _lastConnectionId) {
      return;
    }
    _lastConnectionId = id;
    _epoch++;
    _sessions = const [];
    _error = null;
    _keyword = '';
    _loading = false;
    _creating = false;
    _mutating = false;
    notifyListeners();
    if (id != null && _connection.isConnected) {
      load();
    }
  }

  Future<void> load({bool silent = false}) async {
    final repository = _connection.sessions;
    if (repository == null) {
      return;
    }
    final epoch = ++_epoch;
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final sessions = await repository.fetchSessions(status: _filter.status);
      if (epoch != _epoch) {
        return;
      }
      _sessions = sessions;
      _error = null;
    } on ApiError catch (error) {
      if (epoch != _epoch) {
        return;
      }
      _error = error.userMessage;
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setFilter(SessionFilter filter) async {
    if (_filter == filter) {
      return;
    }
    _filter = filter;
    _sessions = const [];
    notifyListeners();
    await load();
  }

  void setKeyword(String keyword) {
    if (_keyword == keyword) {
      return;
    }
    _keyword = keyword;
    notifyListeners();
  }

  Future<SessionSummary?> createSession({
    required String characterId,
    required String title,
    required AssetSelection assets,
  }) async {
    final repository = _connection.sessions;
    if (repository == null || _creating) {
      return null;
    }
    _creating = true;
    _error = null;
    notifyListeners();
    try {
      final session = await repository.createSession(
        characterId: characterId,
        title: title.trim().isEmpty ? '新的旅程' : title.trim(),
        playerName: _connection.playerName,
        assets: assets,
      );
      if (_filter == SessionFilter.active) {
        _sessions = [
          session,
          ..._sessions.where((item) => item.id != session.id),
        ];
      }
      await _settings.setLastSession(session.id);
      return session;
    } on ApiError catch (error) {
      _error = error.userMessage;
      return null;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  Future<bool> renameSession(SessionSummary session, String title) async {
    final repository = _connection.sessions;
    final trimmed = title.trim();
    if (repository == null || trimmed.isEmpty || _mutating) {
      return false;
    }
    _mutating = true;
    notifyListeners();
    try {
      final updated = await repository.renameSession(session.id, trimmed);
      _replace(updated);
      return true;
    } on ApiError catch (error) {
      _error = error.userMessage;
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<bool> archiveSession(SessionSummary session) async {
    return _changeStatus(session, 'archived');
  }

  Future<bool> restoreSession(SessionSummary session) async {
    return _changeStatus(session, 'active');
  }

  Future<bool> _changeStatus(SessionSummary session, String status) async {
    final repository = _connection.sessions;
    if (repository == null || _mutating) {
      return false;
    }
    _mutating = true;
    notifyListeners();
    try {
      await repository.updateStatus(session.id, status);
      _sessions = _sessions
          .where((item) => item.id != session.id)
          .toList(growable: false);
      return true;
    } on ApiError catch (error) {
      _error = error.userMessage;
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  void _replace(SessionSummary updated) {
    _sessions = _sessions
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
  }

  void rememberSession(String sessionId) {
    _settings.setLastSession(sessionId);
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connection.removeListener(_handleConnectionChange);
    super.dispose();
  }
}
