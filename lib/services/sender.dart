import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'folder_zip.dart';
import 'qr_payload.dart';

/// Sender side: ping the receiver, then upload files / whole folders.
class QShareSender {
  QShareSender(this.payload) : _dio = Dio();

  final QrPayload payload;
  final Dio _dio;

  String get _base => 'http://${payload.ip}:${payload.port}';

  /// True when the receiver answers on the same network.
  Future<bool> ping() async {
    try {
      final res = await _dio.get(
        '$_base/ping',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload one file. [onProgress] gets (sentBytes, totalBytes).
  Future<void> uploadFile(
    File file, {
    required void Function(int sent, int total) onProgress,
  }) async {
    final total = await file.length();
    await _dio.post(
      '$_base/upload',
      data: file.openRead(),
      options: Options(
        headers: {
          'x-qshare-token': payload.token,
          'x-qshare-name': Uri.encodeComponent(p.basename(file.path)),
          'x-qshare-kind': 'file',
          'content-length': '$total',
          'content-type': 'application/octet-stream',
        },
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 30),
      ),
      onSendProgress: (sent, totalBytes) =>
          onProgress(sent, totalBytes > 0 ? totalBytes : total),
    );
    // Keep the callback honest even if Dio reports nothing.
    onProgress(total, total);
  }

  /// Zip a whole folder (preserving its structure) and upload it.
  /// Returns the zip size in bytes.
  Future<int> uploadFolder(
    Directory folder, {
    required void Function(int sent, int total) onProgress,
    required Directory tempDir,
  }) async {
    final folderName = p.basename(folder.path);
    final zipFile = File(
      p.join(tempDir.path, 'qshare-${DateTime.now().millisecondsSinceEpoch}.zip'),
    );
    await zipDirectory(folder, zipFile);
    final total = await zipFile.length();
    try {
      await _dio.post(
        '$_base/upload',
        data: zipFile.openRead(),
        options: Options(
          headers: {
            'x-qshare-token': payload.token,
            'x-qshare-name': Uri.encodeComponent('$folderName.zip'),
            'x-qshare-kind': 'folder-zip',
            'x-qshare-folder': Uri.encodeComponent(folderName),
            'content-length': '$total',
            'content-type': 'application/octet-stream',
          },
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 30),
        ),
        onSendProgress: (sent, totalBytes) =>
            onProgress(sent, totalBytes > 0 ? totalBytes : total),
      );
      onProgress(total, total);
      return total;
    } finally {
      try {
        await zipFile.delete();
      } catch (_) {}
    }
  }
}
