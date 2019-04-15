# remote_logging_handlers

Native dart package for handlers of the [logging](https://pub.dartlang.org/packages/logging) for
[logz](https://logz.io/) and [loki](https://github.com/grafana/loki).

# Performance

I am not sure if it is wise to use this in production, but it's great during beta testing with
a handful of users so you have all logs available.

It tries to stay reasonable performant by batching log entries and sending them off only every few
seconds. If network is down it will retry later. (with an ever increasing interval).

## Getting Started

