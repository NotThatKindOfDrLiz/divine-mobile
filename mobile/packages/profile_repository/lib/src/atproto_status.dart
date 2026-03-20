/// ATProto provisioning status returned by keycast.
class AtprotoStatus {
  const AtprotoStatus({
    required this.enabled,
    required this.state,
    required this.did,
    required this.error,
    required this.username,
  });

  factory AtprotoStatus.fromJson(Map<String, dynamic> json) {
    return AtprotoStatus(
      enabled: json['enabled'] as bool? ?? false,
      state: json['state'] as String?,
      did: json['did'] as String?,
      error: json['error'] as String?,
      username: json['username'] as String?,
    );
  }

  final bool enabled;
  final String? state;
  final String? did;
  final String? error;
  final String? username;

  bool get isPending => state == 'pending';
  bool get isReady => state == 'ready';
  bool get isFailed => state == 'failed';
}
