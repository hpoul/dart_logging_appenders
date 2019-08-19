import 'dart:io';

import 'package:clock/clock.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';

class RotatingFileAppender extends BaseLogAppender {
  RotatingFileAppender({
    LogRecordFormatter formatter,
    @required this.baseFilePath,
    this.keepRotateCount = 3,
    this.rotateAtSizeBytes = 10 * 1024 * 1024,
    this.clock = const Clock(),
  })  : assert(baseFilePath != null),
        super(formatter) {
    _outputFile = File(baseFilePath);
    if (!_outputFile.parent.existsSync()) {
      throw StateError(
          'When initializing file logger, ${_outputFile.parent} must exist.');
    }
    _maybeRotate();
  }

  final String baseFilePath;
  final int keepRotateCount;
  final int rotateAtSizeBytes;
  final Duration rotateCheckInterval = const Duration(minutes: 5);
  final Clock clock;
  DateTime _nextRotateCheck;
  File _outputFile;

  /// Returns all available rotated logs, starting from the most current one.
  List<File> getAllLogFiles() =>
      Iterable.generate(keepRotateCount, (idx) => idx)
          .map((rotation) => _fileNameForRotation(rotation))
          .map((fileName) => File(fileName))
          .takeWhile((file) => file.existsSync())
          .toList(growable: false);

  @override
  void handle(LogRecord record) {
    _outputFile.writeAsString(
        (formatter.formatToStringBuffer(record, StringBuffer())..writeln())
            .toString(),
        mode: FileMode.append);
    _maybeRotate();
  }

  String _fileNameForRotation(int rotation) =>
      rotation == 0 ? baseFilePath : '$baseFilePath.$rotation';

  /// rotates the file, if it is larger than
  Future<bool> _maybeRotate() async {
    if (_nextRotateCheck?.isAfter(clock.now()) == true) {
      return false;
    }
    _nextRotateCheck = clock.now().add(rotateCheckInterval);
    try {
      final length = await _outputFile.length();
      if (length < rotateAtSizeBytes) {
        return false;
      }
    } on FileSystemException catch (_) {
      // if .length() throws an error, ignore it.
      return false;
    }
    for (int i = keepRotateCount - 1; i >= 0; i--) {
      final file = File(_fileNameForRotation(i));
      if (file.existsSync()) {
        await file.rename(_fileNameForRotation(i + 1));
      }
    }
    return true;
  }
}

/// A wrapper LogHandler which will buffer log records until the future provided by
/// the [builder] method has resolved.
class AsyncInitializingLogHandler<T extends BaseLogAppender>
    extends BaseLogAppender {
  AsyncInitializingLogHandler({this.builder}) : super(null) {
    this.builder().then((newLogHandler) {
      delegatedLogHandler = newLogHandler;
      _bufferedLogRecords.forEach(handle);
      _bufferedLogRecords = null;
    });
  }

  List<LogRecord> _bufferedLogRecords = [];
  Future<T> Function() builder;
  T delegatedLogHandler;

  @override
  void handle(LogRecord record) {
    if (delegatedLogHandler != null) {
      return delegatedLogHandler.handle(record);
    }
    _bufferedLogRecords.add(record);
  }
}
