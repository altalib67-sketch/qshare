import 'package:material_ui/material_ui.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../main.dart';
import '../services/qr_payload.dart';
import '../services/receiver_server.dart';
import '../theme.dart';

/// Receive: tap → server starts, big QR appears instantly.
/// Scanning the QR is the trust — files auto-accept into QShare.
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key, required this.qshareDir});

  final QShareDir qshareDir;

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  QShareServer? _server;
  String? _token;
  String? _ip;
  String? _wifiName;
  String? _error;
  bool _starting = true;
  final List<ReceivedItem> _received = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final ip = await _localWifiIp();
      const wifi = '';
      if (ip == null || ip.isEmpty) {
        throw StateError('no-wifi');
      }
      final token = QrPayload.newToken();
      final server = await QShareServer.start(
        saveDir: widget.qshareDir.dir,
        token: token,
      );
      server.onReceived = (item) {
        if (mounted) {
          setState(() => _received.insert(0, item));
        }
      };
      if (!mounted) return;
      setState(() {
        _server = server;
        _token = token;
        _ip = ip;
        _wifiName = wifi;
        _starting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = 'تأكد أن الواي فاي مفعّل في جهازك، وأن الجهازين على '
            'نفس الواي فاي أو الهوتسبوت، ثم أعد المحاولة.';
      });
    }
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  Future<void> _openFolder() async {
    await Clipboard.setData(ClipboardData(text: widget.qshareDir.dir.path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ المسار: ${widget.qshareDir.dir.path} — افتحه من مدير الملفات',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = (_ip != null && _token != null)
        ? QrPayload(ip: _ip!, port: 8765, token: _token!).encode()
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('استلام')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_starting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                ErrorCard(
                  message: _error!,
                  fixLabel: 'إعادة المحاولة',
                  onFix: _start,
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'امسح هذا الرمز من جهاز الإرسال',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: payload!,
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.teal,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_rounded,
                            color: AppColors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _wifiName != null && _wifiName!.isNotEmpty
                                  ? 'الشبكة: $_wifiName'
                                  : 'الشبكة: —',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'العنوان: $_ip',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.teal),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تأكد أن الجهازين على نفس الواي فاي أو الهوتسبوت. '
                          'الملفات المستلمة تُحفظ تلقائياً في مجلد QShare.',
                          style: TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _received.isEmpty
                          ? 'بانتظار الملفات…'
                          : 'وصلت ${_received.length} ${_received.length == 1 ? 'ملف' : 'ملفات'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _openFolder,
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      label: const Text('فتح مجلد QShare'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_received.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'لم يصلك شيء بعد. اترك هذه الشاشة مفتوحة '
                      'وسيظهر كل ملف هنا فور وصوله.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.6),
                    ),
                  )
                else
                  ..._received.map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          item.isFolder
                              ? Icons.folder_rounded
                              : Icons.insert_drive_file_rounded,
                          color: AppColors.teal,
                          size: 32,
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${formatBytes(item.size)} • ${item.path}',
                          textDirection: TextDirection.ltr,
                        ),
                        trailing: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                'مكان الحفظ: ${widget.qshareDir.dir.path}',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First non-loopback IPv4 address (usually the Wi-Fi address).
Future<String?> _localWifiIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
          return addr.address;
        }
      }
    }
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {}
  return null;
}
