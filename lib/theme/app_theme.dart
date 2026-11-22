import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF142B4A);
  static const muted = Color(0xFF526B86);
  static const blue = Color(0xFF3978F6);
  static const blueDeep = Color(0xFF2459D6);
  static const cyan = Color(0xFF55C7F4);
  static const ice = Color(0xFFEAF4FF);
  static const canvas = Color(0xFFF3F8FF);
  static const line = Color(0xFFDCE8F6);
  static const green = Color(0xFF21A77A);
  static const red = Color(0xFFED5268);
  static const amber = Color(0xFFF2A94A);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: Brightness.light,
        primary: AppColors.blue,
        secondary: AppColors.cyan,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.blue.withValues(alpha: 0.11),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.blueDeep : AppColors.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.blueDeep : AppColors.muted,
            size: 22,
          );
        }),
      ),
    );
  }
}
