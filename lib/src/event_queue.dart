import 'dart:async';

import 'package:scout_models/scout_models.dart';

import 'ingest_client.dart';

class EventQueue {
  EventQueue({
    required this.client,
    required this.maxBatch,
    required this.flushInterval,
    this.onError,
  });

  final IngestClient client;
  final int maxBatch;
  final Duration flushInterval;
  final void Function(Object error)? onError;

  final List<IngestEvent> _pending = [];
  Timer? _timer;
  bool _flushing = false;

  void start() => _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void add(IngestEvent event, {bool urgent = false}) {
    _pending.add(event);
    if (urgent || _pending.length >= maxBatch) unawaited(flush());
  }

  Future<void> flush() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    final batch = List<IngestEvent>.from(_pending);
    _pending.clear();
    try {
      final ok = await client.send(batch);
      if (!ok) _pending.insertAll(0, batch);
    } catch (e, st) {
      _pending.insertAll(0, batch);
      onError?.call(e);
      assert(() {
        // ignore: avoid_print
        print('scout_logger_plus flush failed: $e\n$st');
        return true;
      }());
    } finally {
      _flushing = false;
    }
  }
}
