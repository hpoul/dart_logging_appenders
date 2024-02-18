// based on https://github.com/dart-lang/language/issues/2119#issuecomment-1042365842

final Expando<ErrorStack> _causedBy = Expando();
T _wasCausedBy<T extends Exception>(
    T target, Object cause, StackTrace causeStackTrace) {
  _causedBy[target] = (error: cause, stack: causeStackTrace);
  return target;
}

typedef ErrorStack = ({Object error, StackTrace stack});

/// Allow exception chaining.
/// example:
/// ```
/// try {
///   ...
/// } on Exception (e, stackTrace) {
///   throw
/// }
extension CausedByException<E extends Exception> on E {
  E causedBy(Object chainedException, StackTrace stackTrace) =>
      _wasCausedBy(this, chainedException, stackTrace);
  ErrorStack? getCausedByException() => _causedBy[this];

  String toStringWithCause() {
    final cause = this.getCausedByException();
    if (cause == null) {
      return toString();
    }
    final error = cause.error;
    final causeToString =
        error is Exception ? error.toStringWithCause() : error.toString();
    return '${toString()} cause: {$causeToString}';
  }
}
