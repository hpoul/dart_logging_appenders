# logging_appenders

[![Pub](https://img.shields.io/pub/v/logging_appenders.svg?color=green)](https://pub.dartlang.org/packages/logging_appenders)
[![codecov](https://codecov.io/gh/hpoul/dart_logging_appenders/branch/master/graph/badge.svg)](https://codecov.io/gh/hpoul/dart_logging_appenders)


Native dart package for logging appenders usable with the [logging](https://pub.dartlang.org/packages/logging) package.

It currently includes appenders for:

* Local Logging
    * `print()` [PrintAppender](https://pub.dev/documentation/logging_appenders/latest/logging_appenders/PrintAppender-class.html)
    * Rolling File Appender. [RotatingFileAppender](https://pub.dev/documentation/logging_appenders/latest/logging_appenders/RotatingFileAppender-class.html)
* Remote Logging
    * [logz.io](https://logz.io/) 
    * [loki](https://github.com/grafana/loki).

## Performance of Remote Logging Appenders

I am not sure if it is wise to use this in production, but it's great during beta testing with
a handful of users so you have all logs available.

It tries to stay reasonable performant by batching log entries and sending them off only every few
seconds. If network is down it will retry later. (with an ever increasing interval).

# Getting Started

After installing package `logging` and `logging_appenders`:

```dart
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';

final _logger = Logger('main');

void main() {
  Logger.root.level = Level.ALL;
  PrintAppender()..attachToLogger(Logger.root);
  _logger.fine('Lorem ipsum');
}
```

Outputs:

```
$ dart main.dart
2019-08-19 15:36:03.827563 FINE main - Lorem ipsum
```



