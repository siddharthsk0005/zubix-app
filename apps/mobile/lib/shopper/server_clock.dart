/// Counts down against the server's clock, so a wrong phone clock does not
/// unlock a coupon early or late.
class ServerClock {
  ServerClock(DateTime serverTime, {DateTime? localNow})
      : _offset = serverTime.difference(localNow ?? DateTime.now());

  final Duration _offset;

  DateTime now({DateTime? localNow}) => (localNow ?? DateTime.now()).add(_offset);

  /// Whole seconds left until [target], rounded up and never negative.
  int secondsUntil(DateTime target, {DateTime? localNow}) {
    final ms = target.difference(now(localNow: localNow)).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }
}
