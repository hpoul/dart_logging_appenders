import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:logging_appenders/src/remote/base_remote_appender.dart';
import 'package:logging_appenders/src/remote/loki_auth_configuration.dart';
import 'package:logging_appenders/src/remote/loki_configuration.dart';
import 'package:logging_appenders/src/remote/loki_connection_type.dart';
import 'package:meta/meta.dart';

// ignore: unused_element
final _logger = DummyLogger('logging_appenders.loki_appender');

/// Appender used to push logs to [Loki](https://github.com/grafana/loki).
class LokiApiAppender extends BaseHttpLogSender {
  /// Creates an appender pushing to Loki as described by [configuration].
  LokiApiAppender.withConfiguration({
    required this.configuration,
    super.formatter,
    super.bufferSize,
  });

  /// Legacy constructor, kept for backwards compatibility.
  ///
  /// Prefer [LokiApiAppender.withConfiguration] with a [LokiConfiguration].
  @Deprecated('Use LokiApiAppender.withConfiguration() instead.')
  LokiApiAppender({
    required String server,
    required String username,
    required String password,
    required Map<String, String> labels,
    LokiConnectionType connectionType = LokiConnectionType.https,
    LogRecordFormatter? formatter,
    int? bufferSize,
  }) : this.withConfiguration(
         configuration: LokiConfiguration(
           server: server,
           connectionType: connectionType,
           authConfiguration: LokiAuthConfiguration(
             username: username,
             password: password,
           ),
           labels: labels,
         ),
         formatter: formatter,
         bufferSize: bufferSize,
       );

  final LokiConfiguration configuration;

  /// URL of the Loki push API derived from [configuration].
  @visibleForTesting
  String get pushUrl =>
      '${configuration.connectionType.name}://${configuration.server}'
      '/loki/api/v1/push';

  /// Request headers derived from [configuration].
  ///
  /// Contains an `Authorization` header only when [configuration] has an
  /// auth configuration.
  @visibleForTesting
  Map<String, String> get requestHeaders {
    final auth = configuration.authConfiguration;
    if (auth == null) {
      return const {};
    }
    return {HttpHeaders.authorizationHeader: auth.basicAuthHeader};
  }

  /// Formats [entry] as a Loki log line.
  ///
  /// Line labels (level, logger name, error details) are rendered as
  /// `key=value` pairs in front of the message.
  @visibleForTesting
  static String encodeLine(LogEntry entry) {
    final labels = entry.lineLabels.entries
        .map((label) => '${label.key}=${_encodeLineLabelValue(label.value)}')
        .join(' ');
    if (labels.isEmpty) {
      return entry.line;
    }
    return '$labels - ${entry.line}';
  }

  /// Encodes [entry] as a Loki `values` row.
  ///
  /// Returns `[timestamp, line]` with an additional structured-metadata
  /// element when [userProperties] is not empty.
  @visibleForTesting
  static List<Object> encodeValue(
    LogEntry entry,
    Map<String, String> userProperties,
  ) {
    final timestamp = (entry.ts.microsecondsSinceEpoch * 1000).toString();
    final line = encodeLine(entry);
    if (userProperties.isEmpty) {
      return [timestamp, line];
    }
    return [
      timestamp,
      line,
      <String, String>{...userProperties},
    ];
  }

  /// Builds the JSON body for a push request.
  ///
  /// Entries are grouped by log level into one stream per level, each
  /// stream carrying the configured labels plus a `level` label.
  @visibleForTesting
  String buildJsonBody(
    List<LogEntry> entries,
    Map<String, String> userProperties,
  ) {
    final levels = entries.map((entry) => entry.logLevel).toSet();
    final streams = [
      for (final level in levels)
        LokiStream(
          {...configuration.labels, 'level': level.name},
          entries.where((entry) => entry.logLevel == level).toList(),
        ),
    ];
    return json.encode(
      LokiPushBody(streams).toJson(),
      toEncodable: (dynamic obj) {
        if (obj is LogEntry) {
          return encodeValue(obj, userProperties);
        }
        return obj.toJson();
      },
    );
  }

  static String _encodeLineLabelValue(String value) {
    if (value.contains(' ')) {
      return json.encode(value);
    }
    return value;
  }

  @override
  Future<void> sendLogEventsWithHttp(
    List<LogEntry> entries,
    Map<String, String> userProperties,
    Future<void> cancelToken,
  ) {
    if (entries.isEmpty) {
      return Future.value();
    }
    return sendRequest(
      http.AbortableRequest(
          'POST',
          Uri.parse(pushUrl),
          abortTrigger: cancelToken,
        )
        ..body = buildJsonBody(entries, userProperties)
        ..headers.addAll(requestHeaders)
        ..headers[HttpHeaders.contentTypeHeader] = ContentType.json.value,
    );
  }
}

/// Body of a Loki push request (`POST /loki/api/v1/push`).
class LokiPushBody {
  LokiPushBody(this.streams);

  final List<LokiStream> streams;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'streams': streams.map((stream) => stream.toJson()).toList(growable: false),
  };
}

/// A single Loki stream: entries sharing the same set of labels.
class LokiStream {
  LokiStream(this.labels, this.entries);

  final Map<String, String> labels;
  final List<LogEntry> entries;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'stream': labels,
    'values': entries,
  };
}
