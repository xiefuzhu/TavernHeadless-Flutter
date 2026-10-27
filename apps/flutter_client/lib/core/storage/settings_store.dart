import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 非敏感偏好。聊天事实与唯一草稿不放在这里。
class StoredSettings {
  const StoredSettings({
    this.endpoint = 'http://127.0.0.1:3000',
    this.playerName = '旅人',
    this.rememberConnection = false,
    this.directSend = true,
    this.themeMode = ThemeMode.system,
    this.dynamicColor = true,
    this.lastSessionId,
  });

  final String endpoint;
  final String playerName;
  final bool rememberConnection;
  final bool directSend;
  final ThemeMode themeMode;
  final bool dynamicColor;
  final String? lastSessionId;

  StoredSettings copyWith({
    String? endpoint,
    String? playerName,
    bool? rememberConnection,
    bool? directSend,
    ThemeMode? themeMode,
    bool? dynamicColor,
    String? lastSessionId,
    bool clearLastSession = false,
  }) {
    return StoredSettings(
      endpoint: endpoint ?? this.endpoint,
      playerName: playerName ?? this.playerName,
      rememberConnection: rememberConnection ?? this.rememberConnection,
      directSend: directSend ?? this.directSend,
      themeMode: themeMode ?? this.themeMode,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      lastSessionId: clearLastSession ? null : lastSessionId ?? this.lastSessionId,
    );
  }
}

class SettingsStore {
  SettingsStore({SharedPreferencesAsync? preferences})
    : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _endpointKey = 'connection.endpoint';
  static const _playerKey = 'connection.player';
  static const _rememberKey = 'connection.remember';
  static const _directSendKey = 'ui.directSend';
  static const _themeModeKey = 'ui.themeMode';
  static const _dynamicColorKey = 'ui.dynamicColor';
  static const _lastSessionKey = 'session.lastId';

  Future<StoredSettings> load() async {
    final endpoint = await _prefs.getString(_endpointKey);
    final player = await _prefs.getString(_playerKey);
    final remember = await _prefs.getBool(_rememberKey);
    final direct = await _prefs.getBool(_directSendKey);
    final theme = await _prefs.getString(_themeModeKey);
    final dynamicColor = await _prefs.getBool(_dynamicColorKey);
    final lastSession = await _prefs.getString(_lastSessionKey);
    return StoredSettings(
      endpoint: endpoint ?? 'http://127.0.0.1:3000',
      playerName: player ?? '旅人',
      rememberConnection: remember ?? false,
      directSend: direct ?? true,
      themeMode: _decodeThemeMode(theme),
      dynamicColor: dynamicColor ?? true,
      lastSessionId: lastSession,
    );
  }

  Future<void> saveEndpoint(String endpoint) => _prefs.setString(_endpointKey, endpoint);

  Future<void> savePlayerName(String name) => _prefs.setString(_playerKey, name);

  Future<void> saveRemember(bool remember) => _prefs.setBool(_rememberKey, remember);

  Future<void> saveDirectSend(bool direct) => _prefs.setBool(_directSendKey, direct);

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, _encodeThemeMode(mode));

  Future<void> saveDynamicColor(bool enabled) =>
      _prefs.setBool(_dynamicColorKey, enabled);

  Future<void> saveLastSession(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) {
      await _prefs.remove(_lastSessionKey);
      return;
    }
    await _prefs.setString(_lastSessionKey, sessionId);
  }

  static ThemeMode _decodeThemeMode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _encodeThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
