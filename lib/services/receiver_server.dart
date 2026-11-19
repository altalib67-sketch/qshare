import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'folder_zip.dart';

/// One file (or folder) that just arrived.
class ReceivedItem {
  ReceivedItem({
    required this.name,
    required this.path,
    required this.size,
    required this.isFolder,
    required this.receivedAt,
  });

  final String name;
  final String path;
  final int size;
  final bool isFolder;
  final DateTime receivedAt;
}

/// The receiver's small local HTTP server (port 8765).
///
/// * `GET /ping` → `{"ok":true}` — the sender checks reachability.
/// * `POST /upload` — raw file bytes in the body, with headers:
///   `x-qshare-token` (must match), `x-qshare-name` (URI-encoded file
///   name), `x-qshare-kind`: `file` or `folder-zip`,
///   `x-qshare-folder` (original folder name, for folder-zip).
///   A folder-zip is unzipped into `QShare/<folder-name>/` and the
///   zip itself is deleted. Files stream straight to disk (no big
///   in-memory buffer), so large files work.
class QShareServer {
  QShareServer._(this._server, this.saveDir, this.token);

  final HttpServer _server;
  final Directory saveDir;
  final String token;

  void Function(ReceivedItem item)? onReceived;

  int get port => _server.port;

  static Future<QShareServer> start({
    required Directory saveDir,
    required String token,
    int port = 8765,
  }) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    final instance = QShareServer._(server, saveDir, token);
    server.listen(instance._handle);
    return instance;
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/ping') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true}));
        await request.response.close();
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/upload') {
        await _handleUpload(request);
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final response = request.response;
    final tokenHeader = request.headers.value('x-qshare-token');
    if (tokenHeader != token) {
      response.statusCode = HttpStatus.forbidden;
      response.write(jsonEncode({'error': 'bad token'}));
      await response.close();
      return;
    }
    final rawName =
        request.headers.value('x-qshare-name') ?? 'ملف';
    final name = Uri.decodeComponent(rawName);
    final kind = request.headers.value('x-qshare-kind') ?? 'file';
    final folderName =
        request.headers.value('x-qshare-folder');

    saveDir.createSync(recursive: true);

    if (kind == 'folder-zip') {
      final folder = freeDirPath(
        saveDir,
        folderName != null && folderName.isNotEmpty
            ? Uri.decodeComponent(folderName)
            : safeName(name).replaceAll(RegExp(r'\.zip$', caseSensitive: false), ''),
      );
      folder.createSync(recursive: true);
      final tmpZip = File(
        p.join(saveDir.path, '.qshare-tmp-${DateTime.now().millisecondsSinceEpoch}.zip'),
      );
      final sink = tmpZip.openWrite();
      await sink.addStream(request);
      await sink.close();
      final extracted = unzipToDirectory(tmpZip, folder);
      try {
        tmpZip.deleteSync();
      } catch (_) {}
      final size = _dirSize(folder);
      onReceived?.call(ReceivedItem(
        name: p.basename(folder.path),
        path: folder.path,
        size: size,
        isFolder: true,
        receivedAt: DateTime.now(),
      ));
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'ok': true,
          'files': extracted.length,
        }));
      await response.close();
      return;
    }

    final dest = freeFilePath(saveDir, name);
    final sink = dest.openWrite();
    var bytes = 0;
    await for (final chunk in request) {
      bytes += chunk.length;
      sink.add(chunk);
    }
    await sink.close();
    onReceived?.call(ReceivedItem(
      name: p.basename(dest.path),
      path: dest.path,
      size: bytes,
      isFolder: false,
      receivedAt: DateTime.now(),
    ));
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'ok': true, 'size': bytes}));
    await response.close();
  }

  static int _dirSize(Directory dir) {
    var total = 0;
    for (final e in dir.listSync(recursive: true)) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }
}
