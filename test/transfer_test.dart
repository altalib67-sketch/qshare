import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qshare/services/qr_payload.dart';
import 'package:qshare/services/receiver_server.dart';
import 'package:qshare/services/sender.dart';

/// End-to-end transfer on this machine: start the real receiver
/// server, POST a file and a whole folder-zip through the real
/// sender, and verify both land under the QShare folder.
void main() {
  test('transfer: file + whole folder land in the QShare folder',
      () async {
    final tmp = await Directory.systemTemp.createTemp('qshare-transfer');
    try {
      final saveDir = Directory('${tmp.path}/QShare')..createSync();
      final token = QrPayload.newToken();
      final server = await QShareServer.start(
        saveDir: saveDir,
        token: token,
        port: 0, // any free port
      );
      final received = <ReceivedItem>[];
      server.onReceived = received.add;
      try {
        final payload = QrPayload(
          ip: '127.0.0.1',
          port: server.port,
          token: token,
        );
        final sender = QShareSender(payload);
        expect(await sender.ping(), isTrue);

        // 1) a single file
        final file = File('${tmp.path}/hello.txt')
          ..writeAsStringSync('hello qshare');
        await sender.uploadFile(
          file,
          onProgress: (a, b) {},
        );
        final saved = File('${saveDir.path}/hello.txt');
        expect(await saved.exists(), isTrue);
        expect(await saved.readAsString(), 'hello qshare');

        // 2) a whole folder
        final folder = Directory('${tmp.path}/MyFolder');
        await Directory('${folder.path}/sub').create(recursive: true);
        await File('${folder.path}/one.txt').writeAsString('one');
        await File('${folder.path}/sub/two.txt').writeAsString('two');
        final tempDir = Directory('${tmp.path}/temp')..createSync();
        await sender.uploadFolder(
          folder,
          tempDir: tempDir,
          onProgress: (a, b) {},
        );
        expect(
          await File('${saveDir.path}/MyFolder/one.txt').readAsString(),
          'one',
        );
        expect(
          await File('${saveDir.path}/MyFolder/sub/two.txt')
              .readAsString(),
          'two',
        );
        expect(received.length, 2);
        expect(received[1].isFolder, isTrue);
        expect(received[1].name, 'MyFolder');
      } finally {
        await server.stop();
      }
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('server rejects a wrong token', () async {
    final tmp = await Directory.systemTemp.createTemp('qshare-token');
    try {
      final saveDir = Directory('${tmp.path}/QShare')..createSync();
      final server = await QShareServer.start(
        saveDir: saveDir,
        token: 'correct-token',
        port: 0,
      );
      try {
        final bad = QShareSender(
          QrPayload(ip: '127.0.0.1', port: server.port, token: 'wrong'),
        );
        expect(
          () async => bad.uploadFile(
            File('${tmp.path}/x.txt')..writeAsStringSync('x'),
            onProgress: (a, b) {},
          ),
          throwsA(isA<Exception>()),
        );
        expect(await File('${saveDir.path}/x.txt').exists(), isFalse);
      } finally {
        await server.stop();
      }
    } finally {
      await tmp.delete(recursive: true);
    }
  });
}
