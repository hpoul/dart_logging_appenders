import 'package:logging_appenders/src/remote/loki_auth_configuration.dart';
import 'package:logging_appenders/src/remote/loki_connection_type.dart';

class LokiConfiguration {
  LokiConfiguration({
    required this.server,
    required this.connectionType,
    required this.authConfiguration,
    required this.labels,
  });

  final String server;
  final LokiConnectionType connectionType;
  final LokiAuthConiguration? authConfiguration;
  final Map<String, String> labels;
}