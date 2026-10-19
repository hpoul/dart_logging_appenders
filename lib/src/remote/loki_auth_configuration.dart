import 'dart:convert';

/// Basic-auth credentials for Loki servers requiring authentication.
///
/// Servers without authentication (e.g. local development setups) don't
/// need an auth configuration at all.
class LokiAuthConfiguration {
  LokiAuthConfiguration({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  /// Value for the HTTP `Authorization` header.
  String get basicAuthHeader =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';
}
