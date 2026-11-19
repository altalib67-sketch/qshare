import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Zip a whole folder, preserving its internal structure and file names.
/// Returns the created zip [File].
Future<File> zipDirectory(Directory folder, File outZip) async {
  final encoder = ZipFileEncoder();
  encoder.create(outZip.path);
  final base = folder.path;
  final entries = folder
      .listSync(recursive: true, followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entry in entries) {
    if (entry is File) {
      final rel = p.relative(entry.path, from: base);
      await encoder.addFile(entry, rel);
    } else if (entry is Directory) {
      // Empty folders: record them so the structure round-trips.
      final rel = p.relative(entry.path, from: base);
      if (entry.listSync().isEmpty) {
        encoder.addArchiveFile(
          ArchiveFile('$rel/', 0, []),
        );
      }
    }
  }
  await encoder.close();
  return outZip;
}

/// Unzip [zipFile] into [destDir], preserving structure.
/// Returns the list of extracted relative paths.
List<String> unzipToDirectory(File zipFile, Directory destDir) {
  final bytes = zipFile.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final extracted = <String>[];
  for (final file in archive) {
    if (!file.isFile) continue;
    final safe = _safeRelative(file.name);
    if (safe.isEmpty) continue;
    final out = File(p.join(destDir.path, safe));
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(file.content as List<int>);
    extracted.add(safe);
  }
  return extracted;
}

/// Strip drive letters, leading slashes and ".." segments so a zip can
/// never write outside its destination folder.
String _safeRelative(String name) {
  var cleaned = name.replaceAll('\\', '/');
  final parts = cleaned
      .split('/')
      .where((s) => s.isNotEmpty && s != '.' && s != '..')
      .toList();
  return parts.join('/');
}

/// Keep only a safe file/folder name (no separators, no "..").
String safeName(String name) {
  var base = p.basename(name.trim());
  base = base.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  if (base.isEmpty || base == '.' || base == '..') return 'ملف';
  return base;
}

/// A free path inside [dir] for [name]: appends (1), (2)… when taken.
File freeFilePath(Directory dir, String name) {
  final safe = safeName(name);
  var candidate = File(p.join(dir.path, safe));
  if (!candidate.existsSync()) return candidate;
  final stem = p.basenameWithoutExtension(safe);
  final ext = p.extension(safe);
  var i = 1;
  while (true) {
    candidate = File(p.join(dir.path, '$stem ($i)$ext'));
    if (!candidate.existsSync()) return candidate;
    i++;
  }
}

Directory freeDirPath(Directory parent, String name) {
  final safe = safeName(name);
  var candidate = Directory(p.join(parent.path, safe));
  if (!candidate.existsSync()) return candidate;
  var i = 1;
  while (true) {
    candidate = Directory(p.join(parent.path, '$safe ($i)'));
    if (!candidate.existsSync()) return candidate;
    i++;
  }
}
