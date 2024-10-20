enum LokiConnectionType {
  http('http'),
  https('https');
  final String value;

  const LokiConnectionType(this.value);
}