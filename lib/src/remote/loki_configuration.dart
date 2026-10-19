import 'package:logging_appenders/src/remote/loki_auth_configuration.dart';
import 'package:logging_appenders/src/remote/loki_connection_type.dart';

/// Configuration for [LokiApiAppender].
class LokiConfiguration {
  LokiConfiguration({
    required this.server,
    this.connectionType = LokiConnectionType.https,
    this.authConfiguration,
    required this.labels,
  }) : assert(
         !server.contains('://'),
         'server must be a plain host, without scheme.',
       );

  /// Host (and optional port) of the Loki server, e.g. `loki:3100`.
  ///
  /// Must not contain a scheme (`https://`) or path, those are derived
  /// from [connectionType] and the Loki API.
  final String server;

  /// Transport protocol, defaults to [LokiConnectionType.https].
  final LokiConnectionType connectionType;

  /// Credentials for servers requiring authentication, `null` (default)
  /// sends no `Authorization` header.
  ///
  /// Note: with [LokiConnectionType.http] credentials travel in clear text.
  final LokiAuthConfiguration? authConfiguration;

  /// Static labels attached to every stream.
  ///
  /// A `level` label is added automatically and takes precedence over a
  /// custom `level` entry in [labels].
  final Map<String, String> labels;
}
