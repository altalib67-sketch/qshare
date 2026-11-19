import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

/// Home: ONLY two big buttons — Receive and Send.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.qshareDir});

  final QShareDir qshareDir;

  Future<void> _openFolder(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: qshareDir.dir.path));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم نسخ المسار: ${qshareDir.dir.path} — افتحه من مدير الملفات',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'QShare',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              const Text(
                'كيو شير — أرسل واستلم بضغطة واحدة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: _BigButton(
                  icon: Icons.download_rounded,
                  label: 'استلام',
                  sub: 'اعرض رمز QR ليُرسل إليك',
                  color: AppColors.teal,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReceiveScreen(qshareDir: qshareDir),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _BigButton(
                  icon: Icons.upload_rounded,
                  label: 'إرسال',
                  sub: 'امسح رمز QR وأرسل ملفاتك',
                  color: AppColors.gold,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SendScreen(qshareDir: qshareDir),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_rounded,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            qshareDir.isPublicFolder
                                ? 'الملفات المستلمة تُحفظ في:'
                                : 'لم يُمنح الوصول الكامل — تُحفظ في مجلد التطبيق:',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            qshareDir.dir.path,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'فتح المجلد',
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: AppColors.teal,
                      ),
                      onPressed: () => _openFolder(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'بدون إنترنت • مباشرة من جهاز لجهاز',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
