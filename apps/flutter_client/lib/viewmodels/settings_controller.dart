import 'package:flutter/material.dart';

import '../core/storage/settings_store.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    required this._store,
    required StoredSettings initial,
  }) : _value = initial;

  final SettingsStore _store;
  StoredSettings _value;

  StoredSettings get value => _value;

  ThemeMode get themeMode => _value.themeMode;
  bool get dynamicColor => _value.dynamicColor;
  bool get directSend => _value.directSend;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_value.themeMode == mode) {
      return;
    }
    _value = _value.copyWith(themeMode: mode);
    notifyListeners();
    await _store.saveThemeMode(mode);
  }

  Future<void> setDynamicColor(bool enabled) async {
    if (_value.dynamicColor == enabled) {
      return;
    }
    _value = _value.copyWith(dynamicColor: enabled);
    notifyListeners();
    await _store.saveDynamicColor(enabled);
  }

  Future<void> setDirectSend(bool direct) async {
    if (_value.directSend == direct) {
      return;
    }
    _value = _value.copyWith(directSend: direct);
    notifyListeners();
    await _store.saveDirectSend(direct);
  }

  Future<void> setPlayerName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _value.playerName) {
      return;
    }
    _value = _value.copyWith(playerName: trimmed);
    notifyListeners();
    await _store.savePlayerName(trimmed);
  }

  Future<void> setEndpoint(String endpoint) async {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty || trimmed == _value.endpoint) {
      return;
    }
    _value = _value.copyWith(endpoint: trimmed);
    notifyListeners();
    await _store.saveEndpoint(trimmed);
  }

  Future<void> setRememberConnection(bool remember) async {
    if (_value.rememberConnection == remember) {
      return;
    }
    _value = _value.copyWith(rememberConnection: remember);
    notifyListeners();
    await _store.saveRemember(remember);
  }

  Future<void> setLastSession(String? sessionId) async {
    if (_value.lastSessionId == sessionId) {
      return;
    }
    _value = sessionId == null
        ? _value.copyWith(clearLastSession: true)
        : _value.copyWith(lastSessionId: sessionId);
    notifyListeners();
    await _store.saveLastSession(sessionId);
  }
}
