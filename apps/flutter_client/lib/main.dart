import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/credential_store.dart';
import 'core/storage/draft_store.dart';
import 'core/storage/settings_store.dart';
import 'viewmodels/chat_view_model.dart';
import 'viewmodels/connection_view_model.dart';
import 'viewmodels/session_list_view_model.dart';
import 'viewmodels/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsStore = SettingsStore();
  final stored = await _loadSettings(settingsStore);
  final settings = SettingsController(store: settingsStore, initial: stored);
  final drafts = DraftStore();
  final connection = ConnectionViewModel(
    settings: settings,
    credentials: CredentialStore(),
    drafts: drafts,
  );
  final sessions = SessionListViewModel(
    connection: connection,
    settings: settings,
  );
  final chat = ChatViewModel(
    connection: connection,
    settings: settings,
    drafts: drafts,
  );

  runApp(
    TavernApp(
      settings: settings,
      connection: connection,
      sessions: sessions,
      chat: chat,
    ),
  );
}

/// 偏好读取失败时退回默认值，不让启动被本机存储阻塞。
Future<StoredSettings> _loadSettings(SettingsStore store) async {
  try {
    return await store.load();
  } on Object {
    return const StoredSettings();
  }
}
