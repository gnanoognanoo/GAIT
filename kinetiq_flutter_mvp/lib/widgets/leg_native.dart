import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LegView extends StatefulWidget {
  const LegView({super.key, required this.high, required this.alert});
  final bool high, alert;
  @override
  State<LegView> createState() => _LegViewState();
}

class _LegViewState extends State<LegView> {
  WebViewController? controller;
  bool ready = false, failed = false;
  Future<void> sync() async {
    if (!ready) return;
    try {
      await controller?.runJavaScript("""
        (() => {
          const m=document.querySelector('model-viewer');
          const ring=m.model.getMaterialByName('KneeAlertRed');
          ring.pbrMetallicRoughness.setBaseColorFactor([1,0.025,0.04,${widget.alert ? 1 : 0}]);
          ${widget.high ? 'm.play()' : 'm.pause(); m.currentTime=0'}
        })()
      """);
    } catch (_) {
      if (mounted) setState(() => failed = true);
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
          onPressed: () => setState(() {
            failed = false;
            ready = false;
          }),
          child: const Text('Reload 3D model'),
        ),
      );
    }
    return ModelViewer(
      src: 'assets/models/prosthesis_leg_rigged.glb',
      alt: 'Interactive prosthesis scan',
      animationName: 'IllustrativeFlexion',
      exposure: .88,
      cameraControls: true,
      disablePan: true,
      ar: false,
      cameraOrbit: '35deg 85deg auto',
      backgroundColor: Colors.transparent,
      shadowIntensity: .4,
      onWebViewCreated: (c) => controller = c,
      javascriptChannels: {
        JavascriptChannel(
          'RigStatus',
          onMessageReceived: (m) {
            if (!mounted) return;
            if (m.message == 'ready') {
              ready = true;
              sync();
            } else {
              setState(() => failed = true);
            }
          },
        ),
      },
      relatedJs:
          "const leg=document.querySelector('model-viewer'); leg.addEventListener('load',()=>RigStatus.postMessage('ready')); leg.addEventListener('error',()=>RigStatus.postMessage('error'));",
    );
  }
}
