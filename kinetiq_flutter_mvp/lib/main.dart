import 'package:flutter/material.dart';
import 'brand.dart';
import 'screens/app_shell.dart';
import 'services/local_store.dart';
import 'services/motion_data_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KinetiqApp());
}

class KinetiqApp extends StatefulWidget {
  const KinetiqApp({super.key});
  @override
  State<KinetiqApp> createState() => _KinetiqAppState();
}

class _KinetiqAppState extends State<KinetiqApp> {
  late Future<MotionDataService> boot;
  Future<MotionDataService> open() async =>
      MotionDataService(await LocalStore.open());
  @override
  void initState() {
    super.initState();
    boot = open();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: productName,
    theme: AppTheme.light,
    home: FutureBuilder(
      future: boot,
      builder: (context, snap) {
        if (snap.hasData) return AppShell(service: snap.requireData);
        return Scaffold(
          body: Center(
            child: snap.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Encrypted storage could not be opened.'),
                      TextButton(
                        onPressed: () => setState(() => boot = open()),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    ),
  );
}
