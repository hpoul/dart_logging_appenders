import 'dart:io';

import 'package:logging_appenders/src/logrecord_formatter.dart';

LogRecordFormatter defaultLogRecordFormatter() => stdout.supportsAnsiEscapes
    ? const ColorFormatter()
    : const DefaultLogRecordFormatter();
