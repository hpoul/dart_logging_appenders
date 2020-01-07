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
