import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/remote/base_remote_appender.dart';

// ignore: unused_element
final _logger = DummyLogger('logging_appenders.loki_appender');

/// Appender used to push logs to [Loki](https://github.com/grafana/loki).
class LokiApiAppender extends BaseHttpLogSender {
  LokiApiAppender({
    required this.server,
    required this.username,
    required this.password,
    required this.labels,
  }) : labelsString =
           '{${labels.entries.map((entry) => '${entry.key}="${entry.value}"').join(',')}}',
       authHeader =
           'Basic ${base64.encode(utf8.encode([username, password].join(':')))}';

  final String server;
  final String username;
  final String password;
  final String authHeader;
  final Map<String, String> labels;
  final String labelsString;

  static final DateFormat _dateFormat = DateFormat(
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
  );

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
    final jsonObject = LokiPushBody([
      LokiStream(labelsString, entries),
    ]).toJson();
    final jsonBody = json.encode(
      jsonObject,
      toEncodable: (dynamic obj) {
        if (obj is LogEntry) {
          return {
            'ts': _dateFormat.format(obj.ts.toUtc()),
            'line': [
              obj.lineLabels.entries
                  .map(
                    (entry) =>
                        '${entry.key}=${_encodeLineLabelValue(entry.value)}',
                  )
                  .join(' '),
              obj.line,
            ].join(' - '),
          };
        }
        return obj.toJson();
      },
    );
    return sendRequest(
      http.AbortableRequest(
          'POST',
          Uri.parse('https://$server/api/prom/push'),
          abortTrigger: cancelToken,
        )
        ..body = jsonBody
        ..headers[HttpHeaders.authorizationHeader] = authHeader
        ..headers[HttpHeaders.contentTypeHeader] = ContentType.json.value,
    );
  }
}

class LokiPushBody {
  LokiPushBody(this.streams);

  final List<LokiStream> streams;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'streams': streams.map((stream) => stream.toJson()).toList(growable: false),
  };
}

class LokiStream {
  LokiStream(this.labels, this.entries);

  final String labels;
  final List<LogEntry> entries;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'labels': labels,
    'entries': entries,
  };
}
