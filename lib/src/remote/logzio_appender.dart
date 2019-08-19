import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/src/remote/base_remote_appender.dart';
import 'package:meta/meta.dart';

// ignore: unused_element
final _logger = Logger('loki_logger');

class LogzIoApiAppender extends BaseDioLogSender {
  LogzIoApiAppender({
    @required this.apiToken,
    @required this.labels,
  });

  final String apiToken;
  final Map<String, String> labels;

  Dio _clientInstance;

  Dio get _client => _clientInstance ??= Dio();

  @override
  Future<void> sendLogEventsWithDio(List<LogEntry> entries,
      Map<String, String> userProperties, CancelToken cancelToken) {
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
          'https://listener.logz.io:8071/?token=$apiToken&type=flutterlog',
          data: body,
          cancelToken: cancelToken,
          options: Options(
            contentType: ContentType(
                ContentType.json.primaryType, ContentType.json.subType),
          ),
        )
        .then((val) => null);
  }
}
