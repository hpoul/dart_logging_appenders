import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/remote/base_remote_appender.dart';

final _logger = DummyLogger('logging_appenders.loki_appender');

/// Appender used to push logs to [Loki](https://github.com/grafana/loki).
class LokiApiAppender extends BaseDioLogSender {
  LokiApiAppender({
    required this.server,
    required this.username,
    required this.password,
    required this.labels,
  })  : labelsString =
            '{${labels.entries.map((entry) => '${entry.key}="${entry.value}"').join(',')}}',
        authHeader = 'Basic ${base64.encode(utf8.encode([
          username,
          password
        ].join(':')))}';

  final String server;
  final String username;
  final String password;
  final String authHeader;
  final Map<String, String> labels;
  final String labelsString;

  static final DateFormat _dateFormat =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

  Dio? _clientInstance;

  Dio get _client => _clientInstance ??= Dio();

  static String _encodeLineLabelValue(String value) {
    if (value.contains(' ')) {
      return json.encode(value);
    }
    return value;
  }

  @override
  Future<void> sendLogEventsWithDio(List<LogEntry> entries,
      Map<String, String> userProperties, CancelToken cancelToken) {
    final jsonObject =
        LokiPushBody([LokiStream(labelsString, entries)]).toJson();
    final jsonBody = json.encode(jsonObject, toEncodable: (dynamic obj) {
      if (obj is LogEntry) {
        return {
          'ts': _dateFormat.format(obj.ts.toUtc()),
          'line': [
            obj.lineLabels.entries
                .map((entry) =>
                    '${entry.key}=${_encodeLineLabelValue(entry.value)}')
                .join(' '),
            obj.line,
          ].join(' - ')
        };
      }
      return obj.toJson();
    });
    return _client
        .post<dynamic>(
          'https://$server/api/prom/push',
          cancelToken: cancelToken,
          data: jsonBody,
          options: Options(
            headers: <String, String>{
              HttpHeaders.authorizationHeader: authHeader,
            },
            contentType: ContentType(
                    ContentType.json.primaryType, ContentType.json.subType)
                .value,
          ),
        )
        .then(
          (response) => Future<void>.value(null),
//      _logger.finest('sent logs.');
        )
        .catchError((Object err, StackTrace stackTrace) {
      String? message;
      if (err is DioError) {
        if (err.response != null) {
          message = 'response:${err.response!.data}';
        }
      }
      _logger.warning(
          'Error while sending logs to loki. $message', err, stackTrace);
      return Future<void>.error(err, stackTrace);
    });
  }
}

class LokiPushBody {
  LokiPushBody(this.streams);

  final List<LokiStream> streams;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'streams':
            streams.map((stream) => stream.toJson()).toList(growable: false),
      };
}

class LokiStream {
  LokiStream(this.labels, this.entries);

  final String labels;
  final List<LogEntry> entries;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'labels': labels, 'entries': entries};
}
