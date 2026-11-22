import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS()
extension type _Model(web.HTMLElement element) implements JSObject {
  external JSObject? get model;
  external void play();
  external void pause();
  external set currentTime(double t);
}
@JS()
extension type _Scene(JSObject object) implements JSObject {
  external _Material getMaterialByName(String name);
}
@JS()
extension type _Material(JSObject object) implements JSObject {
  external _Pbr get pbrMetallicRoughness;
}
@JS()
extension type _Pbr(JSObject object) implements JSObject {
  external void setBaseColorFactor(JSArray<JSNumber> color);
}

class LegView extends StatefulWidget {
  const LegView({super.key, required this.high, required this.alert});
  final bool high, alert;
  @override
  State<LegView> createState() => _LegViewState();
}

class _LegViewState extends State<LegView> {
  _Model? model;
  bool failed = false;
  void sync() {
    final m = model, scene = m?.model;
    if (m == null || scene == null) return;
    _Scene(scene)
        .getMaterialByName('KneeAlertRed')
        .pbrMetallicRoughness
        .setBaseColorFactor(
          [1.toJS, 0.025.toJS, 0.04.toJS, (widget.alert ? 1 : 0).toJS].toJS,
        );
    if (widget.high) {
      m.play();
    } else {
      m.pause();
      m.currentTime = 0;
    }
  }

  @override
  void didUpdateWidget(covariant LegView old) {
    super.didUpdateWidget(old);
    if (old.high != widget.high || old.alert != widget.alert) sync();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Center(
        child: TextButton(
          onPressed: () => setState(() => failed = false),
          child: const Text('Reload 3D model'),
        ),
      );
    }
    return HtmlElementView.fromTagName(
      tagName: 'model-viewer',
      onElementCreated: (obj) {
        final el = obj as web.HTMLElement;
        el.style
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'transparent';
        el.setAttribute('alt', 'Interactive prosthesis scan');
        el.setAttribute('camera-controls', '');
        el.setAttribute('animation-name', 'IllustrativeFlexion');
        el.setAttribute('exposure', '0.88');
        el.style.setProperty('--progress-bar-height', '2px');
        el.style.setProperty('--progress-bar-color', '#3978f6');
        el.setAttribute('disable-pan', '');
        el.setAttribute('camera-orbit', '35deg 85deg auto');
        el.setAttribute('shadow-intensity', '0.4');
        el.setAttribute('interaction-prompt', 'none');
        model = _Model(el);
        el.addEventListener(
          'load',
          ((web.Event event) {
            if (mounted) sync();
          }).toJS,
        );
        el.addEventListener(
          'error',
          ((web.Event event) {
            if (mounted) setState(() => failed = true);
          }).toJS,
        );
        el.setAttribute(
          'src',
          'assets/assets/models/prosthesis_leg_rigged.glb',
        );
      },
    );
  }
}
