import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../services/qr_payload.dart';
import '../services/sender.dart';
import '../theme.dart';

enum _Step { scan, pick, sending, done }

/// Send: camera → scan QR → pick files / a whole folder → send.
class SendScreen extends StatefulWidget {
  const SendScreen({super.key, required this.qshareDir});

  final QShareDir qshareDir;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _scanner = MobileScannerController();
  _Step _step = _Step.scan;
  bool _scanned = false;
  String? _error;
  QrPayload? _payload;
  QShareSender? _sender;

  final List<File> _files = [];
  Directory? _folder;
  int _folderFileCount = 0;

  String _currentName = '';
  int _sent = 0;
  int _total = 0;
  int _speed = 0;
  int _sentCount = 0;
  int _totalCount = 0;
  DateTime? _lastTick;
  int _lastSent = 0;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_scanned) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    final payload = QrPayload.tryDecode(raw);
    if (payload == null) return;
    _scanned = true;
    await _scanner.stop();
    final sender = QShareSender(payload);
    setState(() {
      _payload = payload;
      _sender = sender;
      _error = null;
    });
    final ok = await sender.ping();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'تأكد أن الجهازين على نفس الواي فاي أو الهوتسبوت، '
            'وأن شاشة الاستلام مفتوحة في الجهاز الآخر.';
        _scanned = false;
      });
      await _scanner.start();
      return;
    }
    setState(() => _step = _Step.pick);
  }

  void _retryScan() {
    setState(() {
      _error = null;
      _scanned = false;
      _payload = null;
      _sender = null;
      _step = _Step.scan;
    });
    _scanner.start();
  }

  Future<void> _pickFiles(FileType type) async {
    final result = await FilePicker.pickFiles(type: type);
    if (result.isEmpty) return;
    setState(() {
      for (final f in result) {
        if (f.path != null) _files.add(File(f.path!));
      }
    });
  }

  Future<void> _pickFolder() async {
    // ignore: deprecated_member_use
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    final dir = Directory(path);
    var count = 0;
    for (final e in dir.listSync(recursive: true)) {
      if (e is File) count++;
    }
    setState(() {
      _folder = dir;
      _folderFileCount = count;
    });
  }

  int _folderSize(Directory dir) {
    var total = 0;
    for (final e in dir.listSync(recursive: true)) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }

  Future<void> _sendAll() async {
    final sender = _sender;
    if (sender == null) return;
    if (_files.isEmpty && _folder == null) return;
    var total = 0;
    for (final f in _files) {
      total += await f.length();
    }
    if (_folder != null) total += _folderSize(_folder!);
    final totalCount = _files.length + (_folder == null ? 0 : 1);
    setState(() {
      _step = _Step.sending;
      _total = total;
      _sent = 0;
      _sentCount = 0;
      _totalCount = totalCount;
      _speed = 0;
      _lastTick = DateTime.now();
      _lastSent = 0;
    });
    final tempDir = await getTemporaryDirectory();
    try {
      var base = 0;
      for (final file in _files) {
        final size = await file.length();
        setState(() => _currentName = p.basename(file.path));
        await sender.uploadFile(
          file,
          onProgress: (sent, totalBytes) {
            final now = DateTime.now();
            final dt = now.difference(_lastTick ?? now).inMilliseconds;
            if (dt >= 400) {
              final delta = (base + sent) - _lastSent;
              setState(() {
                _sent = base + sent;
                _speed = dt > 0 ? (delta * 1000 ~/ dt) : 0;
                _lastTick = now;
                _lastSent = base + sent;
              });
            } else {
              setState(() => _sent = base + sent);
            }
          },
        );
        base += size;
        setState(() {
          _sent = base;
          _sentCount++;
        });
      }
      if (_folder != null) {
        setState(() => _currentName = p.basename(_folder!.path));
        await sender.uploadFolder(
          _folder!,
          tempDir: tempDir,
          onProgress: (sent, totalBytes) {
            final now = DateTime.now();
            final dt = now.difference(_lastTick ?? now).inMilliseconds;
            if (dt >= 400) {
              final delta = (base + sent) - _lastSent;
              setState(() {
                _sent = base + sent;
                _speed = dt > 0 ? (delta * 1000 ~/ dt) : 0;
                _lastTick = now;
                _lastSent = base + sent;
              });
            } else {
              setState(() => _sent = base + sent);
            }
          },
        );
        setState(() {
          _sent = _total;
          _sentCount++;
        });
      }
      if (!mounted) return;
      setState(() {
        _step = _Step.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.pick;
        _error = 'انقطع الإرسال. تأكد أن الجهازين ما زالا على نفس '
            'الشبكة وأن شاشة الاستلام مفتوحة، ثم أعد المحاولة.';
      });
    }
  }

  void _reset() {
    setState(() {
      _files.clear();
      _folder = null;
      _folderFileCount = 0;
      _sent = 0;
      _total = 0;
      _sentCount = 0;
      _totalCount = 0;
      _step = _Step.pick;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إرسال')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.scan:
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scanner,
                    onDetect: _onBarcode,
                  ),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gold, width: 4),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Text(
                      'وجّه الكاميرا نحو رمز QR في جهاز الاستلام',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorCard(
                  message: _error!,
                  fixLabel: 'إعادة المسح',
                  onFix: _retryScan,
                ),
              ),
          ],
        );
      case _Step.pick:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم الاتصال بجهاز الاستلام (${_payload?.ip})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _retryScan,
                      child: const Text('مسح رمز آخر'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ماذا تريد أن ترسل؟',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _PickButton(
                icon: Icons.photo_library_rounded,
                label: 'صور وفيديو من المعرض',
                onTap: () => _pickFiles(FileType.media),
              ),
              const SizedBox(height: 10),
              _PickButton(
                icon: Icons.insert_drive_file_rounded,
                label: 'ملفات (مستندات، صوت، أي ملف)',
                onTap: () => _pickFiles(FileType.any),
              ),
              const SizedBox(height: 10),
              _PickButton(
                icon: Icons.folder_rounded,
                label: 'مجلد كامل — يُرسل كاملاً ويُنزل كاملاً',
                onTap: _pickFolder,
              ),
              const SizedBox(height: 18),
              if (_folder != null)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.folder_rounded,
                      color: AppColors.teal,
                      size: 32,
                    ),
                    title: Text(
                      p.basename(_folder!.path),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'مجلد كامل • $_folderFileCount ملف • ${formatBytes(_folderSize(_folder!))}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _folder = null),
                    ),
                  ),
                ),
              ..._files.map(
                (f) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.insert_drive_file_rounded,
                      color: AppColors.teal,
                    ),
                    title: Text(p.basename(f.path)),
                    subtitle: Text(formatBytes(f.lengthSync())),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _files.remove(f)),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorCard(
                  message: _error!,
                  fixLabel: 'إعادة المحاولة',
                  onFix: () => setState(() => _error = null),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: (_files.isEmpty && _folder == null)
                    ? null
                    : _sendAll,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  'إرسال ${_files.length + (_folder == null ? 0 : 1)} عنصر',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'ستصل الملفات إلى مجلد QShare في الجهاز الآخر، '
                'والمجلد الكامل سيُنزل كاملاً بنفس الاسم وبنيته.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        );
      case _Step.sending:
        final progress = _total > 0 ? _sent / _total : 0.0;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.cloud_upload_rounded,
                size: 72,
                color: AppColors.teal,
              ),
              const SizedBox(height: 16),
              const Text(
                'جارٍ الإرسال…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _currentName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: AppColors.tealLight,
                color: AppColors.teal,
              ),
              const SizedBox(height: 12),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% • '
                '${formatBytes(_sent)} من ${formatBytes(_total)} • '
                '${formatSpeed(_speed)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                '$_sentCount من $_totalCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              const Text(
                'لا تغلق التطبيق ولا تبعد الجهازين عن بعضهما',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        );
      case _Step.done:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 88,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              const Text(
                'تم الإرسال بنجاح',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'وصلت $_totalCount عناصر (${formatBytes(_total)}) '
                'إلى مجلد QShare في الجهاز الآخر.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _reset,
                child: const Text('إرسال المزيد'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('رجوع للرئيسية'),
              ),
            ],
          ),
        );
    }
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: AppColors.teal, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
