import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/remote/base_remote_appender.dart';
import 'package:logging_appenders/src/remote/loki_configuration.dart';

final _logger = DummyLogger('logging_appenders.loki_appender');

/// Appender used to push logs to [Loki](https://github.com/grafana/loki).
class LokiApiAppender extends BaseDioLogSender {
  LokiApiAppender({
    required this.configuration
  }) : authHeader = configuration.authConfiguration?.basicAuthHeader ?? '';

  final LokiConfiguration configuration;
  final String authHeader;

  late final Dio _client = Dio();

  @override
  Future<void> dispose() async {
    await super.dispose();
    _client.close();
  }

  @override
  Future<void> sendLogEventsWithDio(List<LogEntry> entries,
      Map<String, String> userProperties, CancelToken cancelToken) {
    var levels = entries.map((element) => element.logLevel).toSet();
    List<LokiStream> streams = [];
    for (var level in levels) {
      var newHeaders = Map<String, String>.from(configuration.labels)
        ..addAll({'level': level.name});
      streams.add(LokiStream(
          newHeaders, entries.where((e) => e.logLevel == level).toList()));
    }
    final jsonObject = LokiPushBody(streams);
    final jsonBody = json.encode(jsonObject, toEncodable: (dynamic obj) {
      if (obj is LogEntry) {
        return [
          '${obj.ts.microsecondsSinceEpoch * 1000}',
          obj.line,
        ];
      }
      return obj.toJson();
    });
    return _client
        .post<dynamic>(
      '${configuration.connectionType.value}://${configuration
          .server}/loki/api/v1/push',
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
      if (err is DioException) {
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

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
        'streams':
        streams.map((stream) => stream.toJson()).toList(growable: false),
      };
}

class LokiStream {
  LokiStream(this.labels, this.entries);

  final Map<String, String> labels;
  final List<LogEntry> entries;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'stream': labels, 'values': entries};
}
