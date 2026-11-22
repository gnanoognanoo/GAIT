import 'dart:async';
import 'dart:js_interop';

@JS('kinetiqSerialSupported')
external bool get serialSupported;
@JS('kinetiqOpenSerial')
external JSPromise<JSAny?> _open(int baud, JSFunction line, JSFunction end);
@JS('kinetiqCloseSerial')
external void _close();

Future<Stream<String>> openSerial(int baud) async {
  final controller = StreamController<String>(onCancel: () => _close());
  await _open(
    baud,
    ((JSString line) {
      if (!controller.isClosed) controller.add(line.toDart);
    }).toJS,
    (() {
      controller.close();
    }).toJS,
  ).toDart;
  return controller.stream;
}
