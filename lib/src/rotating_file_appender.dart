// ignore_for_file: implementation_imports

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
          'When initializing file logger, ${_outputFile.parent} must exist.');
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
          _logger.warning(
              'Error while writing to logging file.', error, stackTrace);
          return Future<dynamic>.error(error, stackTrace);
        });

  static int id = 0;
  final int instanceId = id++;

  final List<String> _rotateBuffer = <String>[];
  bool _inFlushAndClose = false;

  @override
  void handle(LogRecord record) {
    if (record.loggerName == _logger.fullName) {
      // ignore my own log messages.
      return;
    }
    final rotating = _nextRotateCheck == null || _inFlushAndClose;
    if (rotating) {
      _rotateBuffer.add(formatter.format(record));
      return;
    } else if (_rotateBuffer.isNotEmpty) {
      final sink = _getOpenOutputFileSink();
      for (final line in _rotateBuffer) {
        sink.writeln(line);
      }
      _rotateBuffer.clear();
    }
    try {
      _getOpenOutputFileSink().writeln(formatter.format(record));
    } catch (error, stackTrace) {
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
      // Rotate the file if it can be read & reached its size limit
      var rotate = false;
      try {
        if (await File(_outputFile.path).length() > rotateAtSizeBytes) {
          rotate = true;
        }
      } catch (e, stackTrace) {
        _logger.warning('Error while checking file length.', e, stackTrace);
      }
      if (!rotate) {
        return false;
      }

      // Rotate files that are not currently used
      for (var i = keepRotateCount - 1; i >= 1; i--) {
        final file = File(_fileNameForRotation(i));
        if (file.existsSync()) {
          await file.rename(_fileNameForRotation(i + 1));
        }
      }

      // Close file before renaming the last, currently-in-use file
      await _closeAndFlush();

      // Rename the last file
      final file = File(_fileNameForRotation(0));
      if (file.existsSync()) {
        await file.rename(_fileNameForRotation(1));
      }

      handle(LogRecord(Level.INFO, 'Rotated log.', '_'));
      return true;
    } finally {
      _nextRotateCheck = clock.now().add(rotateCheckInterval);
    }
  }

  Future<void> _closeAndFlush() async {
    _closeAndFlushTimer?.cancel();
    _closeAndFlushTimer = null;

    // It can happen that the first log entries are put in a buffer without the sink being opened.
    // Open the sink in this case, so buffered data gets written and flushed.
    if (_rotateBuffer.isNotEmpty) _getOpenOutputFileSink();

    if (_outputFileSink != null) {
      try {
        final oldSink = _outputFileSink!;
        for (final line in _rotateBuffer) {
          oldSink.writeln(line);
        }
        _rotateBuffer.clear();

        _outputFileSink = null;
        _inFlushAndClose = true;
        await oldSink.flush();
        await oldSink.close();
        _inFlushAndClose = false;
      } catch (e, stackTrace) {
        _inFlushAndClose = false;
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
      _bufferedLogRecords!.forEach(handle);
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
    if (delegatedLogHandler != null) {
      return delegatedLogHandler!.handle(record);
    }
    _bufferedLogRecords!.add(record);
  }
}
