import 'dart:convert';
import 'dart:math';

/// QR payload shared by sender and receiver.
///
/// A compact JSON string:
/// {"v":1,"ip":"192.168.1.5","port":8765,"token":"<16 random chars>"}
/// The token is the trust: whoever scanned the QR may upload. The
/// receiver validates it on every upload.
class QrPayload {
  const QrPayload({
    required this.ip,
    required this.port,
    required this.token,
  });

  final String ip;
  final int port;
  final String token;

  static const int currentVersion = 1;

  String encode() => jsonEncode({
        'v': currentVersion,
        'ip': ip,
        'port': port,
        'token': token,
      });

  static QrPayload? tryDecode(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final obj = jsonDecode(trimmed);
      if (obj is! Map<String, dynamic>) return null;
      if (obj['v'] != currentVersion) return null;
      final ip = obj['ip'];
      final port = obj['port'];
      final token = obj['token'];
      if (ip is! String || ip.isEmpty) return null;
      if (port is! int || port <= 0 || port > 65535) return null;
      if (token is! String || token.isEmpty) return null;
      // A plain IPv4 address (no hostnames, no URLs).
      final parts = ip.split('.');
      if (parts.length != 4) return null;
      for (final p in parts) {
        final n = int.tryParse(p);
        if (n == null || n < 0 || n > 255) return null;
      }
      return QrPayload(ip: ip, port: port, token: token);
    } catch (_) {
      return null;
    }
  }

  static String newToken() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(16, (_) => chars[rnd.nextInt(chars.length)])
        .join();
  }
}
