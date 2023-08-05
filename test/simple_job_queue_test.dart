import 'dart:io';

import 'package:logging_appenders/base_remote_appender.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('SimpleJobQueue', () async {
    final queue = SimpleJobQueue();
    queue.add(SimpleJobDef(runner: (job) async* {
      print('first queue item..');
      sleep(Duration(milliseconds: 10));
      print('first queue item..DONE');
    }));
    queue.add(SimpleJobDef(runner: (job) async* {
      print('second queue item..');
      sleep(Duration(milliseconds: 5));
      print('second queue item..DONE');
    }));
    final done = await queue.triggerJobRuns();
    print('done: $done, remaining: ${queue.length}');
    expect(done, 2);
    expect(queue.length, 0);
  });
}
