class UserAccount {
  final String userId;
  final String username;
  final String serverUrl;
  final String accessToken;
  final String serverId;
  final String? profileImageBase64;
  final bool isAdmin;

  UserAccount({
    required this.userId,
    required this.username,
    required this.serverUrl,
    required this.accessToken,
    required this.serverId,
    this.profileImageBase64,
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'serverUrl': serverUrl,
    'accessToken': accessToken,
    'serverId': serverId,
    'profileImageBase64': profileImageBase64,
    'isAdmin': isAdmin,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    userId: json['userId'] as String,
    username: json['username'] as String,
    serverUrl: json['serverUrl'] as String,
    accessToken: json['accessToken'] as String,
    serverId: json['serverId'] as String,
    profileImageBase64: json['profileImageBase64'] as String?,
    isAdmin: json['isAdmin'] as bool? ?? false,
  );
}
