import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 访问凭证只写入平台安全存储，不进入 shared_preferences、日志或 WebView。
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'tavern_credentials'),
          );

  final FlutterSecureStorage _storage;

  static String _keyFor(String connectionId) => 'tavern.apiKey.$connectionId';

  Future<String?> read(String connectionId) async {
    if (connectionId.isEmpty) {
      return null;
    }
    try {
      return await _storage.read(key: _keyFor(connectionId));
    } on Object {
      return null;
    }
  }

  Future<void> write(String connectionId, String apiKey) async {
    if (connectionId.isEmpty) {
      return;
    }
    await _storage.write(key: _keyFor(connectionId), value: apiKey);
  }

  Future<void> delete(String connectionId) async {
    if (connectionId.isEmpty) {
      return;
    }
    try {
      await _storage.delete(key: _keyFor(connectionId));
    } on Object {
      // 删除失败不应阻塞退出流程。
    }
  }
}
