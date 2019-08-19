import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:rxdart/rxdart.dart';

final _logger = Logger('base_logger');

typedef LogRecordListener = void Function(LogRecord rec);

abstract class BaseLogAppender {
  const BaseLogAppender(LogRecordFormatter formatter)
      : formatter = formatter ?? const DefaultLogRecordFormatter();

  final LogRecordFormatter formatter;

  @protected
  void handle(LogRecord record);

  LogRecordListener logListener() => (LogRecord record) => handle(record);

  void call(LogRecord record) => handle(record);
}

abstract class BaseLogSender extends BaseLogAppender {
  BaseLogSender(
      {LogRecordFormatter formatter = const DefaultLogRecordFormatter()})
      : super(formatter);

  Map<String, String> _userProperties = {};

  final int _bufferSize = 500;

  List<LogEntry> _logEvents = <LogEntry>[];
  Timer _timer;

  final SimpleJobQueue _sendQueue = SimpleJobQueue();

  set userProperties(Map<String, String> userProperties) {
    _userProperties = userProperties;
  }

  Future<void> log(DateTime time, String line, Map<String, String> lineLabels) {
    return _logEvent(LogEntry(ts: time, line: line, lineLabels: lineLabels));
  }

  Future<void> _logEvent(LogEntry log) {
    _timer?.cancel();
    _timer = null;
    _logEvents.add(log);
    if (_logEvents.length > _bufferSize) {
      _triggerSendLogEvents();
    } else {
      _timer = Timer(Duration(seconds: 10), () {
        _timer = null;
        _triggerSendLogEvents();
      });
    }
    return Future.value(null);
  }

  @protected
  Stream<void> sendLogEvents(
      List<LogEntry> logEntries, Map<String, String> userProperties);

  Future<void> _triggerSendLogEvents() => Future(() {
        final entries = _logEvents;
        _logEvents = [];
        _sendQueue.add(SimpleJobDef(
          runner: (job) => sendLogEvents(entries, _userProperties),
        ));
        return _sendQueue.triggerJobRuns().then((val) {
          _logger.finest('Sent log jobs: $val');
          return null;
        });
      });

  @override
  void handle(LogRecord record) {
    // do not print our own logging lines, kind of recursive.
    if (record.loggerName == _logger.fullName &&
        record.level.value < Level.FINE.value) {
      return;
    }
    final message = formatter.format(record);
    final lineLabels = {
      'lvl': record.level.name,
      'logger': record.loggerName,
    };
    if (record.error != null) {
      lineLabels['e'] = record.error.toString();
      lineLabels['eType'] = record.error.runtimeType.toString();
    }
    log(record.time, message, lineLabels);
  }

  Future<void> flush() => _triggerSendLogEvents();
}

abstract class BaseDioLogSender extends BaseLogSender {
  Future<void> sendLogEventsWithDio(List<LogEntry> entries,
      Map<String, String> userProperties, CancelToken cancelToken);

  @override
  Stream<void> sendLogEvents(
      List<LogEntry> logEntries, Map<String, String> userProperties) {
    final CancelToken cancelToken = CancelToken();
    final streamController = StreamController<void>(onCancel: () {
      cancelToken.cancel();
    });
    streamController.onListen = () {
      sendLogEventsWithDio(logEntries, userProperties, cancelToken).then((val) {
        if (!streamController.isClosed) {
          streamController.add(null);
          streamController.close();
        }
      }).catchError((dynamic err, StackTrace stackTrace) {
        String message = err.runtimeType.toString();
        if (err is DioError) {
          if (err.response != null) {
            message = 'response:' + err.response.data?.toString();
          }
          _logger.warning(
              'Error while sending logs. $message', err, stackTrace);
          if (!streamController.isClosed) {
            streamController.addError(err, stackTrace);
            streamController.close();
          }
        }
      });
    };
    return streamController.stream;
  }
}

class LogEntry {
  LogEntry({@required this.ts, @required this.line, @required this.lineLabels});

  static final DateFormat _dateFormat =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
  final DateTime ts;
  final String line;
  final Map<String, String> lineLabels;

  String get tsFormatted => _dateFormat.format(ts.toUtc());
}

typedef SimpleJobRunner = Stream<void> Function(SimpleJobDef job);

class SimpleJobDef {
  SimpleJobDef({@required this.runner});

  final SimpleJobRunner runner;
}

class SimpleJobQueue {
  SimpleJobQueue({this.maxQueueSize = 100});

  final int maxQueueSize;

  final Queue<SimpleJobDef> _queue = Queue<SimpleJobDef>();

  StreamSubscription<SimpleJobDef> _currentStream;

  int _errorCount = 0;
  DateTime _lastError;

  void add(SimpleJobDef job) {
    _queue.addLast(job);
  }

  Future<int> triggerJobRuns() {
    if (_currentStream != null) {
      _logger.info('Already running jobs. Ignoring trigger.');
      return Future.value(0);
    }
    _logger.finest('Triggering Job Runs. ${_queue.length}');
    final Completer<int> completer = Completer();
    int successfulJobs = 0;
//    final job = _queue.removeFirst();
    _currentStream = Observable.concat(
            _queue.map((job) => job.runner(job).map((val) => job)).toList())
        .listen((successJob) {
      _queue.remove(successJob);
      successfulJobs++;
      _logger.finest(
          'Success job. remaining: ${_queue.length} - completed: $successfulJobs');
    }, onDone: () {
      _logger.finest('All jobs done.');
      _errorCount = 0;
      _lastError = null;

      _currentStream = null;
      completer.complete(successfulJobs);
    }, onError: (dynamic error, StackTrace stackTrace) {
      _logger.warning('Error while executing job', error, stackTrace);
      _errorCount++;
      _lastError = DateTime.now();
      _currentStream.cancel();
      _currentStream = null;
      completer.completeError(error, stackTrace);

      const int errorWait = 10;
      final minWait =
          Duration(seconds: errorWait * (_errorCount * _errorCount + 1));
      if (_lastError.difference(DateTime.now()).abs().compareTo(minWait) < 0) {
        _logger.finest('There was an error. waiting at least $minWait');
        if (_queue.length > maxQueueSize) {
          _logger.finest('clearing log buffer. ${_queue.length}');
          _queue.clear();
        }
      }
      return Future.value(null);
    });

    return completer.future;
  }
}
