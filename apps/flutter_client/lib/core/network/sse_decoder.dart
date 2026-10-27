import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/json_utils.dart';
import 'api_error.dart';
import 'tavern_api_client.dart';

class SseDone {
  const SseDone({
    required this.floorId,
    required this.floorNo,
    required this.generatedText,
    required this.finalState,
    required this.summaries,
    this.branchId,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  final String floorId;
  final int floorNo;
  final String generatedText;
  final String finalState;
  final List<String> summaries;
  final String? branchId;
  final int inputTokens;
  final int outputTokens;
}

class SseDecoder {
  const SseDecoder._();

  static Future<SseDone> read(
    SseConnection connection, {
    void Function()? onStart,
    void Function(String chunk)? onChunk,
    void Function(String phase)? onPhase,
    void Function(String warning)? onWarning,
  }) async {
    var eventName = 'message';
    final dataLines = <String>[];
    var buffer = '';
    SseDone? done;
    final collectedSummaries = <String>[];
    String? branchId;

    void flush() {
      if (dataLines.isEmpty) {
        eventName = 'message';
        return;
      }
      final raw = dataLines.join('\n');
      dataLines.clear();
      final currentEvent = eventName;
      eventName = 'message';
      final payload = _parseMap(raw);
      if (payload == null) {
        return;
      }

      switch (currentEvent) {
        case 'start':
          branchId = readNullableString(payload['branch_id']) ?? branchId;
          onStart?.call();
        case 'chunk':
          final chunk = readString(payload['chunk']);
          if (chunk.isNotEmpty) {
            onChunk?.call(chunk);
          }
        case 'run':
          final phase = readNullableString(payload['public_phase']);
          if (phase != null) {
            onPhase?.call(phase);
          }
        case 'summary':
          collectedSummaries.addAll(readStringList(payload['summaries']));
        case 'tool':
          final replaySafety = readString(payload['replay_safety']);
          if (replaySafety.isNotEmpty && replaySafety != 'safe') {
            final toolName = readString(payload['tool_name'], '工具');
            onWarning?.call('$toolName 的执行结果需要在重放前确认。');
          }
        case 'error':
          throw ApiError(
            code: readNullableString(payload['code']),
            message: readString(payload['message'], '生成失败'),
          );
        case 'done':
          final floorId = readNullableString(payload['floor_id']);
          final floorNo = readNullableInt(payload['floor_no']);
          if (floorId != null && floorNo != null) {
            final usage = readMap(payload['total_usage']);
            done = SseDone(
              branchId:
                  readNullableString(payload['branch_id']) ?? branchId,
              finalState: readString(payload['final_state'], 'committed'),
              floorId: floorId,
              floorNo: floorNo,
              generatedText: readString(payload['generated_text']),
              inputTokens: readInt(usage['input_tokens']),
              outputTokens: readInt(usage['output_tokens']),
              summaries: readStringList(payload['summaries']).isEmpty
                  ? List.unmodifiable(collectedSummaries)
                  : readStringList(payload['summaries']),
            );
          }
      }
    }

    Future<void> processLine(String rawLine) async {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      if (line.isEmpty) {
        flush();
        return;
      }
      if (line.startsWith(':')) {
        return;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
        return;
      }
      if (line.startsWith('data:')) {
        final value = line.substring('data:'.length);
        dataLines.add(value.startsWith(' ') ? value.substring(1) : value);
      }
    }

    try {
      await for (final chunk in utf8.decoder.bind(connection.response.stream)) {
        buffer += chunk;
        while (true) {
          final newline = buffer.indexOf('\n');
          if (newline < 0) {
            break;
          }
          final line = buffer.substring(0, newline);
          buffer = buffer.substring(newline + 1);
          await processLine(line);
        }
      }
      if (buffer.trim().isNotEmpty) {
        await processLine(buffer);
      }
      flush();
    } on ApiError {
      rethrow;
    } on http.RequestAbortedException {
      // 本地取消：调用方需要区分“用户停止”与真正的网络错误。
      rethrow;
    } on Object catch (error) {
      throw ApiError(message: '读取生成流失败：$error');
    }

    final result = done;
    if (result == null) {
      throw const ApiError(message: '生成流提前结束，未收到完成结果');
    }
    return result;
  }

  static Map<String, Object?>? _parseMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
