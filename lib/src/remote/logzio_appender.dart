import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/remote/base_remote_appender.dart';

// ignore: unused_element
final _logger = DummyLogger('logging_appenders.logzio_appender');

/// Appender which sends all logs to https://logz.io/
/// Uses
class LogzIoApiAppender extends BaseDioLogSender {
  LogzIoApiAppender({
    super.formatter,
    required this.apiToken,
    required this.labels,
    this.url = 'https://listener.logz.io:8071/',
    this.type = 'flutterlog',
    super.bufferSize,
  });

  final String url;
  final String apiToken;
  final Map<String, String> labels;
  final String type;

  late final Dio _client = Dio();

  @override
  Future<void> dispose() async {
    await super.dispose();
    _client.close();
  }

  @override
  Future<void> sendLogEventsWithDio(List<LogEntry> entries,
      Map<String, String> userProperties, CancelToken cancelToken) {
    _logger.finest('Sending logs to $url');
    final body = entries
        .map((entry) => {
              '@timestamp': entry.ts.toUtc().toIso8601String(),
              'message': entry.line,
              'user': userProperties,
            }
              ..addAll(labels)
              ..addAll(entry.lineLabels))
        .map((map) => json.encode(map))
        .join('\n');
    return _client
        .post<dynamic>(
          '$url?token=$apiToken&type=$type',
          data: body,
          cancelToken: cancelToken,
          options: Options(
            contentType: ContentType(
                    ContentType.json.primaryType, ContentType.json.subType)
                .value,
          ),
        )
        .then((val) => null);
  }
}
