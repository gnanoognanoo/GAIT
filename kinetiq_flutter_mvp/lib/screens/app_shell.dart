import 'dart:ui';
import 'package:flutter/material.dart';
import '../brand.dart';
import '../services/motion_data_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.service, this.showModel = true});
  final MotionDataService service;
  final bool showModel;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int index = 0;
  bool notified = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.service.addListener(alert);
  }

  void alert() {
    final active = widget.service.latest?.alert == true;
    if (active && !notified && widget.service.profile['notify'] != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.service.demo ? 'DEMO · ' : ''}Sustained high-motion alert.',
          ),
        ),
      );
    }
    notified = active;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) widget.service.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.service.removeListener(alert);
    widget.service.dispose();
    super.dispose();
  }

  void select(int v) => setState(() => index = v);
  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return Scaffold(
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfff9fcff), Color(0xffe8f2ff), Color(0xfff9fbff)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 31,
                          height: 31,
                          decoration: BoxDecoration(
                            color: AppColors.blueDeep,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.multiline_chart_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          productName,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.3,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Recent alerts',
                          icon: const Icon(Icons.notifications_none_rounded),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (ctx) {
                              final events = s.history.reversed
                                  .where((v) => v.alertStart)
                                  .take(12)
                                  .toList();
                              return AlertDialog(
                                title: const Text('Recent alerts'),
                                content: SizedBox(
                                  width: 360,
                                  child: events.isEmpty
                                      ? const Text(
                                          'No recorded alert episodes.',
                                        )
                                      : ListView(
                                          shrinkWrap: true,
                                          children: [
                                            for (final v in events)
                                              ListTile(
                                                title: Text(
                                                  v.demo
                                                      ? 'DEMO · Sustained high motion'
                                                      : 'Sustained high motion',
                                                ),
                                                subtitle: Text(
                                                  v.time
                                                      .toLocal()
                                                      .toString()
                                                      .split('.')
                                                      .first,
                                                ),
                                              ),
                                          ],
                                        ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        ListenableBuilder(
                          listenable: s,
                          builder: (context, _) => IconButton(
                            tooltip: 'Open profile',
                            onPressed: () => select(2),
                            icon: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xffdceaff),
                              child: Text(
                                (s.profile['name'] as String? ?? '')
                                        .trim()
                                        .characters
                                        .firstOrNull
                                        ?.toUpperCase() ??
                                    'K',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: [
                    TickerMode(
                      enabled: index == 0,
                      child: HomeScreen(
                        service: s,
                        showModel: widget.showModel,
                        visible: index == 0,
                      ),
                    ),
                    ReportsScreen(service: s, visible: index == 1),
                    ProfileScreen(service: s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1f26466e),
                  blurRadius: 18,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: NavigationBar(
                  height: 62,
                  backgroundColor: Colors.white.withValues(alpha: .89),
                  selectedIndex: index,
                  onDestinationSelected: select,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_rounded),
                      label: 'Reports',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
