/// Authentication state model
///
/// Represents the current authentication status of the user.
class AuthState {
  final bool isAuthenticated;
  final String? userEmail;
  final String? identityPoolId;
  final DateTime? lastAuthTime;

  AuthState({
    required this.isAuthenticated,
    this.userEmail,
    this.identityPoolId,
    this.lastAuthTime,
  });

  /// Create an unauthenticated state
  factory AuthState.unauthenticated() {
    return AuthState(isAuthenticated: false);
  }

  /// Create an authenticated state
  factory AuthState.authenticated({
    required String userEmail,
    required String identityPoolId,
  }) {
    return AuthState(
      isAuthenticated: true,
      userEmail: userEmail,
      identityPoolId: identityPoolId,
      lastAuthTime: DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  AuthState copyWith({
    bool? isAuthenticated,
    String? userEmail,
    String? identityPoolId,
    DateTime? lastAuthTime,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userEmail: userEmail ?? this.userEmail,
      identityPoolId: identityPoolId ?? this.identityPoolId,
      lastAuthTime: lastAuthTime ?? this.lastAuthTime,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'isAuthenticated': isAuthenticated,
      'userEmail': userEmail,
      'identityPoolId': identityPoolId,
      'lastAuthTime': lastAuthTime?.toIso8601String(),
    };
  }

  /// Create from JSON map
  factory AuthState.fromJson(Map<String, dynamic> json) {
    return AuthState(
      isAuthenticated: json['isAuthenticated'] as bool,
      userEmail: json['userEmail'] as String?,
      identityPoolId: json['identityPoolId'] as String?,
      lastAuthTime: json['lastAuthTime'] != null
          ? DateTime.parse(json['lastAuthTime'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthState &&
        other.isAuthenticated == isAuthenticated &&
        other.userEmail == userEmail &&
        other.identityPoolId == identityPoolId &&
        other.lastAuthTime == lastAuthTime;
  }

  @override
  int get hashCode {
    return isAuthenticated.hashCode ^
        userEmail.hashCode ^
        identityPoolId.hashCode ^
        lastAuthTime.hashCode;
  }

  @override
  String toString() {
    return 'AuthState(isAuthenticated: $isAuthenticated, userEmail: $userEmail, identityPoolId: $identityPoolId)';
  }
}
