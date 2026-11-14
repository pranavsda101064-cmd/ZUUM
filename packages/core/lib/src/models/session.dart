import 'user.dart';

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final ZUser user;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String,
        user: ZUser.fromJson(json['user'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'access': accessToken,
        'refresh': refreshToken,
        'user': user.toJson(),
      };
}
