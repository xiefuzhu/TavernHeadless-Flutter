import '../../core/config/generation_defaults.dart';
import '../../core/network/api_error.dart';
import '../../core/network/sse_decoder.dart';
import '../../core/network/tavern_api_client.dart';
import '../models/json_utils.dart';
import '../models/session_models.dart';

class ChatRepository {
  ChatRepository(this._api);

  final TavernApiClient _api;

  Map<String, Object?> _turnConfig() => const {
    'enableDirector': false,
    'enableVerifier': false,
    'enableMemoryConsolidation': false,
  };

  Future<SseDone> respondStream({
    required String sessionId,
    required String message,
    String branchId = 'main',
    int maxOutputTokens = GenerationDefaults.maxOutputTokens,
    void Function()? onStart,
    void Function(String chunk)? onChunk,
    void Function(String phase)? onPhase,
    void Function(String warning)? onWarning,
    void Function(void Function() cancel)? onAttach,
  }) async {
    final connection = await _api.openSse(
      '/sessions/$sessionId/respond/stream',
      body: {
        'message': message,
        'config': _turnConfig(),
        'generation_params': {'max_output_tokens': maxOutputTokens},
        'branch_id': branchId,
      },
    );
    onAttach?.call(connection.cancel);
    try {
      return await SseDecoder.read(
        connection,
        onStart: onStart,
        onChunk: onChunk,
        onPhase: onPhase,
        onWarning: onWarning,
      );
    } finally {
      connection.cancel();
    }
  }

  Future<RespondResult> regenerate({
    required String sessionId,
    int maxOutputTokens = GenerationDefaults.maxOutputTokens,
  }) async {
    final json = await _api.postJson(
      '/sessions/$sessionId/regenerate',
      body: {
        'config': _turnConfig(),
        'generation_params': {'max_output_tokens': maxOutputTokens},
      },
      timeout: const Duration(minutes: 10),
    );
    final data = readMap(json['data']);
    final floorId = readNullableString(data['floor_id']);
    if (floorId == null) {
      throw const ApiError(message: '重新生成没有返回新的楼层');
    }
    final usage = readMap(data['total_usage']);
    return RespondResult(
      floorId: floorId,
      floorNo: readInt(data['floor_no']),
      generatedText: readString(data['generated_text']),
      finalState: readString(data['final_state'], 'committed'),
      branchId: readNullableString(data['branch_id']),
      inputTokens: readInt(usage['input_tokens']),
      outputTokens: readInt(usage['output_tokens']),
    );
  }

  Future<DryRunDiagnostics> dryRun({
    required String sessionId,
    required String message,
    int maxOutputTokens = GenerationDefaults.maxOutputTokens,
    String branchId = 'main',
  }) async {
    final json = await _api.postJson(
      '/sessions/$sessionId/respond/dry-run',
      body: {
        'message': message,
        'budget': {
          'max_input_tokens': GenerationDefaults.inputBudget,
          'reserved_completion_tokens': maxOutputTokens,
        },
      },
      timeout: const Duration(seconds: 60),
    );
    return DryRunDiagnostics.fromJson(readMap(json['data']));
  }
}
