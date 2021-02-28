import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'test_utils.dart';

@isTest
void tempDirTest<T>(
    String description, Future<T> Function(Directory dir) callback) {
  test(description, () async {
    final dirName = description.replaceAll(RegExp('[^A-Za-z0-9]+'), '_');
    final dir = await Directory.systemTemp.createTemp('dartlang_test_$dirName');
    try {
      await callback(dir);
      await dir.delete(recursive: true);
    } catch (e) {
      print('Test failed, not deleting test directory ${dir.absolute.path}');
      rethrow;
    }
  });
}

LogRecord _logRecord(String message) => TestUtils.logRecord(message);

class MockLockAppender extends Mock implements BaseLogAppender {
  @override
  void handle(LogRecord? record) =>
      super.noSuchMethod(Invocation.method(#handle, [record]));
}

void main() {
  hierarchicalLoggingEnabled = true;
  LoggingAppenders.internalLogLevel = Level.ALL;

  tempDirTest('simple write test', (dir) async {
    final logFile = path.join(dir.path, 'app.log');
    final appender = RotatingFileAppender(baseFilePath: logFile);
    appender.handle(LogRecord(Level.FINE, 'foo', 'foo'));
    appender.handle(LogRecord(Level.FINE, 'bar', 'bar'));
    await appender.dispose();
    final content = await File(logFile).readAsString();
    final lines = content.trim().split('\n');
    expect(lines[0], endsWith('foo'));
    expect(lines[1], endsWith('bar'));
  });

  tempDirTest('Check rotate', (dir) async {
    final logFile = path.join(dir.path, 'app.log');
//    fakeAsync((async) {
    print('clock: ${clock.now()} XXX ${_logRecord('blubb')}');

    final appender = RotatingFileAppender(
      baseFilePath: logFile,
      rotateAtSizeBytes: 5,
      rotateCheckInterval: Duration.zero,
    );
    expect(File(logFile).existsSync(), false);
    expect(File(logFile + '.1').existsSync(), false);
    appender.handle(_logRecord('foo'));
    appender.handle(_logRecord('bar'));
    await appender.forceFlush();
    expect(appender.getAllLogFiles(), hasLength(1));
    appender.handle(_logRecord('baz'));
    await Future<dynamic>.delayed(const Duration(milliseconds: 100));
    expect(appender.getAllLogFiles(), hasLength(2));
    expect(File(logFile).existsSync(), true);
    expect(File(logFile + '.1').existsSync(), true);
    appender.handle(_logRecord('bar'));
//    }, initialTime: DateTime(2018));
    await Future<dynamic>.delayed(const Duration(milliseconds: 100));
    await _debugFiles(dir);
    await appender.dispose();
  });

  tempDirTest('test async initialization', (dir) async {
    fakeAsync((async) {
      final logAppenderCompleter = Completer<BaseLogAppender>();
      final mockAppender = MockLockAppender();
      final appender = AsyncInitializingLogHandler(
        builder: () async => await logAppenderCompleter.future,
      );

      appender.handle(_logRecord('foo'));
      async.flushMicrotasks();
      verifyNever(mockAppender.handle(any));

      logAppenderCompleter.complete(mockAppender);
      async.flushMicrotasks();
      verify(mockAppender.handle(any)).called(1);
    });
  });
}

Future<void> _debugFiles(Directory dir) async {
  print('Contents of $dir:');

  await for (final entry in dir.list(recursive: true)) {
    print(
        '    ${path.relative(entry.path, from: dir.path)}:\n      | ${File(entry.path).readAsStringSync().split('\n').join('\n      | ')}\n\n');
  }
  print('\n============================');
}
