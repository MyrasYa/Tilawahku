import 'dart:async';

class SleepTimerController {
  SleepTimerController({
    required Future<void> Function() onExpire,
    required void Function(Object error, StackTrace stackTrace) onError,
    DateTime Function()? now,
  }) : _onExpire = onExpire,
       _onError = onError,
       _now = now ?? DateTime.now;

  final Future<void> Function() _onExpire;
  final void Function(Object error, StackTrace stackTrace) _onError;
  final DateTime Function() _now;
  final StreamController<Duration?> _remainingController =
      StreamController<Duration?>.broadcast();
  Timer? _timer;
  DateTime? _deadline;

  DateTime? get deadline => _deadline;

  Stream<Duration?> get remainingStream => _remainingController.stream;

  Duration? get remaining => _remainingUntilDeadline();

  void start(Duration duration) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive.');
    }

    _timer?.cancel();
    _deadline = _now().add(duration);
    _publishRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => checkDeadline());
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _remainingController.add(null);
  }

  void checkDeadline() {
    final deadline = _deadline;
    if (deadline == null) return;

    final remaining = deadline.difference(_now());
    if (remaining <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      _deadline = null;
      _remainingController.add(null);
      unawaited(_expire());
      return;
    }

    _remainingController.add(
      Duration(seconds: (remaining.inMilliseconds + 999) ~/ 1000),
    );
  }

  Duration? _remainingUntilDeadline() {
    final deadline = _deadline;
    if (deadline == null) return null;
    final remaining = deadline.difference(_now());
    if (remaining <= Duration.zero) return Duration.zero;
    return Duration(seconds: (remaining.inMilliseconds + 999) ~/ 1000);
  }

  void _publishRemaining() {
    _remainingController.add(_remainingUntilDeadline());
  }

  Future<void> _expire() async {
    try {
      await _onExpire();
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  Future<void> dispose() async {
    cancel();
    await _remainingController.close();
  }
}
