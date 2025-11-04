/// Represents different types of sync operations
enum SyncOperationType {
  create,
  update,
  delete,
}

/// Represents a single sync operation in the queue
class SyncOperation {
  final String id; // Unique ID for this operation
  final String fileId; // ID of the file being synced
  final SyncOperationType type;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttempt;
  final String? errorMessage;

  SyncOperation({
    required this.id,
    required this.fileId,
    required this.type,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttempt,
    this.errorMessage,
  });

  /// Create a copy with updated fields
  SyncOperation copyWith({
    String? id,
    String? fileId,
    SyncOperationType? type,
    DateTime? createdAt,
    int? retryCount,
    DateTime? lastAttempt,
    String? errorMessage,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Calculate next retry delay using exponential backoff
  Duration getNextRetryDelay() {
    // Exponential backoff: 2^retryCount seconds (max 1 hour)
    final seconds = (1 << retryCount).clamp(1, 3600);
    return Duration(seconds: seconds);
  }

  /// Check if enough time has passed for retry
  bool shouldRetry() {
    if (lastAttempt == null) return true;
    if (retryCount >= 10) return false; // Max 10 retries

    final nextRetryDelay = getNextRetryDelay();
    final nextRetryTime = lastAttempt!.add(nextRetryDelay);
    return DateTime.now().isAfter(nextRetryTime);
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileId': fileId,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastAttempt': lastAttempt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  /// Create from JSON
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      fileId: json['fileId'] as String,
      type: SyncOperationType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastAttempt: json['lastAttempt'] != null
          ? DateTime.parse(json['lastAttempt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  String toString() {
    return 'SyncOperation(id: $id, fileId: $fileId, type: $type, retryCount: $retryCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncOperation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Represents a transaction in the local change log
class SyncTransaction {
  final String id;
  final String fileId;
  final SyncOperationType operation;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // Extra data like file name, size, etc.

  SyncTransaction({
    required this.id,
    required this.fileId,
    required this.operation,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileId': fileId,
      'operation': operation.name,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory SyncTransaction.fromJson(Map<String, dynamic> json) {
    return SyncTransaction(
      id: json['id'] as String,
      fileId: json['fileId'] as String,
      operation: SyncOperationType.values.firstWhere(
        (e) => e.name == json['operation'],
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'SyncTransaction(id: $id, fileId: $fileId, operation: $operation, timestamp: $timestamp)';
  }
}

/// Sync status for UI indicators
enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  pending,
}

/// Sync conflict resolution strategy
enum ConflictResolution {
  localWins, // Keep local version
  remoteWins, // Keep remote version
  newerWins, // Keep the version with later timestamp
  manual, // Require user decision
}
