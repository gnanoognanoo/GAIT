import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

const gap = SizedBox(height: 16);
const headingStyle = TextStyle(
  fontSize: 27,
  fontWeight: FontWeight.w700,
  letterSpacing: -1.1,
  color: AppColors.ink,
);

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.blueDeep});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: color,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 18 : 32,
            18,
            MediaQuery.sizeOf(context).width < 600 ? 18 : 32,
            120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class SplitPanel extends StatelessWidget {
  const SplitPanel({super.key, required this.left, required this.right});
  final Widget left, right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 760
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: left),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: right),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, gap, right],
          ),
  );
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, this.icon, {super.key});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.ice.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class CardBody extends StatelessWidget {
  const CardBody(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}

Future<void> perform(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The operation could not be completed. Please try again.',
          ),
        ),
      );
    }
  }
}
