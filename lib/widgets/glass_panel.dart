import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.tint,
    this.blur = 18,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final double blur;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.92),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8CAED8).withValues(alpha: 0.13),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
              const BoxShadow(
                color: Colors.white,
                blurRadius: 8,
                offset: Offset(-3, -3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.iconColor = AppColors.blueDeep,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8AA9D1).withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(4, 5),
              ),
              const BoxShadow(
                color: Colors.white,
                blurRadius: 8,
                offset: Offset(-3, -3),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.label, required this.alert});

  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert
        ? AppColors.red
        : (label == 'OFFLINE'
              ? AppColors.muted
              : label == 'DEMO'
              ? const Color(0xff8b591b)
              : AppColors.blueDeep);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}
