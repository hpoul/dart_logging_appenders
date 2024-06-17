## 1.3.1

* Default formatter: add support for printing `cause` of [JsonUnsupportedObjectError]

## 1.3.0

* Support for exception chaining.
* Allow closing of subscriptions without disposing. `detachFromLoggers`

## 1.2.0+1

* Graylog: Send timestamp with decimal places.
* Require at least Dio 5.2.0

## 1.2.0

* Support for gelf / Graylog appender.
* Fix concurrent modification exception (thanks @andreacimino #23)

## 1.1.0

* Support logging 1.2.0 package.

## 1.0.2

* Fix RotatingFileAppender on windows #15 / #18

## 1.0.1

* Allow dio 5.x

## 1.0.0+2

* Update dependencies.

## 1.0.0+1

* AsyncInitializingLogHandler: Allow access to underlying async handler.

## 1.0.0

* Support for null safety

## 0.4.3+1

* Fix concurrent modification #9 thanks @rvasqz86

## 0.4.3

* Remove dependency on rxdart.
* Loki: use UTC for all timestamps (thanks @hsmade) 

## 0.4.3-dev.1

* Remove dependency on rxdart.

## 0.4.2+5

* Improve documentation
* Add possibility to log to stderr.
  ```dart
  PrintAppender.setupLogging(stderrLevel: Level.SEVERE);
  ```

## 0.4.2+4

* Add error `runtimeType` to default log output.

## 0.4.2+3

* fix passing along level on PrintAppender.setupLogging

## 0.4.2+2

* Slightly improve the default formatting of errors/stack traces.

## 0.4.2 (and 0.4.2+1)

* Separated PrintAppender initializer into a default and a dart:io file, so
  to remove dependency on `dart:io`.
* Created a `PrintAppender.setupLogging()` method which configures the root logger.

## 0.4.1

* Expose `BaseLogSender` and similar classes required to build custom log senders.

## 0.4.0

* Upgrade to dio 3.x

## 0.3.0

* Upgraded to rxdart 0.23

## 0.2.2

* Added a `ColorFormatter` when outputting to interactive terminal.
    * If `stdout.supportsAnsiEscapes` returns true, the `PrintAppender`
      will default to `ColorFormatter`
* Correctly dispose close timer.

## 0.2.1+1

* Make `LogzIoApiAppender` more configurable (host, type, bufferSize, etc.).
* Make internal logging levels configurable, to help debugging the Appenders themselves.

## 0.2.1

* Improved API, use `attachToLogger`.
* Updated documentation, improved readme
* More test coverage for `RotatingFileAppender`

## [0.2.0] - 2019-08-19

* Renamed everything from `handler` to `appender`.
* Major refactoring.

## [0.1.0+2] - 2019-04-20 hotfix
## [0.1.0+1] - 2019-04-20 broaden dependencies for 0.x versions.

## [0.1.0] - 2019-04-20 initial release

* Initial release with logz.io and loki logging backends.
