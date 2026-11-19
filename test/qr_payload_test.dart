import 'package:flutter_test/flutter_test.dart';
import 'package:qshare/services/qr_payload.dart';

void main() {
  test('QR payload round-trip', () {
    const payload = QrPayload(ip: '192.168.1.5', port: 8765, token: 'AbC123xYz');
    final decoded = QrPayload.tryDecode(payload.encode());
    expect(decoded, isNotNull);
    expect(decoded!.ip, '192.168.1.5');
    expect(decoded.port, 8765);
    expect(decoded.token, 'AbC123xYz');
  });

  test('QR payload rejects garbage, wrong version and bad IPs', () {
    expect(QrPayload.tryDecode('hello'), isNull);
    expect(QrPayload.tryDecode(''), isNull);
    expect(
      QrPayload.tryDecode('{"v":2,"ip":"192.168.1.5","port":8765,"token":"x"}'),
      isNull,
    );
    expect(
      QrPayload.tryDecode(
        '{"v":1,"ip":"example.com","port":8765,"token":"x"}',
      ),
      isNull,
    );
    expect(
      QrPayload.tryDecode(
        '{"v":1,"ip":"999.1.1.1","port":8765,"token":"x"}',
      ),
      isNull,
    );
    expect(
      QrPayload.tryDecode(
        '{"v":1,"ip":"192.168.1.5","port":0,"token":"x"}',
      ),
      isNull,
    );
  });

  test('newToken is 16 chars, unique', () {
    final a = QrPayload.newToken();
    final b = QrPayload.newToken();
    expect(a.length, 16);
    expect(a, isNot(b));
  });
}
