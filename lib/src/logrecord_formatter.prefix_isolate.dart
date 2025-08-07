import 'dart:isolate';

String? isolatePrefix() => '[${Isolate.current.debugName ?? 'unnamed'}] ';
