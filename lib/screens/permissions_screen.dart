import 'package:material_ui/material_ui.dart';

import '../services/permissions_service.dart';
import '../theme.dart';

/// First-launch screen: one Arabic explainer, then all permissions
/// are requested at once. Never shown again after this.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.onDone});

  final Future<void> Function() onDone;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    final result = await PermissionsService.requestAll();
    setState(() => _busy = false);
    if (!mounted) return;
    if (!result.allFilesAccess) {
      // All-files access opens system settings; if the user skipped
      // it, explain once where files will land instead of nagging.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ملاحظة عن مكان الحفظ'),
          content: const Text(
            'لم تمنح إذن "الوصول لكل الملفات"، لذلك ستحفظ الملفات '
            'المستلمة في مجلد التطبيق الخاص بدل مجلد QShare العام. '
            'يمكنك تفعيله لاحقاً من إعدادات التطبيق.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('فهمت'),
            ),
          ],
        ),
      );
    }
    await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 110,
                  height: 110,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'QShare — كيو شير',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'مشاركة ملفات بسيطة بين جهازين، بدون إنترنت',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: AppColors.muted),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الأذونات مرة واحدة فقط',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    _PermRow('الكاميرا', 'لمسح رمز QR عند الإرسال'),
                    _PermRow('الصور والملفات', 'لاختيار ما ترسله وحفظ ما تستلمه'),
                    _PermRow('الموقع والأجهزة القريبة', 'لاكتشاف الجهاز الآخر — لا نعرف مكانك ولا نحفظه'),
                    _PermRow('الوصول لكل الملفات', 'لحفظ الملفات في مجلد QShare الظاهر في مدير الملفات'),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _request,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('السماح والمتابعة'),
              ),
              const SizedBox(height: 8),
              const Text(
                'بعد الموافقة لن نسألك عن الأذونات مرة أخرى',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow(this.title, this.sub);

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.teal, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(sub, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
