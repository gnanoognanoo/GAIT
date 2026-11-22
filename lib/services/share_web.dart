import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';
import 'package:web/web.dart' as web;

Future<void> shareFile(
  Uint8List bytes,
  String filename,
  String mime,
  Rect origin,
) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
}
