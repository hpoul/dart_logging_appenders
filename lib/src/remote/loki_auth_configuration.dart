import 'dart:convert';

class LokiAuthConiguration {
  LokiAuthConiguration({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  String get basicAuthHeader =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';
}