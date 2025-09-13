import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:meta/meta.dart';

final _logger = DummyLogger('logging_appenders.rotating_file_appender');

/// A file appender which will rotate the log file once it reaches
/// [rotateAtSizeBytes] bytes. Will keep [keepRotateCount] number of
/// files.
/// If the [baseFilePath] cannot be calculated synchronously you can use
/// a [AsyncInitializingLogHandler] to buffer log messages until the
/// [baseFilePath] is ready.
class RotatingFileAppender extends BaseLogAppender {
  RotatingFileAppender({
    LogRecordFormatter? formatter,
    required this.baseFilePath,
    this.keepRotateCount = 3,
    this.rotateAtSizeBytes = 10 * 1024 * 1024,
    this.rotateCheckInterval = const Duration(minutes: 5),
    this.clock = const Clock(),
  }) : super(formatter) {
    _outputFile = File(baseFilePath);
    if (!_outputFile.parent.existsSync()) {
      throw StateError(
        'When initializing file logger, ${_outputFile.parent} must exist.',
      );
    }
    _maybeRotate();
  }

  @visibleForTesting
  static Logger get debugLogger => _logger;

  /// (Absolute) path to base file (ie. the current log file).
  final String baseFilePath;

  /// the number of rotated files to keep.
  /// e.g. if this is 3 we will create `filename`, `filename.1`, `filename.2`.
  final int keepRotateCount;

  /// The size in bytes we allow a file to grow before rotating it.
  final int rotateAtSizeBytes;
  final Duration rotateCheckInterval;

  /// how long to keep log file open. will be closed once this duration
  /// passed without a log message.
  final Duration keepOpenDuration = const Duration(minutes: 2);
  final Clock clock;

  // immediately check on rotate when creating appender.
  DateTime? _nextRotateCheck = DateTime.now();
  late File _outputFile;
  IOSink? _outputFileSink;
  Timer? _closeAndFlushTimer;

  /// Returns all available rotated logs, starting from the most current one.
  List<File> getAllLogFiles() =>
      Iterable.generate(keepRotateCount, (idx) => idx)
          .map((rotation) => _fileNameForRotation(rotation))
          .map((fileName) => File(fileName))
          .takeWhile((file) => file.existsSync())
          .toList(growable: false);

  IOSink _getOpenOutputFileSink() =>
      _outputFileSink ??= _outputFile.openWrite(mode: FileMode.append)
        ..done.catchError((Object error, StackTrace stackTrace) {
          print('error while writing to logging file.');
          _logger.warning(
            'Error while writing to logging file.',
            error,
            stackTrace,
          );
          return Future<dynamic>.error(error, stackTrace);
        });

  static int id = 0;
  final int instanceId = id++;

  @override
  void handle(LogRecord record) {
    if (record.loggerName == _logger.fullName) {
      // ignore my own log messages.
      return;
    }
    try {
      _getOpenOutputFileSink().writeln(formatter.format(record));
    } catch (error, stackTrace) {
      print('error while writing log $error $stackTrace');
      _logger.warning('Error while writing log.', error, stackTrace);
      _closeAndFlush();
      // try once more.
      _getOpenOutputFileSink().writeln(formatter.format(record));
    }
    _closeAndFlushTimer?.cancel();
    _closeAndFlushTimer = Timer(keepOpenDuration, () {
      _closeAndFlush();
    });
    //    _outputFile.writeAsString(
    //        (formatter.formatToStringBuffer(record, StringBuffer())..writeln())
    //            .toString(),
    //        mode: FileMode.append);
    _maybeRotate();
  }

  String _fileNameForRotation(int rotation) =>
      rotation == 0 ? baseFilePath : '$baseFilePath.$rotation';

  /// rotates the file, if it is larger than [rotateAtSizeBytes]
  Future<bool> _maybeRotate() async {
    if (_nextRotateCheck?.isAfter(clock.now()) != false) {
      return false;
    }
    _nextRotateCheck = null;
    try {
      try {
        final length = await File(_outputFile.path).length();
        if (length < rotateAtSizeBytes) {
          return false;
        }
      } on FileSystemException catch (_) {
        // if .length() throws an error, ignore it.
        return false;
      } catch (e, stackTrace) {
        _logger.warning('Error while checking file length.', e, stackTrace);
        rethrow;
      }

      Future<void>? flushFuture;
      for (var i = keepRotateCount - 1; i >= 0; i--) {
        final file = File(_fileNameForRotation(i));
        if (file.existsSync()) {
          try {
            await file.rename(_fileNameForRotation(i + 1));
          } on FileSystemException catch (_) {
            if (i == 0) {
              // open file can't be renamed on Windows, so close file and retry
              flushFuture = _closeAndFlush();
              await flushFuture;
              await file.rename(_fileNameForRotation(i + 1));
            } else {
              rethrow;
            }
          }
        }
      }

      // initiate flush if not already running
      flushFuture ??= _closeAndFlush();
      handle(LogRecord(Level.INFO, 'Rotated log.', '_'));
      await flushFuture;
      return true;
    } finally {
      _nextRotateCheck = clock.now().add(rotateCheckInterval);
    }
  }

  Future<void> _closeAndFlush() async {
    _closeAndFlushTimer?.cancel();
    _closeAndFlushTimer = null;
    if (_outputFileSink != null) {
      try {
        final oldSink = _outputFileSink!;
        _outputFileSink = null;
        await oldSink.flush();
        await oldSink.close();
      } catch (e, stackTrace) {
        _logger.warning('Error while flushing, closing stream.', e, stackTrace);
      }
    }
  }

  @visibleForTesting
  Future<void> forceFlush() async {
    await _closeAndFlush();
  }

  @override
  Future<void> dispose() async {
    await _closeAndFlush();
    await super.dispose();
  }
}

/// A wrapper LogHandler which will buffer log records until the future provided by
/// the [builder] method has resolved.
class AsyncInitializingLogHandler<T extends BaseLogAppender>
    extends BaseLogAppender {
  AsyncInitializingLogHandler({required this.builder})
    : delegatedLogHandlerAsync = builder(),
      super(null) {
    delegatedLogHandlerAsync.then((newLogHandler) {
      delegatedLogHandler = newLogHandler;
      _bufferedLogRecords?.forEach(handle);
      _bufferedLogRecords = null;
      return newLogHandler;
    });
  }

  List<LogRecord>? _bufferedLogRecords = [];
  Future<T> Function() builder;
  T? delegatedLogHandler;
  final Future<T> delegatedLogHandlerAsync;

  @override
  void handle(LogRecord record) {
    if (delegatedLogHandler case final delegatedLogHandler?) {
      return delegatedLogHandler.handle(record);
    }
    _bufferedLogRecords!.add(record);
  }
}
