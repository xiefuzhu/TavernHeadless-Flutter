import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 规范化实例地址：去掉尾部斜杠、统一小写主机部分。
String normalizeEndpoint(String raw) {
  var value = raw.trim();
  if (value.isEmpty) {
    return value;
  }
  if (!value.contains('://')) {
    value = 'https://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }
  final path = uri.path == '/' ? '' : uri.path.replaceAll(RegExp(r'/+$'), '');
  final rebuilt = uri.replace(path: path, fragment: null, query: null);
  return rebuilt.toString();
}

/// 连接标识：同一实例 + 同一玩家名视为同一账号范围，用于隔离草稿与缓存。
/// 只包含地址和名字的摘要，不包含访问密钥。
String connectionIdFor(String endpoint, String playerName) {
  final normalized = normalizeEndpoint(endpoint).toLowerCase();
  final digest = sha256.convert(
    utf8.encode('$normalized|${playerName.trim()}'),
  );
  return digest.toString().substring(0, 16);
}

/// 展示用主机名，不带路径与凭证。
String endpointLabel(String endpoint) {
  final uri = Uri.tryParse(normalizeEndpoint(endpoint));
  if (uri == null || uri.host.isEmpty) {
    return endpoint;
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.host}$port';
}
