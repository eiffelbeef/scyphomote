class UserAccount {
  final String userId;
  final String username;
  final String serverUrl;
  final String accessToken;
  final String serverId;
  final String? profileImageBase64;

  UserAccount({
    required this.userId,
    required this.username,
    required this.serverUrl,
    required this.accessToken,
    required this.serverId,
    this.profileImageBase64,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'serverUrl': serverUrl,
    'accessToken': accessToken,
    'serverId': serverId,
    'profileImageBase64': profileImageBase64,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    userId: json['userId'] as String,
    username: json['username'] as String,
    serverUrl: json['serverUrl'] as String,
    accessToken: json['accessToken'] as String,
    serverId: json['serverId'] as String,
    profileImageBase64: json['profileImageBase64'] as String?,
  );
}
