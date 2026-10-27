class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.statusCode,
    this.code,
    this.requestId,
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? requestId;
  final Object? details;

  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;
  bool get isNetworkError => statusCode == null;

  String get userMessage {
    if (isAuthError) {
      return '认证失败，请检查访问密钥或重新连接。';
    }
    if (isNetworkError) {
      return '无法连接实例：$message';
    }
    if (isConflict) {
      return '服务器状态已变化：$message';
    }
    if (isNotFound) {
      return '请求的内容不存在或已被移除。';
    }
    return message;
  }

  @override
  String toString() => message;
}
