/// Transport protocol used to reach the Loki server.
enum LokiConnectionType {
  /// Plain HTTP, e.g. for local servers or IP addresses.
  http,

  /// HTTPS. This is the default.
  https,
}
