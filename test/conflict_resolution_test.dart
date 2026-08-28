import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/models/writing_file.dart';
import 'package:flowrite/models/sync_operation.dart';
import 'package:flowrite/services/conflict_resolution_service.dart';

void main() {
  final service = ConflictResolutionService();

  group('hasConflict', () {
    test('no conflict when content is identical', () {
      final local = WritingFile(id: 'f1', name: 'a', content: 'same', lastModified: DateTime(2026, 1, 1, 10, 0));
      final remote = WritingFile(id: 'f1', name: 'a', content: 'same', lastModified: DateTime(2026, 1, 1, 10, 0, 3));
      expect(service.hasConflict(local, remote), isFalse);
    });

    test('conflict when content differs and timestamps are close', () {
      final local = WritingFile(id: 'f1', name: 'a', content: 'local edit', lastModified: DateTime(2026, 1, 1, 10, 0, 0));
      final remote = WritingFile(id: 'f1', name: 'a', content: 'remote edit', lastModified: DateTime(2026, 1, 1, 10, 0, 2));
      expect(service.hasConflict(local, remote), isTrue);
    });

    test('no conflict when content differs but timestamps are far apart', () {
      final local = WritingFile(id: 'f1', name: 'a', content: 'local edit', lastModified: DateTime(2026, 1, 1, 10, 0, 0));
      final remote = WritingFile(id: 'f1', name: 'a', content: 'remote edit', lastModified: DateTime(2026, 1, 1, 11, 0, 0));
      expect(service.hasConflict(local, remote), isFalse);
    });
  });

  group('resolveConflict newerWins', () {
    test('remote wins when remote is newer', () async {
      final local = WritingFile(id: 'f1', name: 'a', content: 'local edit', lastModified: DateTime(2026, 1, 1, 10, 0, 0));
      final remote = WritingFile(id: 'f1', name: 'a', content: 'remote edit', lastModified: DateTime(2026, 1, 1, 10, 0, 2));

      final resolved = await service.resolveConflict(
        localFile: local,
        remoteFile: remote,
        strategy: ConflictResolution.newerWins,
      );

      expect(resolved.content, 'remote edit');
    });

    test('local wins when local is newer', () async {
      final local = WritingFile(id: 'f1', name: 'a', content: 'local edit', lastModified: DateTime(2026, 1, 1, 10, 0, 5));
      final remote = WritingFile(id: 'f1', name: 'a', content: 'remote edit', lastModified: DateTime(2026, 1, 1, 10, 0, 0));

      final resolved = await service.resolveConflict(
        localFile: local,
        remoteFile: remote,
        strategy: ConflictResolution.newerWins,
      );

      expect(resolved.content, 'local edit');
    });
  });
}
