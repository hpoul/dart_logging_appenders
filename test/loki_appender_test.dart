import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:logging_appenders/src/remote/base_remote_appender.dart';
import 'package:logging_appenders/src/remote/loki_appender.dart';
import 'package:logging_appenders/src/remote/loki_auth_configuration.dart';
import 'package:logging_appenders/src/remote/loki_configuration.dart';
import 'package:logging_appenders/src/remote/loki_connection_type.dart';
import 'package:test/test.dart';

class TestLokiAppender extends LokiApiAppender {
  TestLokiAppender(LokiConfiguration configuration)
    : super.withConfiguration(configuration: configuration);

  http.BaseRequest? lastRequest;

  @override
  Future<void> sendRequest(http.BaseRequest request) {
    lastRequest = request;
    return Future.value();
  }
}

void main() {
  LokiConfiguration configWithoutAuth() =>
      LokiConfiguration(server: 'loki:3100', labels: {'app': 'test'});

  LokiApiAppender appenderWithoutAuth() =>
      LokiApiAppender.withConfiguration(configuration: configWithoutAuth());

  LogEntry entry({
    Level level = Level.INFO,
    String line = 'hello',
    Map<String, String> lineLabels = const {'lvl': 'INFO', 'logger': 'test'},
  }) => LogEntry(
    logLevel: level,
    ts: DateTime.fromMicrosecondsSinceEpoch(1700000000000000, isUtc: true),
    line: line,
    lineLabels: lineLabels,
  );

  List<dynamic> singleValueOf(String jsonBody) {
    final body = json.decode(jsonBody) as Map<String, dynamic>;
    final streams = body['streams'] as List<dynamic>;
    final values =
        (streams.single as Map<String, dynamic>)['values'] as List<dynamic>;
    return values.single as List<dynamic>;
  }

  group('LokiConfiguration', () {
    test('defaults to https without auth', () {
      final config = configWithoutAuth();
      expect(config.connectionType, LokiConnectionType.https);
      expect(config.authConfiguration, isNull);
    });

    test('rejects server with scheme or path', () {
      expect(
        () => LokiConfiguration(server: 'https://loki', labels: {}),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => LokiConfiguration(server: 'loki/push', labels: {}),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('LokiAuthConfiguration', () {
    test('basicAuthHeader', () {
      final auth = LokiAuthConfiguration(username: 'user', password: 'pass');
      expect(auth.basicAuthHeader, 'Basic dXNlcjpwYXNz');
    });
  });

  group('LokiApiAppender', () {
    test('legacy constructor maps to configuration', () {
      // ignore: deprecated_member_use_from_same_package
      final appender = LokiApiAppender(
        server: 'loki',
        username: 'user',
        password: 'pass',
        labels: {'app': 'test'},
      );
      expect(appender.configuration.server, 'loki');
      expect(appender.configuration.connectionType, LokiConnectionType.https);
      expect(appender.configuration.authConfiguration?.username, 'user');
      expect(appender.configuration.authConfiguration?.password, 'pass');
      expect(appender.configuration.labels, {'app': 'test'});
    });

    test('legacy constructor honors connectionType', () {
      // ignore: deprecated_member_use_from_same_package
      final appender = LokiApiAppender(
        server: 'loki',
        username: 'user',
        password: 'pass',
        labels: const {},
        connectionType: LokiConnectionType.http,
      );
      expect(appender.configuration.connectionType, LokiConnectionType.http);
    });

    test('pushUrl follows connectionType', () {
      expect(
        appenderWithoutAuth().pushUrl,
        'https://loki:3100/loki/api/v1/push',
      );
      final plainHttp = LokiApiAppender.withConfiguration(
        configuration: LokiConfiguration(
          server: 'loki:3100',
          connectionType: LokiConnectionType.http,
          labels: const {},
        ),
      );
      expect(plainHttp.pushUrl, 'http://loki:3100/loki/api/v1/push');
    });

    test('requestHeaders contains auth only when configured', () {
      expect(appenderWithoutAuth().requestHeaders, isEmpty);

      final withAuth = LokiApiAppender.withConfiguration(
        configuration: LokiConfiguration(
          server: 'loki',
          authConfiguration: LokiAuthConfiguration(
            username: 'user',
            password: 'pass',
          ),
          labels: const {},
        ),
      );
      expect(withAuth.requestHeaders, {
        HttpHeaders.authorizationHeader: 'Basic dXNlcjpwYXNz',
      });
    });

    test('buildJsonBody groups entries by level', () {
      final body =
          json.decode(
                appenderWithoutAuth().buildJsonBody([
                  entry(line: 'first info'),
                  entry(
                    level: Level.WARNING,
                    line: 'a warning',
                    lineLabels: const {'lvl': 'WARNING'},
                  ),
                  entry(line: 'second info'),
                ], const {}),
              )
              as Map<String, dynamic>;
      final streams = body['streams'] as List<dynamic>;
      expect(streams, hasLength(2));

      final info = streams[0] as Map<String, dynamic>;
      expect(info['stream'], {'app': 'test', 'level': 'INFO'});
      final infoValues = info['values'] as List<dynamic>;
      expect(infoValues, hasLength(2));
      expect((infoValues[0] as List<dynamic>)[1], contains('first info'));
      expect((infoValues[1] as List<dynamic>)[1], contains('second info'));

      final warning = streams[1] as Map<String, dynamic>;
      expect(warning['stream'], {'app': 'test', 'level': 'WARNING'});
    });

    test('buildJsonBody encodes timestamp and line', () {
      final value = singleValueOf(
        appenderWithoutAuth().buildJsonBody([entry()], {}),
      );
      expect(value[0], '1700000000000000000');
      expect(value[1], 'lvl=INFO logger=test - hello');
      expect(value, hasLength(2));
    });

    test('buildJsonBody quotes label values with spaces', () {
      final value = singleValueOf(
        appenderWithoutAuth().buildJsonBody([
          entry(lineLabels: const {'msg': 'has space'}),
        ], const {}),
      );
      expect(value[1], 'msg="has space" - hello');
    });

    test('buildJsonBody renders bare line without line labels', () {
      final value = singleValueOf(
        appenderWithoutAuth().buildJsonBody([
          entry(lineLabels: const {}),
        ], const {}),
      );
      expect(value[1], 'hello');
    });

    test('buildJsonBody level label takes precedence', () {
      final appender = LokiApiAppender.withConfiguration(
        configuration: LokiConfiguration(
          server: 'loki:3100',
          labels: const {'app': 'test', 'level': 'custom'},
        ),
      );
      final body =
          json.decode(appender.buildJsonBody([entry()], const {}))
              as Map<String, dynamic>;
      final streams = body['streams'] as List<dynamic>;
      expect(
        (streams.single as Map<String, dynamic>)['stream'],
        {'app': 'test', 'level': 'INFO'},
      );
    });

    test('buildJsonBody merges equal level names into one stream', () {
      final body =
          json.decode(
                appenderWithoutAuth().buildJsonBody([
                  entry(level: Level('CUSTOM', 850)),
                  entry(level: Level('CUSTOM', 850)),
                ], const {}),
              )
              as Map<String, dynamic>;
      final streams = body['streams'] as List<dynamic>;
      expect(streams, hasLength(1));
      expect(
        (streams.single as Map<String, dynamic>)['stream'],
        {'app': 'test', 'level': 'CUSTOM'},
      );
    });

    test('buildJsonBody attaches userProperties as structured metadata', () {
      final value = singleValueOf(
        appenderWithoutAuth().buildJsonBody([entry()], {'trace': 'abc'}),
      );
      expect(value, hasLength(3));
      expect(value[2], {'trace': 'abc'});
    });

    test('sends nothing for empty batches', () async {
      final appender = TestLokiAppender(configWithoutAuth());
      await appender.sendLogEventsWithHttp(
        [],
        const {},
        Completer<void>().future,
      );
      expect(appender.lastRequest, isNull);
    });

    test('posts push body to push url', () async {
      final appender = TestLokiAppender(
        LokiConfiguration(
          server: 'loki:3100',
          authConfiguration: LokiAuthConfiguration(
            username: 'user',
            password: 'pass',
          ),
          labels: const {'app': 'test'},
        ),
      );
      await appender.sendLogEventsWithHttp(
        [entry()],
        const {},
        Completer<void>().future,
      );
      final request = appender.lastRequest! as http.Request;
      expect(request.method, 'POST');
      expect(request.url.toString(), appender.pushUrl);
      expect(
        request.headers[HttpHeaders.authorizationHeader],
        'Basic dXNlcjpwYXNz',
      );
      final body = json.decode(request.body) as Map<String, dynamic>;
      expect((body['streams'] as List<dynamic>), hasLength(1));
    });
  });
}
