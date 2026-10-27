class GenerationDefaults {
  const GenerationDefaults._();

  static const int contextWindow = 1048576;
  static const int maxOutputTokens = 65536;
  static const int inputBudget = contextWindow - maxOutputTokens;

  static const String contextLabel = '1M';
  static const String outputLabel = '64K';
}

class ConnectionConfig {
  const ConnectionConfig({
    required this.endpoint,
    required this.apiKey,
    required this.playerName,
    required this.remember,
    this.profileId = '',
  });

  final String endpoint;
  final String apiKey;
  final String playerName;
  final bool remember;
  final String profileId;

  Uri get baseUri => Uri.parse(endpoint);

  ConnectionConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? playerName,
    bool? remember,
    String? profileId,
  }) {
    return ConnectionConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      playerName: playerName ?? this.playerName,
      remember: remember ?? this.remember,
      profileId: profileId ?? this.profileId,
    );
  }

  Map<String, Object?> toPublicJson() => {
    'endpoint': endpoint,
    'playerName': playerName,
    'remember': remember,
    'profileId': profileId,
  };
}
