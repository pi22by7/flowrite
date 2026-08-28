import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/writing_file.dart';

/// Exports writing files to a plain-text format the user can share or save
/// anywhere via the OS share sheet.
class ExportService {
  Future<void> exportFile(WritingFile file) async {
    final content = await file.readContent();
    final tempDir = await getTemporaryDirectory();
    final safeName = _sanitizeFileName(file.name);
    final tempFile = File('${tempDir.path}/$safeName.txt');
    await tempFile.writeAsString(content);

    try {
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        fileNameOverrides: ['$safeName.txt'],
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> exportAll(List<WritingFile> files) async {
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/flowrite_export.zip';
    final zipFile = File(zipPath);

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      for (final file in files) {
        final content = await file.readContent();
        final safeName = _sanitizeFileName(file.name);
        encoder.addArchiveFile(
          ArchiveFile('$safeName.txt', content.length, content.codeUnits),
        );
      }
    } finally {
      encoder.close();
    }

    try {
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        fileNameOverrides: ['flowrite_export.zip'],
      );
    } finally {
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'untitled' : sanitized;
  }
}
