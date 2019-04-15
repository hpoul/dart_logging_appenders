import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

final _logger = Logger('base_logger');

typedef void LogRecordListener(LogRecord rec);

abstract class BaseLogSender {
  Map<String, String> _userProperties = {};

  final int _bufferSize = 500;

  List<LogEntry> _logEvents = <LogEntry>[];
  Timer _timer;

  SimpleJobQueue _sendQueue = SimpleJobQueue();

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
  Stream<void> sendLogEvents(List<LogEntry> logEntries, Map<String, String> userProperties);

  Future<void> _triggerSendLogEvents() =>
    Future(() {
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

  LogRecordListener logListener() => (LogRecord rec) {
        if (rec.loggerName == _logger.fullName && rec.level.value < Level.FINE.value) {
          return;
        }
        final stackTrace = rec.stackTrace ?? (rec.error is Error ? (rec.error as Error).stackTrace : null);
        final message = '${rec.message}${stackTrace != null ? '\n' + stackTrace.toString() : ''}';
//      lokiApiSender.log(rec.time, message);
        final lineLabels = {
          'lvl': rec.level.name,
          'logger': rec.loggerName,
        };
        if (rec.error != null) {
          lineLabels['e'] = rec.error.toString();
          lineLabels['eType'] = rec.error.runtimeType.toString();
        }
        log(rec.time, message, lineLabels);
      };


  Future<void> flush() => _triggerSendLogEvents();
}

abstract class BaseDioLogSender extends BaseLogSender {
  Future<void> sendLogEventsWithDio(
      List<LogEntry> _logEvents, Map<String, String> userProperties, CancelToken cancelToken);

  @override
  Stream<void> sendLogEvents(List<LogEntry> logEntries, Map<String, String> userProperties) {
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
          _logger.warning('Error while sending logs. $message', err, stackTrace);
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

  static final DateFormat _dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
  final DateTime ts;
  final String line;
  final Map<String, String> lineLabels;

  String get tsFormatted => _dateFormat.format(ts.toUtc());
}

typedef Stream<void> SimpleJobRunner(SimpleJobDef job);

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
    _currentStream = Observable.concat(_queue.map((job) => job.runner(job).map((val) => job)).toList()).listen((successJob) {
      _queue.remove(successJob);
      successfulJobs++;
      _logger.finest('Success job. remaining: ${_queue.length} - completed: $successfulJobs');
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

      final int errorWait = 10;
      final minWait = Duration(seconds: errorWait * (_errorCount + 1));
      if (_lastError.difference(DateTime.now()).abs().compareTo(minWait) < 0) {
        _logger.finest('There was an error. waiting at least $minWait');
        if (_queue.length > maxQueueSize) {
          _logger.finest('clearing log buffer. ${_queue.length}');
          _queue.clear();
        }
        return Future.value(null);
      }
    });

    return completer.future;
  }
}
