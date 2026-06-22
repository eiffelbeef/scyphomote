class UserAccount {
  final String userId;
  final String username;
  final String serverUrl;
  final String accessToken;
  final String serverId;
  final String? profileImageBase64;
  final bool isAdmin;
  final bool isEmby;
  final String? embyConnectAccessToken;
  final String? embyConnectUserId;
  final String? embySystemId;

  UserAccount({
    required this.userId,
    required this.username,
    required this.serverUrl,
    required this.accessToken,
    required this.serverId,
    this.profileImageBase64,
    this.isAdmin = false,
    this.isEmby = false,
    this.embyConnectAccessToken,
    this.embyConnectUserId,
    this.embySystemId,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'serverUrl': serverUrl,
    'accessToken': accessToken,
    'serverId': serverId,
    'profileImageBase64': profileImageBase64,
    'isAdmin': isAdmin,
    'isEmby': isEmby,
    'embyConnectAccessToken': embyConnectAccessToken,
    'embyConnectUserId': embyConnectUserId,
    'embySystemId': embySystemId,
  };

  UserAccount copyWith({
    String? userId,
    String? username,
    String? serverUrl,
    String? accessToken,
    String? serverId,
    String? profileImageBase64,
    bool? isAdmin,
    bool? isEmby,
    String? embyConnectAccessToken,
    String? embyConnectUserId,
    String? embySystemId,
  }) {
    return UserAccount(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      serverUrl: serverUrl ?? this.serverUrl,
      accessToken: accessToken ?? this.accessToken,
      serverId: serverId ?? this.serverId,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      isAdmin: isAdmin ?? this.isAdmin,
      isEmby: isEmby ?? this.isEmby,
      embyConnectAccessToken: embyConnectAccessToken ?? this.embyConnectAccessToken,
      embyConnectUserId: embyConnectUserId ?? this.embyConnectUserId,
      embySystemId: embySystemId ?? this.embySystemId,
    );
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    userId: json['userId'] as String,
    username: json['username'] as String,
    serverUrl: json['serverUrl'] as String,
    accessToken: json['accessToken'] as String,
    serverId: json['serverId'] as String,
    profileImageBase64: json['profileImageBase64'] as String?,
    isAdmin: json['isAdmin'] as bool? ?? false,
    isEmby: json['isEmby'] as bool? ?? false,
    embyConnectAccessToken: json['embyConnectAccessToken'] as String?,
    embyConnectUserId: json['embyConnectUserId'] as String?,
    embySystemId: json['embySystemId'] as String?,
  );
}
