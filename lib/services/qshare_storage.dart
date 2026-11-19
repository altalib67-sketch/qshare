import 'dart:io';

import 'package:path/path.dart' as p;

/// Where received files live: /storage/emulated/0/QShare — a folder
/// named after the app, visible in the Files app (not Downloads).
///
/// [hasAllFilesAccess] is true when MANAGE_EXTERNAL_STORAGE was granted.
/// Without it Android 11+ will not let us write to the public root, so
/// we fall back to the app's own external folder and tell the user.
class QShareStorage {
  static const String folderName = 'QShare';
  static const String publicRoot = '/storage/emulated/0';

  static Directory resolve({
    required bool hasAllFilesAccess,
    Directory? appExternalDir,
    String? publicRootOverride,
  }) {
    if (hasAllFilesAccess) {
      return Directory(
        p.join(publicRootOverride ?? publicRoot, folderName),
      );
    }
    if (appExternalDir != null) {
      return Directory(p.join(appExternalDir.path, folderName));
    }
    return Directory(p.join(publicRootOverride ?? publicRoot, folderName));
  }

  /// Create the folder (best effort) and report whether it is writable.
  static bool ensureWritable(Directory dir) {
    try {
      dir.createSync(recursive: true);
      final probe = File(p.join(dir.path, '.qshare-write-test'));
      probe.writeAsStringSync('ok');
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }
}
