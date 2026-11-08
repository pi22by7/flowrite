import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';
import '../models/writing_file.dart';

/// Byte-based exports work on desktop and in browsers (including downloads when
/// the browser's native share API is unavailable).
class ExportService {
  Future<void> exportFile(WritingFile file) async {
    final name = '${_sanitizeFileName(file.name)}.txt';
    await SharePlus.instance.share(ShareParams(files: [
      XFile.fromData(Uint8List.fromList(utf8.encode(await file.readContent())),
          mimeType: 'text/plain', name: name)
    ], fileNameOverrides: [
      name
    ]));
  }

  Future<void> exportAll(List<WritingFile> files) async {
    final archive = Archive();
    final names = <String>{};
    for (final file in files.where((file) => !file.isDeleted)) {
      final base = _sanitizeFileName(file.name);
      var name = '$base.txt';
      var count = 2;
      while (!names.add(name)) {
        name = '$base (${count++}).txt';
      }
      final bytes = utf8.encode(await file.readContent());
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    const name = 'flowrite_export.zip';
    await SharePlus.instance.share(ShareParams(files: [
      XFile.fromData(Uint8List.fromList(ZipEncoder().encode(archive)),
          mimeType: 'application/zip', name: name)
    ], fileNameOverrides: [
      name
    ]));
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'untitled' : sanitized;
  }
}
