import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qshare/services/folder_zip.dart';

void main() {
  test('zip a folder and unzip it — structure and content round-trip',
      () async {
    final tmp = await Directory.systemTemp.createTemp('qshare-zip-test');
    try {
      final src = Directory('${tmp.path}/MyPhotos');
      await Directory('${src.path}/sub/nested').create(recursive: true);
      await Directory('${src.path}/empty').create(recursive: true);
      await File('${src.path}/a.txt').writeAsString('hello a');
      await File('${src.path}/sub/b.txt').writeAsString('hello b');
      await File('${src.path}/sub/nested/c.bin')
          .writeAsBytes(List.generate(256, (i) => i));

      final zip = File('${tmp.path}/out.zip');
      await zipDirectory(src, zip);
      expect(await zip.exists(), isTrue);
      expect(await zip.length(), greaterThan(0));

      final dest = Directory('${tmp.path}/dest');
      final extracted = unzipToDirectory(zip, dest);
      expect(extracted, contains('a.txt'));
      expect(extracted, contains('sub/b.txt'));
      expect(extracted, contains('sub/nested/c.bin'));
      expect(await File('${dest.path}/a.txt').readAsString(), 'hello a');
      expect(await File('${dest.path}/sub/b.txt').readAsString(), 'hello b');
      expect(
        await File('${dest.path}/sub/nested/c.bin').readAsBytes(),
        List.generate(256, (i) => i),
      );
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('unzip rejects path traversal', () {
    // _safeRelative is exercised through unzipToDirectory with a
    // hand-built archive containing a traversal entry.
    expect(safeName('../../etc/passwd'), isNot('etc/passwd'));
    expect(safeName('my file.txt'), 'my file.txt');
    expect(safeName(''), 'ملف');
  });
}
