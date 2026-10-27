import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_error.dart';

class TavernApiClient {
  TavernApiClient({
    required this.baseUri,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final String apiKey;
  final http.Client _http;

  static const Duration _requestTimeout = Duration(seconds: 30);

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  Uri resolve(String path, [Map<String, Object?>? query]) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(
      path: '$basePath$normalizedPath',
      queryParameters: query == null || query.isEmpty
          ? null
          : query.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?>? query,
  }) async {
    final uri = resolve(path, query);
    try {
      final response = await _http
          .get(uri, headers: _headers)
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const ApiError(message: '请求超时');
    } on http.ClientException catch (error) {
      throw ApiError(message: error.message);
    }
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    Object? body,
    Duration timeout = _requestTimeout,
  }) async {
    final uri = resolve(path);
    try {
      final response = await _http
          .post(uri, headers: _headers, body: jsonEncode(body ?? const {}))
          .timeout(timeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const ApiError(message: '请求超时');
    } on http.ClientException catch (error) {
      throw ApiError(message: error.message);
    }
  }

  Future<Map<String, Object?>> patchJson(
    String path, {
    Object? body,
  }) async {
    final uri = resolve(path);
    try {
      final response = await _http
          .patch(uri, headers: _headers, body: jsonEncode(body ?? const {}))
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw const ApiError(message: '请求超时');
    } on http.ClientException catch (error) {
      throw ApiError(message: error.message);
    }
  }

  Future<SseConnection> openSse(
    String path, {
    required Map<String, Object?> body,
  }) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'POST',
      resolve(path),
      abortTrigger: abort.future,
    )
      ..headers.addAll({..._headers, 'Accept': 'text/event-stream'})
      ..body = jsonEncode(body);

    late final http.StreamedResponse response;
    try {
      response = await _http.send(request);
    } on http.ClientException catch (error) {
      throw ApiError(message: error.message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = await _decodeErrorResponse(response);
      if (!abort.isCompleted) {
        abort.complete();
      }
      throw error;
    }

    return SseConnection(
      response: response,
      cancel: () {
        if (!abort.isCompleted) {
          abort.complete();
        }
      },
    );
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _decodeErrorText(response.body, response.statusCode, response);
    }
    if (response.body.trim().isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw ApiError(
        message: '服务器返回了无法识别的数据',
        statusCode: response.statusCode,
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<ApiError> _decodeErrorResponse(http.StreamedResponse response) async {
    try {
      final body = await response.stream.bytesToString();
      return _decodeErrorText(body, response.statusCode, response);
    } on Object {
      return ApiError(
        message: '请求失败（HTTP ${response.statusCode}）',
        statusCode: response.statusCode,
      );
    }
  }

  ApiError _decodeErrorText(
    String body,
    int statusCode,
    http.BaseResponse response,
  ) {
    String? code;
    String message = '请求失败（HTTP $statusCode）';
    Object? details;
    if (body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final error = decoded['error'];
          if (error is Map) {
            code = error['code'] is String ? error['code'] as String : null;
            final rawMessage = error['message'];
            if (rawMessage is String && rawMessage.isNotEmpty) {
              message = rawMessage;
            }
            details = error['details'];
          } else if (decoded['message'] is String) {
            message = decoded['message'] as String;
          }
        }
      } on FormatException {
        // Keep the status-based message for non-JSON error bodies.
      }
    }
    return ApiError(
      code: code,
      details: details,
      message: message,
      requestId: response.headers['x-request-id'],
      statusCode: statusCode,
    );
  }

  void close() => _http.close();
}

class SseConnection {
  const SseConnection({required this.response, required this.cancel});

  final http.StreamedResponse response;
  final void Function() cancel;
}
