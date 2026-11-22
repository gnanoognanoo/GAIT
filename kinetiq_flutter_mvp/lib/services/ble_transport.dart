import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_ble/universal_ble.dart';
import 'ble_protocol.dart';
export 'ble_protocol.dart';

class WearableLink {
  WearableLink(this.id, this.statusChanged);
  final String id;
  final void Function(String, bool) statusChanged;
  bool streaming = true,
      ready = false,
      _cancelled = false,
      _calibrating = false;
  static const timeout = Duration(seconds: 8);
  final _stop = Completer<void>();
  WearableHealth? health;

  Future<void> command(WearableCommand command) async {
    await UniversalBle.write(
      id,
      motionServiceId,
      controlCharacteristicId,
      Uint8List.fromList([command.index + 1]),
      timeout: timeout,
    );
    if (command == WearableCommand.start) streaming = true;
    if (command == WearableCommand.stop) {
      streaming = false;
      statusChanged('Streaming paused', false);
    }
    if (command == WearableCommand.calibrate) {
      _calibrating = true;
      statusChanged('Hold band still for calibration', false);
    }
  }

  Stream<String> subscribe() {
    late StreamController<String> out;
    Future<void> run() async {
      for (int attempt = 0; !_cancelled && attempt < 4; attempt++) {
        final lost = Completer<void>(),
            subscriptions = <StreamSubscription<dynamic>>[];
        final pairs = FramePairer(), clock = Stopwatch()..start();
        Timer? watchdog;
        int statusAt = 0, pairAt = 0, lastEmit = -100, previousLosses = 0;
        String? lastActivity;
        bool previouslyValid = false;
        void finish() {
          if (!lost.isCompleted) lost.complete();
        }

        void bad(String reason) {
          if (!_cancelled) statusChanged(reason, false);
          previouslyValid = false;
        }

        void onStatus(Uint8List value) {
          if (_cancelled) return;
          final h = WearableHealth.decode(value);
          health = h;
          statusAt = clock.elapsedMilliseconds;
          if (h.code != 0) {
            _calibrating = false;
            bad(h.label);
          } else if (!streaming) {
            bad('Streaming paused');
          }
        }

        void onPart(Uint8List value, bool orientation) {
          if (_cancelled || !streaming) return;
          final pair = pairs.add(
            TelemetryPart.decode(value, orientation: orientation),
            orientation: orientation,
          );
          if (pair == null) return;
          final (raw, rotation) = pair;
          final h = health;
          if (!raw.ready || h == null || h.code != 0 || _calibrating) return;
          pairAt = clock.elapsedMilliseconds;
          final statusMatches = ((raw.stamp - h.stamp) & 0xffffffff) < 1000;
          final activity = raw.orienting
              ? 'UNKNOWN'
              : (raw.flags & 8) != 0
              ? 'HIGH'
              : (raw.flags & 4) == 0
              ? 'STATIONARY'
              : statusMatches && h.activity == 2
              ? 'ACTIVE'
              : statusMatches && h.activity == 1
              ? 'LOW'
              : 'UNKNOWN';
          if (pairs.losses != previousLosses) {
            previousLosses = pairs.losses;
            bad('Telemetry discontinuity');
          }
          if (pairAt - lastEmit < 100 &&
              lastActivity == activity &&
              previouslyValid) {
            return;
          }
          lastActivity = activity;
          lastEmit = pairAt;
          previouslyValid = true;
          final quality =
              (100 * pairs.received / (pairs.received + pairs.losses)).round();
          statusChanged(
            'Live · $quality% paired${raw.overrange ? ' · gyro range limit' : ''}',
            true,
          );
          const names = ['ax', 'ay', 'az', 'gx', 'gy', 'gz'];
          out.add(
            jsonEncode({
              'motion': activity,
              for (int i = 0; i < 6; i++)
                if (i < 3 || !raw.overrange) names[i]: raw.values[i],
              if (statusMatches && !raw.orienting) 'intensity': h.intensity,
              if (!rotation.orienting) 'quaternion': rotation.values,
              'deviceTime': raw.stamp,
              'event': h.event,
            }),
          );
        }

        void listen(String characteristic, void Function(Uint8List) decode) {
          subscriptions.add(
            UniversalBle.characteristicValueStream(id, characteristic).listen(
              (value) {
                try {
                  decode(value);
                } on FormatException {
                  bad('Invalid wearable packet');
                }
              },
              onError: (_) => finish(),
              onDone: finish,
            ),
          );
        }

        try {
          bad(
            attempt == 0
                ? 'Connecting to wearable'
                : 'Reconnecting to wearable',
          );
          await UniversalBle.connect(id, timeout: timeout);
          if (_cancelled) break;
          subscriptions.add(
            UniversalBle.connectionStream(id).listen((connected) {
              if (!connected) finish();
            }, onError: (_) => finish()),
          );
          await UniversalBle.discoverServices(id, timeout: timeout);
          if (_cancelled) break;
          listen(statusCharacteristicId, onStatus);
          listen(rawCharacteristicId, (v) => onPart(v, false));
          listen(orientationCharacteristicId, (v) => onPart(v, true));
          for (final c in [
            statusCharacteristicId,
            rawCharacteristicId,
            orientationCharacteristicId,
          ]) {
            await UniversalBle.subscribeNotifications(
              id,
              motionServiceId,
              c,
              timeout: timeout,
            );
          }
          if (_cancelled) break;
          ready = true;
          _calibrating = false;
          health = null;
          await command(WearableCommand.status);
          await command(
            streaming ? WearableCommand.start : WearableCommand.stop,
          );
          statusAt = pairAt = clock.elapsedMilliseconds;
          watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
            final now = clock.elapsedMilliseconds;
            if (now - statusAt > 4000) {
              finish();
              return;
            }
            if (streaming && health?.code == 0 && now - pairAt > 1500) {
              bad('Telemetry stale');
              if (now - pairAt > 4000) finish();
            }
          });
          await Future.any([lost.future, _stop.future]);
          if (clock.elapsedMilliseconds > 15000) attempt = -1;
        } catch (_) {
          /* Re-discover after transient failures. */
        } finally {
          ready = false;
          watchdog?.cancel();
          for (final sub in subscriptions) {
            await sub.cancel();
          }
          try {
            await UniversalBle.disconnect(id, timeout: timeout);
          } catch (_) {}
        }
        if (!_cancelled) {
          await Future.any([
            Future<void>.delayed(const Duration(seconds: 2)),
            _stop.future,
          ]);
        }
      }
      if (!_cancelled) {
        out.addError(StateError('Wearable unavailable'));
        await out.close();
      }
    }

    out = StreamController<String>(
      onListen: run,
      onCancel: () {
        _cancelled = true;
        if (!_stop.isCompleted) _stop.complete();
      },
    );
    return out.stream;
  }
}
