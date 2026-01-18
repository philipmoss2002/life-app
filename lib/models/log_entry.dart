/// Log level enum
enum LogLevel {
  info,
  warning,
  error,
}

/// Extension methods for LogLevel
extension LogLevelExtension on LogLevel {
  /// Get a human-readable description
  String get description {
    switch (this) {
      case LogLevel.info:
        return 'Info';
      case LogLevel.warning:
        return 'Warning';
      case LogLevel.error:
        return 'Error';
    }
  }

  /// Get severity as integer (for sorting)
  int get severity {
    switch (this) {
      case LogLevel.info:
        return 0;
      case LogLevel.warning:
        return 1;
      case LogLevel.error:
        return 2;
    }
  }
}

/// Log entry model
///
/// Represents a single log entry for debugging and monitoring.
class LogEntry {
  final int? id;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? errorDetails;
  final String? stackTrace;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.errorDetails,
    this.stackTrace,
  });

  /// Create a new log entry with current timestamp
  factory LogEntry.create({
    required LogLevel level,
    required String message,
    String? errorDetails,
    String? stackTrace,
  }) {
    return LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      errorDetails: errorDetails,
      stackTrace: stackTrace,
    );
  }

  /// Create an info log entry
  factory LogEntry.info(String message) {
    return LogEntry.create(level: LogLevel.info, message: message);
  }

  /// Create a warning log entry
  factory LogEntry.warning(String message) {
    return LogEntry.create(level: LogLevel.warning, message: message);
  }

  /// Create an error log entry
  factory LogEntry.error(
    String message, {
    String? errorDetails,
    String? stackTrace,
  }) {
    return LogEntry.create(
      level: LogLevel.error,
      message: message,
      errorDetails: errorDetails,
      stackTrace: stackTrace,
    );
  }

  /// Create a copy with updated fields
  LogEntry copyWith({
    int? id,
    DateTime? timestamp,
    LogLevel? level,
    String? message,
    String? errorDetails,
    String? stackTrace,
  }) {
    return LogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      message: message ?? this.message,
      errorDetails: errorDetails ?? this.errorDetails,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'errorDetails': errorDetails,
      'stackTrace': stackTrace,
    };
  }

  /// Create from JSON map
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      message: json['message'] as String,
      errorDetails: json['errorDetails'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  /// Convert to database map (for SQLite)
  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'level': level.name,
      'message': message,
      'error_details': errorDetails,
      'stack_trace': stackTrace,
    };
  }

  /// Create from database map (from SQLite)
  factory LogEntry.fromDatabase(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      level: LogLevel.values.firstWhere(
        (e) => e.name == map['level'],
        orElse: () => LogLevel.info,
      ),
      message: map['message'] as String,
      errorDetails: map['error_details'] as String?,
      stackTrace: map['stack_trace'] as String?,
    );
  }

  /// Format log entry as a readable string
  String format() {
    final buffer = StringBuffer();
    buffer.write('[${level.description.toUpperCase()}] ');
    buffer.write('${timestamp.toIso8601String()} - ');
    buffer.write(message);

    if (errorDetails != null) {
      buffer.write('\nError: $errorDetails');
    }

    if (stackTrace != null) {
      buffer.write('\nStack Trace:\n$stackTrace');
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LogEntry &&
        other.id == id &&
        other.timestamp == timestamp &&
        other.level == level &&
        other.message == message &&
        other.errorDetails == errorDetails &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        timestamp.hashCode ^
        level.hashCode ^
        message.hashCode ^
        errorDetails.hashCode ^
        stackTrace.hashCode;
  }

  @override
  String toString() {
    return 'LogEntry(level: ${level.name}, message: $message, timestamp: $timestamp)';
  }
}
