import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ChatDraft {
  const ChatDraft({
    required this.connectionId,
    required this.sessionId,
    required this.text,
    required this.updatedAt,
    this.version = 1,
  });

  factory ChatDraft.fromJson(Map<String, Object?> json, String fileSessionId) {
    final text = json['text'];
    return ChatDraft(
      connectionId: json['connectionId'] is String
          ? json['connectionId'] as String
          : '',
      sessionId: json['sessionId'] is String
          ? json['sessionId'] as String
          : fileSessionId,
      text: text is String ? text : '',
      updatedAt: json['updatedAt'] is int ? json['updatedAt'] as int : 0,
      version: json['version'] is int ? json['version'] as int : 1,
    );
  }

  final String connectionId;
  final String sessionId;
  final String text;
  final int updatedAt;
  final int version;

  bool get isBlank => text.trim().isEmpty;

  Map<String, Object?> toJson() => {
    'schemaVersion': version,
    'connectionId': connectionId,
    'sessionId': sessionId,
    'text': text,
    'updatedAt': updatedAt,
  };
}

/// 草稿按“连接 + 会话”写入版本化文件；提交成功并核对后才清理。
class DraftStore {
  DraftStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  static const int schemaVersion = 1;

  Future<Directory> _directory(String connectionId) async {
    final base = await _baseDirectory();
    final dir = Directory('${base.path}/drafts/v$schemaVersion/$connectionId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file(String connectionId, String sessionId) async {
    final dir = await _directory(connectionId);
    return File('${dir.path}/$sessionId.json');
  }

  Future<void> save(ChatDraft draft) async {
    if (draft.connectionId.isEmpty || draft.sessionId.isEmpty) {
      return;
    }
    if (draft.isBlank) {
      await delete(draft.connectionId, draft.sessionId);
      return;
    }
    final file = await _file(draft.connectionId, draft.sessionId);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(draft.toJson()), flush: true);
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
    } on FileSystemException {
      // 原子替换失败时退回到直接写入，至少保住内容。
      await file.writeAsString(jsonEncode(draft.toJson()), flush: true);
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  Future<ChatDraft?> read(String connectionId, String sessionId) async {
    if (connectionId.isEmpty || sessionId.isEmpty) {
      return null;
    }
    try {
      final file = await _file(connectionId, sessionId);
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      return ChatDraft.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
        sessionId,
      );
    } on Object {
      return null;
    }
  }

  Future<void> delete(String connectionId, String sessionId) async {
    try {
      final file = await _file(connectionId, sessionId);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // 清理失败不影响主流程。
    }
  }

  /// 退出连接时按连接范围清理草稿，返回删除的文件数。
  Future<int> clearConnection(String connectionId) async {
    if (connectionId.isEmpty) {
      return 0;
    }
    try {
      final dir = await _directory(connectionId);
      if (!await dir.exists()) {
        return 0;
      }
      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
          removed++;
        }
      }
      await dir.delete();
      return removed;
    } on Object {
      return 0;
    }
  }
}
