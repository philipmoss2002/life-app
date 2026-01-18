/// Sync result model
///
/// Represents the result of a synchronization operation.
class SyncResult {
  final int uploadedCount;
  final int downloadedCount;
  final int failedCount;
  final List<String> errors;
  final Duration duration;

  SyncResult({
    required this.uploadedCount,
    required this.downloadedCount,
    required this.failedCount,
    required this.errors,
    required this.duration,
  });

  /// Create a successful sync result with no errors
  factory SyncResult.success({
    required int uploadedCount,
    required int downloadedCount,
    required Duration duration,
  }) {
    return SyncResult(
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
      failedCount: 0,
      errors: [],
      duration: duration,
    );
  }

  /// Create a failed sync result
  factory SyncResult.failure({
    required List<String> errors,
    required Duration duration,
  }) {
    return SyncResult(
      uploadedCount: 0,
      downloadedCount: 0,
      failedCount: errors.length,
      errors: errors,
      duration: duration,
    );
  }

  /// Create an empty sync result (no operations performed)
  factory SyncResult.empty() {
    return SyncResult(
      uploadedCount: 0,
      downloadedCount: 0,
      failedCount: 0,
      errors: [],
      duration: Duration.zero,
    );
  }

  /// Check if sync was successful (no failures)
  bool get isSuccess => failedCount == 0;

  /// Check if any operations were performed
  bool get hasOperations =>
      uploadedCount > 0 || downloadedCount > 0 || failedCount > 0;

  /// Get total number of operations
  int get totalOperations => uploadedCount + downloadedCount + failedCount;

  /// Create a copy with updated fields
  SyncResult copyWith({
    int? uploadedCount,
    int? downloadedCount,
    int? failedCount,
    List<String>? errors,
    Duration? duration,
  }) {
    return SyncResult(
      uploadedCount: uploadedCount ?? this.uploadedCount,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      failedCount: failedCount ?? this.failedCount,
      errors: errors ?? this.errors,
      duration: duration ?? this.duration,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'uploadedCount': uploadedCount,
      'downloadedCount': downloadedCount,
      'failedCount': failedCount,
      'errors': errors,
      'durationMs': duration.inMilliseconds,
    };
  }

  /// Create from JSON map
  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      uploadedCount: json['uploadedCount'] as int,
      downloadedCount: json['downloadedCount'] as int,
      failedCount: json['failedCount'] as int,
      errors:
          (json['errors'] as List<dynamic>).map((e) => e as String).toList(),
      duration: Duration(milliseconds: json['durationMs'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncResult &&
        other.uploadedCount == uploadedCount &&
        other.downloadedCount == downloadedCount &&
        other.failedCount == failedCount &&
        _listEquals(other.errors, errors) &&
        other.duration == duration;
  }

  @override
  int get hashCode {
    return uploadedCount.hashCode ^
        downloadedCount.hashCode ^
        failedCount.hashCode ^
        errors.hashCode ^
        duration.hashCode;
  }

  @override
  String toString() {
    return 'SyncResult(uploaded: $uploadedCount, downloaded: $downloadedCount, failed: $failedCount, duration: ${duration.inSeconds}s)';
  }

  /// Helper method to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
