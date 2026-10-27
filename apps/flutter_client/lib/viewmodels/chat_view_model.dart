import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/network/api_error.dart';
import '../core/storage/draft_store.dart';
import '../data/models/session_models.dart';
import '../services/message_derivation.dart';
import 'connection_view_model.dart';
import 'settings_controller.dart';

class DisplayMessage {
  const DisplayMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.derived,
    required this.floorId,
    required this.floorNo,
    required this.floorState,
    this.isPending = false,
    this.isStreaming = false,
    this.isUnconfirmed = false,
  });

  factory DisplayMessage.fromTimeline(
    TimelineMessage message, {
    required String floorId,
    required int floorNo,
    required String floorState,
  }) {
    return DisplayMessage(
      id: message.id,
      role: message.role,
      content: message.content,
      derived: deriveMessage(message.content),
      floorId: floorId,
      floorNo: floorNo,
      floorState: floorState,
    );
  }

  factory DisplayMessage.pendingUser(String text) {
    return DisplayMessage(
      id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      content: text,
      derived: deriveMessage(text),
      floorId: '',
      floorNo: 0,
      floorState: 'pending',
      isPending: true,
    );
  }

  factory DisplayMessage.streaming(String text) {
    return DisplayMessage(
      id: 'local-stream',
      role: 'assistant',
      content: text,
      derived: DerivedMessage(markdown: text, options: const []),
      floorId: '',
      floorNo: 0,
      floorState: 'pending',
      isStreaming: true,
    );
  }

  factory DisplayMessage.unconfirmed(String text) {
    return DisplayMessage(
      id: 'local-unconfirmed',
      role: 'assistant',
      content: text,
      derived: DerivedMessage(markdown: text, options: const []),
      floorId: '',
      floorNo: 0,
      floorState: 'unconfirmed',
      isUnconfirmed: true,
    );
  }

  final String id;
  final String role;
  final String content;
  final DerivedMessage derived;
  final String floorId;
  final int floorNo;
  final String floorState;
  final bool isPending;
  final bool isStreaming;
  final bool isUnconfirmed;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isEmptyBody => derived.isEmptyBody;

  DisplayMessage copyWith({String? content, DerivedMessage? derived}) {
    return DisplayMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      derived: derived ?? this.derived,
      floorId: floorId,
      floorNo: floorNo,
      floorState: floorState,
      isPending: isPending,
      isStreaming: isStreaming,
      isUnconfirmed: isUnconfirmed,
    );
  }
}

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required this._connection,
    required this._settings,
    required this._drafts,
  }) {
    _connection.addListener(_handleConnectionChange);
    _lastConnectionId = _connection.connectionId;
  }

  final ConnectionViewModel _connection;
  final SettingsController _settings;
  final DraftStore _drafts;

  SessionSummary? _session;
  List<DisplayMessage> _messages = const [];
  DisplayMessage? _pendingUser;
  DisplayMessage? _streamingMessage;
  String _unconfirmedText = '';
  String _draft = '';
  String _streamText = '';
  final StringBuffer _streamBuffer = StringBuffer();
  final List<String> _warnings = [];

  bool _loading = false;
  bool _loadingEarlier = false;
  bool _busy = false;
  bool _streaming = false;
  bool _recovering = false;
  String? _phase;
  String? _error;
  String? _notice;
  int _loadedOffset = 0;
  int _totalFloors = 0;
  bool _hasEarlier = false;
  int _epoch = 0;
  int _recoveryAttempt = 0;
  int _focusSignal = 0;
  DryRunDiagnostics? _diagnostics;
  bool _diagnosticsLoading = false;

  Timer? _flushTimer;
  Timer? _draftTimer;
  Timer? _recoveryTimer;
  void Function()? _cancelStream;
  bool _disposed = false;
  String? _lastConnectionId;

  SessionSummary? get session => _session;
  bool get loading => _loading;
  bool get loadingEarlier => _loadingEarlier;
  bool get busy => _busy;
  bool get streaming => _streaming;
  bool get recovering => _recovering;
  String? get phase => _phase;
  String? get error => _error;
  String? get notice => _notice;
  String get draft => _draft;
  bool get hasEarlier => _hasEarlier;
  int get totalFloors => _totalFloors;
  int get loadedOffset => _loadedOffset;
  int get focusSignal => _focusSignal;
  DryRunDiagnostics? get diagnostics => _diagnostics;
  bool get diagnosticsLoading => _diagnosticsLoading;
  bool get hasSession => _session != null;

  List<DisplayMessage> get messages {
    final list = List<DisplayMessage>.of(_messages);
    if (_pendingUser != null) {
      list.add(_pendingUser!);
    }
    if (_streamingMessage != null) {
      list.add(_streamingMessage!);
    } else if (_unconfirmedText.isNotEmpty) {
      list.add(DisplayMessage.unconfirmed(_unconfirmedText));
    }
    return list;
  }

  bool get isWriteLocked => _busy || _streaming || _recovering;

  /// 重命名等元信息变更后同步当前会话，避免标题停留在旧值。
  void updateSession(SessionSummary session) {
    if (_session?.id != session.id) {
      return;
    }
    _session = session;
    _notify();
  }

  String? get phaseLabel => describeRunPhase(_phase);

  String? get lastAssistantId {
    for (var index = _messages.length - 1; index >= 0; index--) {
      if (_messages[index].isAssistant) {
        return _messages[index].id;
      }
    }
    return null;
  }

  String? get lastFloorId => _messages.isEmpty ? null : _messages.last.floorId;

  bool get canRegenerate {
    if (_session == null || _loading || isWriteLocked) {
      return false;
    }
    final floorId = lastFloorId;
    if (floorId == null) {
      return false;
    }
    final floorMessages = _messages.where((item) => item.floorId == floorId);
    if (!floorMessages.any((item) => item.isAssistant)) {
      return false;
    }
    return _messages.last.floorState == 'committed';
  }

  /// 只有“最新可操作回复”的选项面板才有发送权限。
  bool canUseOptions(DisplayMessage message) {
    if (message.role != 'assistant' ||
        message.isPending ||
        message.isStreaming) {
      return false;
    }
    if (_session == null || _loading || isWriteLocked) {
      return false;
    }
    if (message.floorState != 'committed') {
      return false;
    }
    return message.id == lastAssistantId && message.floorId == lastFloorId;
  }

  Future<void> open(SessionSummary session) async {
    final repository = _connection.sessions;
    if (repository == null) {
      return;
    }
    final epoch = ++_epoch;
    _cancelTimers();
    _cancelStream?.call();
    _cancelStream = null;
    _session = session;
    _messages = const [];
    _pendingUser = null;
    _streamingMessage = null;
    _unconfirmedText = '';
    _streamText = '';
    _streamBuffer.clear();
    _warnings.clear();
    _draft = '';
    _loading = true;
    _busy = false;
    _streaming = false;
    _recovering = false;
    _phase = null;
    _error = null;
    _notice = null;
    _diagnostics = null;
    _loadedOffset = 0;
    _totalFloors = 0;
    _hasEarlier = false;
    _recoveryAttempt = 0;
    _notify();

    final connectionId = _connection.connectionId;
    await _settings.setLastSession(session.id);
    if (connectionId != null) {
      final draft = await _drafts.read(connectionId, session.id);
      if (epoch != _epoch) {
        return;
      }
      if (draft != null && draft.text.trim().isNotEmpty) {
        _draft = draft.text;
        _notify();
      }
    }

    try {
      final results = await Future.wait<Object>([
        repository.fetchLatestTimeline(session.id),
        repository.fetchActiveRun(session.id),
      ]);
      if (epoch != _epoch) {
        return;
      }
      _applyTimeline(results[0] as SessionTimeline);
      final run = results[1] as ActiveRun;
      if (run.busy) {
        _recovering = true;
        _phase = run.phase;
        _notice = '服务器仍在生成，正在恢复会话；不会重复发送。';
        _scheduleRecovery();
      } else if (_messages.isNotEmpty &&
          _messages.last.floorState == 'failed') {
        _notice = '上一轮生成失败。可以查看历史后重新操作，不会自动重发。';
      }
    } on ApiError catch (error) {
      if (epoch == _epoch) {
        _error = error.userMessage;
      }
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        _notify();
      }
    }
  }

  void close() {
    _epoch++;
    _cancelTimers();
    _cancelStream?.call();
    _cancelStream = null;
    _session = null;
    _messages = const [];
    _pendingUser = null;
    _streamingMessage = null;
    _unconfirmedText = '';
    _draft = '';
    _streamText = '';
    _streamBuffer.clear();
    _warnings.clear();
    _recovering = false;
    _busy = false;
    _streaming = false;
    _phase = null;
    _loading = false;
    _loadingEarlier = false;
    _error = null;
    _notice = null;
    _diagnostics = null;
    _notify();
  }

  void updateDraft(String text) {
    if (_draft == text) {
      return;
    }
    _draft = text;
    _scheduleDraftSave();
    _notify();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _persistDraft);
  }

  Future<void> _persistDraft() async {
    final session = _session;
    final connectionId = _connection.connectionId;
    if (session == null || connectionId == null) {
      return;
    }
    final text = _draft;
    if (text.trim().isEmpty) {
      await _drafts.delete(connectionId, session.id);
      return;
    }
    await _drafts.save(
      ChatDraft(
        connectionId: connectionId,
        sessionId: session.id,
        text: text,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> send() async {
    final repository = _connection.chat;
    final session = _session;
    final connectionId = _connection.connectionId;
    final text = _draft.trim();
    if (repository == null ||
        session == null ||
        connectionId == null ||
        text.isEmpty ||
        isWriteLocked) {
      return;
    }

    final epoch = _epoch;
    _busy = true;
    _streaming = true;
    _error = null;
    _notice = null;
    _warnings.clear();
    _phase = 'preparing';
    _unconfirmedText = '';
    _streamText = '';
    _streamBuffer.clear();
    _pendingUser = DisplayMessage.pendingUser(text);
    _streamingMessage = DisplayMessage.streaming('');
    _draft = '';
    _notify();

    // 先落盘，网络中断也能恢复用户输入；提交确认后再删除。
    await _drafts.save(
      ChatDraft(
        connectionId: connectionId,
        sessionId: session.id,
        text: text,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    var confirmed = false;
    try {
      final done = await repository.respondStream(
        sessionId: session.id,
        message: text,
        onAttach: (cancel) {
          if (epoch == _epoch) {
            _cancelStream = cancel;
          }
        },
        onStart: () {
          if (epoch != _epoch) {
            return;
          }
          _phase = 'generating';
          _notify();
        },
        onChunk: (chunk) {
          if (epoch == _epoch) {
            _onChunk(chunk);
          }
        },
        onPhase: (phase) {
          if (epoch != _epoch) {
            return;
          }
          _phase = phase;
          _notify();
        },
        onWarning: (warning) {
          if (epoch == _epoch) {
            _warnings.add(warning);
          }
        },
      );
      if (epoch != _epoch) {
        return;
      }
      _flushStream(force: true);
      if (done.finalState != 'committed') {
        _notice = '服务器未确认提交（状态：${done.finalState}），正在核对时间线。';
      } else if (done.generatedText.trim().isEmpty) {
        _notice = '模型没有返回正文，可能已用尽推理预算。';
      }
      if (_warnings.isNotEmpty) {
        _notice = _warnings.join('；');
      }
      confirmed = await _reconcile(epoch, expectedFloorId: done.floorId);
      if (confirmed) {
        await _drafts.delete(connectionId, session.id);
      } else {
        await _restoreDraft(text, connectionId, session.id);
      }
    } on http.RequestAbortedException {
      if (epoch == _epoch) {
        _notice = '已停止本地接收。服务端可能仍在生成，正在核对结果。';
        await _reconcile(epoch);
        await _restoreDraft(text, connectionId, session.id);
      }
    } on ApiError catch (error) {
      if (epoch == _epoch) {
        _error = _describeSendError(error);
        await _reconcile(epoch);
        await _restoreDraft(text, connectionId, session.id);
      }
    } finally {
      if (epoch == _epoch) {
        _flushStream(force: true);
        if (!confirmed && _streamText.trim().isNotEmpty) {
          _unconfirmedText = _streamText;
        }
        _busy = false;
        _streaming = false;
        _pendingUser = null;
        _streamingMessage = null;
        _streamText = '';
        _streamBuffer.clear();
        _cancelStream = null;
        _phase = null;
        _notify();
      }
    }
  }

  Future<void> regenerate() async {
    final repository = _connection.chat;
    final session = _session;
    if (repository == null || session == null || !canRegenerate) {
      return;
    }
    final epoch = _epoch;
    _busy = true;
    _error = null;
    _notice = '正在重新生成，旧回复会保留到新结果确认。';
    _phase = 'generating';
    _unconfirmedText = '';
    _notify();
    try {
      final result = await repository.regenerate(sessionId: session.id);
      if (epoch != _epoch) {
        return;
      }
      if (result.generatedText.trim().isEmpty) {
        _error = '模型没有返回正文，旧回复已保留。可以稍后重试，或降低预设的字数要求。';
        return;
      }
      final confirmed = await _reconcile(
        epoch,
        expectedFloorId: result.floorId,
      );
      if (confirmed) {
        _notice = '已替换为新的回复。';
      } else if (_error == null) {
        _notice = '新结果尚未确认，旧回复仍然保留。请稍后手动刷新核对。';
      }
    } on ApiError catch (error) {
      if (epoch == _epoch) {
        _error = '重新生成失败：${error.userMessage}。旧回复仍然保留。';
      }
    } finally {
      if (epoch == _epoch) {
        _busy = false;
        _phase = null;
        _notify();
      }
    }
  }

  void stopStreaming() {
    if (!_streaming) {
      return;
    }
    _cancelStream?.call();
    _notice = '正在停止本地接收…';
    _notify();
  }

  Future<void> refreshFromServer({bool manual = false}) async {
    final repository = _connection.sessions;
    final session = _session;
    if (repository == null || session == null || _streaming) {
      return;
    }
    final epoch = _epoch;
    if (manual) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final results = await Future.wait<Object>([
        repository.fetchLatestTimeline(session.id),
        repository.fetchActiveRun(session.id),
      ]);
      if (epoch != _epoch) {
        return;
      }
      _applyTimeline(results[0] as SessionTimeline);
      final run = results[1] as ActiveRun;
      _recovering = run.busy;
      _phase = run.phase;
      _recoveryAttempt = 0;
      if (run.busy) {
        _notice = '服务器仍在生成，继续等待结果。';
        _scheduleRecovery();
      } else if (manual) {
        _notice = '已与服务器同步。';
      }
    } on ApiError catch (error) {
      if (epoch == _epoch) {
        _error = error.userMessage;
        if (manual) {
          _notice = '当前离线读取失败，已保留当前内容。';
        }
      }
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> loadEarlier() async {
    final repository = _connection.sessions;
    final session = _session;
    if (repository == null ||
        session == null ||
        _loadingEarlier ||
        !_hasEarlier) {
      return;
    }
    final epoch = _epoch;
    _loadingEarlier = true;
    _notify();
    try {
      final page = await repository.fetchEarlier(
        session.id,
        currentOffset: _loadedOffset,
      );
      if (epoch != _epoch) {
        return;
      }
      _prependTimeline(page);
      _loadedOffset = page.offset;
      _hasEarlier = page.offset > 0;
    } on ApiError catch (error) {
      if (epoch == _epoch) {
        _error = error.userMessage;
      }
    } finally {
      if (epoch == _epoch) {
        _loadingEarlier = false;
        _notify();
      }
    }
  }

  Future<String?> applyOption(
    ActionOption option, {
    required bool direct,
  }) async {
    if (_session == null || isWriteLocked) {
      return null;
    }
    final previous = _draft;
    _draft = option.text;
    _scheduleDraftSave();
    _notify();
    if (direct) {
      await send();
      return null;
    }
    _focusSignal++;
    _notify();
    return previous;
  }

  Future<void> runDryRun() async {
    final repository = _connection.chat;
    final session = _session;
    if (repository == null || session == null) {
      return;
    }
    final message = _draft.trim().isNotEmpty
        ? _draft.trim()
        : _lastUserContent() ?? '';
    if (message.isEmpty) {
      _error = '先写下一条消息，再预览提示词预算。';
      _notify();
      return;
    }
    _diagnosticsLoading = true;
    _error = null;
    _notify();
    try {
      _diagnostics = await repository.dryRun(
        sessionId: session.id,
        message: message,
      );
    } on ApiError catch (error) {
      _error = error.userMessage;
    } finally {
      _diagnosticsLoading = false;
      _notify();
    }
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    _notify();
  }

  void clearNotice() {
    if (_notice == null) {
      return;
    }
    _notice = null;
    _notify();
  }

  String? _lastUserContent() {
    for (var index = _messages.length - 1; index >= 0; index--) {
      if (_messages[index].isUser) {
        return _messages[index].content;
      }
    }
    return null;
  }

  Future<bool> _reconcile(int epoch, {String? expectedFloorId}) async {
    final repository = _connection.sessions;
    final session = _session;
    if (repository == null || session == null) {
      return false;
    }
    try {
      final timeline = await repository.fetchLatestTimeline(session.id);
      if (epoch != _epoch) {
        return false;
      }
      _applyTimeline(timeline);
      final run = await repository.fetchActiveRun(session.id);
      if (epoch != _epoch) {
        return false;
      }
      _recovering = run.busy;
      _phase = run.phase;
      if (run.busy) {
        _notice = '服务器仍在生成，继续核对结果。';
        _scheduleRecovery();
      } else {
        _recoveryAttempt = 0;
      }
      _notify();
      if (run.busy) {
        return false;
      }
      if (expectedFloorId == null) {
        return false;
      }
      return _messages.any((message) => message.floorId == expectedFloorId) &&
          timeline.floors.isNotEmpty &&
          timeline.floors.last.state == 'committed';
    } on ApiError {
      if (epoch == _epoch) {
        _notice = '生成结果尚未确认：无法读取服务端时间线。请稍后手动刷新。';
        _notify();
      }
      return false;
    }
  }

  Future<void> _restoreDraft(
    String text,
    String connectionId,
    String sessionId,
  ) async {
    if (_draft.trim().isNotEmpty) {
      return;
    }
    _draft = text;
    _notify();
    await _drafts.save(
      ChatDraft(
        connectionId: connectionId,
        sessionId: sessionId,
        text: text,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _applyTimeline(SessionTimeline timeline) {
    _loadedOffset = timeline.offset;
    _totalFloors = timeline.total;
    _hasEarlier = timeline.offset > 0;
    _messages = _buildMessages(timeline.floors);
    _unconfirmedText = '';
  }

  void _prependTimeline(SessionTimeline page) {
    final known = _messages.map((message) => message.floorId).toSet();
    final older = page.floors
        .where((floor) => !known.contains(floor.id))
        .toList(growable: false);
    if (older.isEmpty) {
      return;
    }
    _messages = [..._buildMessages(older), ..._messages];
  }

  List<DisplayMessage> _buildMessages(List<TimelineFloor> floors) {
    final result = <DisplayMessage>[];
    final seen = <String>{};
    for (final floor in floors) {
      final pages = floor.activePages.isEmpty ? floor.pages : floor.activePages;
      for (final page in pages) {
        for (final message in page.messages) {
          if (message.role == 'system') {
            continue;
          }
          if (message.content.trim().isEmpty && message.role != 'assistant') {
            continue;
          }
          if (!seen.add(message.id)) {
            continue;
          }
          result.add(
            DisplayMessage.fromTimeline(
              message,
              floorId: floor.id,
              floorNo: floor.floorNo,
              floorState: floor.state,
            ),
          );
        }
      }
    }
    return List.unmodifiable(result);
  }

  void _onChunk(String chunk) {
    _streamBuffer.write(chunk);
    _flushTimer ??= Timer(const Duration(milliseconds: 70), _flushStream);
  }

  void _flushStream({bool force = false}) {
    if (_flushTimer != null) {
      _flushTimer!.cancel();
      _flushTimer = null;
    }
    if (_streamBuffer.isNotEmpty) {
      _streamText += _streamBuffer.toString();
      _streamBuffer.clear();
    }
    if (!force && _streamText.isEmpty) {
      return;
    }
    final message = _streamingMessage;
    if (message == null) {
      return;
    }
    _streamingMessage = message.copyWith(
      content: _streamText,
      derived: DerivedMessage(markdown: _streamText, options: const []),
    );
    _notify();
  }

  void _scheduleRecovery() {
    _recoveryTimer?.cancel();
    if (!_recovering || _disposed) {
      return;
    }
    if (_recoveryAttempt >= 12) {
      _recovering = false;
      _notice = '恢复轮询已暂停，请回到会话后手动刷新核对服务端。';
      _notify();
      return;
    }
    _recoveryAttempt++;
    final delay = _recoveryAttempt <= 3
        ? const Duration(milliseconds: 1500)
        : _recoveryAttempt <= 6
        ? const Duration(seconds: 3)
        : const Duration(seconds: 6);
    _recoveryTimer = Timer(delay, _pollRecovery);
  }

  Future<void> _pollRecovery() async {
    final repository = _connection.sessions;
    final session = _session;
    if (_disposed || _streaming || !_recovering) {
      return;
    }
    if (repository == null || session == null) {
      _recovering = false;
      _notify();
      return;
    }
    final epoch = _epoch;
    try {
      final run = await repository.fetchActiveRun(session.id);
      if (epoch != _epoch) {
        return;
      }
      _phase = run.phase;
      if (run.busy) {
        _notify();
        _scheduleRecovery();
        return;
      }
      final timeline = await repository.fetchLatestTimeline(session.id);
      if (epoch != _epoch) {
        return;
      }
      _applyTimeline(timeline);
      _recovering = false;
      _recoveryAttempt = 0;
      _notice = '会话已恢复，结果来自服务端时间线。';
      _notify();
    } on ApiError {
      if (epoch != _epoch) {
        return;
      }
      _scheduleRecovery();
    }
  }

  String _describeSendError(ApiError error) {
    if (error.isConflict) {
      return '服务器拒绝了这次写入：${error.message}。可能已有另一个客户端在生成，请刷新核对。';
    }
    if (error.isAuthError) {
      return '登录状态已失效，请重新连接后再试。内容已保留。';
    }
    return '生成中断：${error.message}。正在核对服务端记录，不会自动重发。';
  }

  void _handleConnectionChange() {
    final id = _connection.connectionId;
    if (id == _lastConnectionId) {
      return;
    }
    _lastConnectionId = id;
    close();
  }

  void _cancelTimers() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _draftTimer?.cancel();
    _draftTimer = null;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _cancelTimers();
    _cancelStream?.call();
    _cancelStream = null;
    _connection.removeListener(_handleConnectionChange);
    super.dispose();
  }
}
