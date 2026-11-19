import 'package:material_ui/material_ui.dart';

/// Kush teal + gold, matching the user's other projects.
class AppColors {
  static const teal = Color(0xFF0D7377);
  static const tealDark = Color(0xFF0A5A5E);
  static const tealLight = Color(0xFFE3F2F2);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFF7ECD0);
  static const ink = Color(0xFF1B2A2A);
  static const muted = Color(0xFF5F7373);
  static const card = Colors.white;
  static const background = Color(0xFFF4F7F7);
  static const success = Color(0xFF1E8E3E);
  static const danger = Color(0xFFB3261E);
}

ThemeData qshareTheme() {
  const base = ColorScheme.light(
    primary: AppColors.teal,
    secondary: AppColors.gold,
    surface: AppColors.card,
  );
  return ThemeData(
    colorScheme: base,
    fontFamily: 'Tajawal',
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.teal,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.teal,
        side: const BorderSide(color: AppColors.teal, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
  );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes بايت';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} ك.ب';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} غ.ب';
}

String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '—';
  return '${formatBytes(bytesPerSecond)}/ث';
}

/// One clear Arabic error card + one fix button.
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.message,
    required this.fixLabel,
    required this.onFix,
  });

  final String message;
  final String fixLabel;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تعذّر الاتصال',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onFix, child: Text(fixLabel)),
        ],
      ),
    );
  }
}
