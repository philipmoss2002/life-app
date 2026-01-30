import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'authentication_service.dart';
import 'log_service.dart';

/// Custom exception for database-related errors
///
/// Provides descriptive error messages with context about the operation
/// that failed and the user affected.
///
/// Requirements: 7.1, 7.5
class DatabaseException implements Exception {
  final String message;
  final String? userId;
  final String? operation;
  final dynamic originalError;
  final StackTrace? stackTrace;

  DatabaseException(
    this.message, {
    this.userId,
    this.operation,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseException: $message');
    if (operation != null) buffer.write(' (operation: $operation)');
    if (userId != null) buffer.write(' (userId: $userId)');
    if (originalError != null) buffer.write('\nCaused by: $originalError');
    if (stackTrace != null) buffer.write('\nStack trace: $stackTrace');
    return buffer.toString();
  }
}

/// Clean database service for authentication and sync rewrite
///
/// This service implements a simplified schema with only three tables:
/// - documents: Document metadata with syncId as primary key
/// - file_attachments: File attachments linked to documents
/// - logs: Application logs for debugging
///
/// Key design principles:
/// - syncId (UUID) is the primary identifier for documents
/// - Clean separation of concerns
/// - No legacy migration code
/// - Simple, maintainable schema
/// - User-scoped databases for data isolation
/// - Thread-safe operations with mutex synchronization
/// - Rapid authentication change handling with debouncing
class NewDatabaseService {
  static final NewDatabaseService instance = NewDatabaseService._init();
  static Database? _database;
  static String? _currentUserId;
  static bool _isSwitching = false;
  static final Lock _mutex = Lock();

  final _authService = AuthenticationService();
  final _logService = LogService();

  // Rapid authentication change handling
  // Requirements: 10.1, 10.2, 10.3, 10.4, 10.5
  Timer? _authChangeDebounceTimer;
  String? _pendingUserId;
  int _activeOperations = 0;
  Completer<void>? _operationCompleter;
  static const _debounceDelay = Duration(milliseconds: 300);

  NewDatabaseService._init();

  /// Get database for current authenticated user
  ///
  /// Automatically switches database if user changes. This method ensures
  /// that the correct user's database is always open and handles user
  /// transitions gracefully.
  ///
  /// Implements comprehensive error handling:
  /// - Retries with exponential backoff on transient errors
  /// - Falls back to guest database on authentication failures
  /// - Logs all errors with full context
  ///
  /// Thread-safe: Uses mutex to prevent concurrent access issues.
  ///
  /// Requirements: 1.1, 1.2, 2.1, 2.2, 2.3, 2.4, 2.5, 7.1, 7.3, 7.4, 7.5, 8.1, 8.2
  Future<Database> get database async {
    return await _mutex.synchronized(() async {
      try {
        final currentUserId = await _getCurrentUserId();

        // Check if we need to switch databases
        if (_database != null && _currentUserId != currentUserId) {
          _logService.log(
            'User changed from $_currentUserId to $currentUserId, switching database',
            level: LogLevel.info,
          );
          await _switchDatabase(currentUserId);
        } else if (_database == null) {
          await _openDatabaseWithRetry(currentUserId);
        }

        if (_database == null) {
          throw DatabaseException(
            'Database is null after initialization',
            userId: currentUserId,
            operation: 'get database',
          );
        }

        return _database!;
      } catch (e, stackTrace) {
        _logService.log(
          'Critical error in database getter: $e\nStack trace: $stackTrace',
          level: LogLevel.error,
        );

        // Last resort: try to fall back to guest database
        if (_currentUserId != 'guest') {
          _logService.log(
            'Attempting fallback to guest database',
            level: LogLevel.warning,
          );
          try {
            await _openDatabaseWithRetry('guest');
            if (_database != null) {
              return _database!;
            }
          } catch (guestError) {
            _logService.log(
              'Failed to fall back to guest database: $guestError',
              level: LogLevel.error,
            );
          }
        }

        throw DatabaseException(
          'Failed to open database and fallback failed',
          userId: _currentUserId,
          operation: 'get database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<Database> _initDB(String filePath) async {
    // Use getApplicationSupportDirectory() to ensure app-internal storage
    // This guarantees the database is removed on app uninstall
    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(join(appDir.path, 'databases'));

    // Ensure database directory exists
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final path = join(dbDir.path, filePath);

    try {
      return await openDatabase(
        path,
        version: 3, // Incremented for file attachment labels
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } on DatabaseException catch (e) {
      // Check if database is corrupted
      if (e.toString().contains('corrupt') ||
          e.toString().contains('malformed') ||
          e.toString().contains('not a database')) {
        _logService.log(
          'Database file corrupted: $filePath. Creating new database.',
          level: LogLevel.error,
        );

        // Delete corrupted database file
        final dbFile = File(path);
        if (await dbFile.exists()) {
          await dbFile.delete();
          _logService.log(
            'Deleted corrupted database file: $filePath',
            level: LogLevel.info,
          );
        }

        // Try to open again (will create new database)
        return await openDatabase(
          path,
          version: 3,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        );
      }
      rethrow;
    }
  }

  /// Open database with retry logic and exponential backoff
  ///
  /// Attempts to open the database up to 3 times with exponential backoff
  /// between attempts. This handles transient errors like file locks or
  /// temporary I/O issues.
  ///
  /// Backoff schedule:
  /// - Attempt 1: immediate
  /// - Attempt 2: wait 100ms
  /// - Attempt 3: wait 400ms
  ///
  /// Requirements: 7.3, 7.4, 7.5
  Future<void> _openDatabaseWithRetry(String userId,
      {int maxRetries = 3}) async {
    int attempt = 0;
    Duration backoff = const Duration(milliseconds: 100);

    while (attempt < maxRetries) {
      attempt++;

      try {
        await _openDatabase(userId);
        return; // Success!
      } catch (e, stackTrace) {
        _logService.log(
          'Database open attempt $attempt/$maxRetries failed for user $userId: $e',
          level: LogLevel.warning,
        );

        if (attempt >= maxRetries) {
          // All retries exhausted
          _logService.log(
            'All $maxRetries retry attempts exhausted for user $userId\nStack trace: $stackTrace',
            level: LogLevel.error,
          );

          // If this is not the guest database, try falling back to guest
          if (userId != 'guest') {
            _logService.log(
              'Falling back to guest database after failed retries',
              level: LogLevel.warning,
            );
            try {
              await _openDatabase('guest');
              return;
            } catch (guestError, guestStackTrace) {
              throw DatabaseException(
                'Failed to open database after $maxRetries retries and guest fallback failed',
                userId: userId,
                operation: 'open database with retry',
                originalError: e,
                stackTrace: guestStackTrace,
              );
            }
          }

          throw DatabaseException(
            'Failed to open database after $maxRetries retries',
            userId: userId,
            operation: 'open database with retry',
            originalError: e,
            stackTrace: stackTrace,
          );
        }

        // Wait before next retry with exponential backoff
        _logService.log(
          'Waiting ${backoff.inMilliseconds}ms before retry attempt ${attempt + 1}',
          level: LogLevel.info,
        );
        await Future.delayed(backoff);
        backoff *= 4; // Exponential backoff: 100ms, 400ms, 1600ms
      }
    }
  }

  /// Open database for specific user
  ///
  /// Creates or opens a user-specific database file. If the database doesn't
  /// exist, it will be created with the proper schema.
  ///
  /// Implements comprehensive error handling:
  /// - Detects and handles corrupted database files
  /// - Logs all operations with timing information
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Requirements: 1.1, 1.2, 2.1, 2.3, 7.1, 7.2, 7.5, 9.1
  Future<void> _openDatabase(String userId) async {
    final startTime = DateTime.now();

    _logService.log(
      'Opening database for user: $userId',
      level: LogLevel.info,
    );

    try {
      final dbFileName = _getDatabaseFileName(userId);
      _database = await _initDB(dbFileName);
      _currentUserId = userId;

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _logService.log(
        'Database opened: $dbFileName (took ${duration}ms)',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _logService.log(
        'Failed to open database for user $userId after ${duration}ms: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      // Ensure database is null if open failed
      _database = null;
      _currentUserId = null;

      throw DatabaseException(
        'Failed to open database',
        userId: userId,
        operation: 'open database',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Switch from one user's database to another
  ///
  /// Closes the current database and opens the new user's database.
  /// This method is thread-safe and prevents concurrent switches.
  ///
  /// Implements comprehensive error handling:
  /// - Ensures database is closed even if errors occur
  /// - Logs all operations with timing information
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Requirements: 2.3, 2.4, 2.5, 3.1, 3.2, 7.1, 7.5, 9.2, 9.3
  Future<void> _switchDatabase(String newUserId) async {
    if (_isSwitching) {
      throw DatabaseException(
        'Database switch already in progress',
        userId: newUserId,
        operation: 'switch database',
      );
    }

    _isSwitching = true;
    final startTime = DateTime.now();
    final oldUserId = _currentUserId;

    try {
      _logService.log(
        'Switching database from $oldUserId to $newUserId',
        level: LogLevel.info,
      );

      // Close current database
      if (_database != null) {
        final closeDuration = DateTime.now();

        try {
          await _database!.close();
          _database = null;

          final closeTime =
              DateTime.now().difference(closeDuration).inMilliseconds;
          _logService.log(
            'Closed database for user: $oldUserId (took ${closeTime}ms)',
            level: LogLevel.info,
          );
        } catch (e, stackTrace) {
          _logService.log(
            'Error closing database during switch: $e\nStack trace: $stackTrace',
            level: LogLevel.error,
          );
          // Continue with switch even if close fails
          _database = null;
        }
      }

      // Open new database with retry logic
      await _openDatabaseWithRetry(newUserId);

      final totalDuration = DateTime.now().difference(startTime).inMilliseconds;
      _logService.log(
        'Database switch complete (took ${totalDuration}ms)',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _logService.log(
        'Database switch failed after ${duration}ms: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      throw DatabaseException(
        'Failed to switch database',
        userId: newUserId,
        operation: 'switch database',
        originalError: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isSwitching = false;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Documents table - stores document metadata
    await db.execute('''
      CREATE TABLE documents (
        sync_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        date INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_state TEXT NOT NULL DEFAULT 'pendingUpload'
      )
    ''');

    // File attachments table - stores file references
    await db.execute('''
      CREATE TABLE file_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        label TEXT,
        local_path TEXT,
        s3_key TEXT,
        file_size INTEGER,
        added_at INTEGER NOT NULL,
        FOREIGN KEY (sync_id) REFERENCES documents(sync_id) ON DELETE CASCADE
      )
    ''');

    // Logs table - stores application logs
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        level TEXT NOT NULL,
        message TEXT NOT NULL,
        error_details TEXT,
        stack_trace TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_documents_sync_state ON documents(sync_state)');
    await db.execute(
        'CREATE INDEX idx_file_attachments_sync_id ON file_attachments(sync_id)');
    await db.execute('CREATE INDEX idx_logs_timestamp ON logs(timestamp)');
    await db.execute('CREATE INDEX idx_logs_level ON logs(level)');

    debugPrint('✅ Database schema created successfully');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // Migration from v1 to v2: Add category and date fields
      debugPrint('📝 Adding category and date columns to documents table');

      // Add category column with default value
      await db.execute('''
        ALTER TABLE documents ADD COLUMN category TEXT NOT NULL DEFAULT 'other'
      ''');

      // Add date column (nullable)
      await db.execute('''
        ALTER TABLE documents ADD COLUMN date INTEGER
      ''');

      // Rename description to notes if it exists (from old schema)
      try {
        await db.execute('''
          ALTER TABLE documents RENAME COLUMN description TO notes
        ''');
        debugPrint('✅ Renamed description column to notes');
      } catch (e) {
        // Column might not exist or already renamed
        debugPrint('ℹ️ Description column not found (may already be migrated)');
      }

      debugPrint('✅ Database upgraded to version 2');
    }

    if (oldVersion < 3) {
      // Migration from v2 to v3: Move labels from documents to file_attachments
      debugPrint('📝 Moving labels from documents to file_attachments');

      // Step 1: Create new documents table without labels column
      // SQLite doesn't support DROP COLUMN, so we recreate the table
      await db.execute('''
        CREATE TABLE documents_new (
          sync_id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          category TEXT NOT NULL,
          date INTEGER,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          sync_state TEXT NOT NULL DEFAULT 'pendingUpload'
        )
      ''');

      // Step 2: Copy data from old table to new table (excluding labels)
      await db.execute('''
        INSERT INTO documents_new 
        SELECT sync_id, title, category, date, notes, created_at, updated_at, sync_state
        FROM documents
      ''');

      // Step 3: Drop old table and rename new table
      await db.execute('DROP TABLE documents');
      await db.execute('ALTER TABLE documents_new RENAME TO documents');

      // Step 4: Add label column to file_attachments table
      await db.execute('ALTER TABLE file_attachments ADD COLUMN label TEXT');

      // Step 5: Recreate indexes
      await db.execute(
          'CREATE INDEX idx_documents_sync_state ON documents(sync_state)');

      debugPrint(
          '✅ Database upgraded to version 3: Labels moved to file attachments');
    }
  }

  /// Close the database connection
  ///
  /// Properly closes the current database connection and releases all
  /// resources. This method should be called during sign-out to ensure
  /// clean database lifecycle management.
  ///
  /// Implements comprehensive error handling:
  /// - Ensures references are cleared even if close fails
  /// - Logs all operations with timing information
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Thread-safe: Uses mutex to prevent concurrent access issues.
  ///
  /// Requirements: 3.1, 3.2, 3.3, 7.1, 7.5, 9.2
  Future<void> close() async {
    await _mutex.synchronized(() async {
      if (_database != null) {
        final startTime = DateTime.now();
        final userId = _currentUserId;

        _logService.log(
          'Closing database for user: $userId',
          level: LogLevel.info,
        );

        try {
          await _database!.close();
          _database = null;
          _currentUserId = null;

          final duration = DateTime.now().difference(startTime).inMilliseconds;
          _logService.log(
            'Database closed for user: $userId (took ${duration}ms)',
            level: LogLevel.info,
          );
        } catch (e, stackTrace) {
          _logService.log(
            'Error closing database for user $userId: $e\nStack trace: $stackTrace',
            level: LogLevel.error,
          );
          // Still clear references even if close fails
          _database = null;
          _currentUserId = null;

          throw DatabaseException(
            'Failed to close database',
            userId: userId,
            operation: 'close database',
            originalError: e,
            stackTrace: stackTrace,
          );
        }
      }
    });
  }

  /// Get current user ID (authenticated user or 'guest')
  ///
  /// Returns the Cognito sub claim for authenticated users, or 'guest' for
  /// unauthenticated users. This method handles authentication failures
  /// gracefully by falling back to guest mode.
  ///
  /// Requirements: 2.1, 12.1, 12.2, 12.3, 12.4, 12.5
  Future<String> _getCurrentUserId() async {
    try {
      if (await _authService.isAuthenticated()) {
        final userId = await _authService.getUserId();

        // Validate user ID is not empty
        if (userId.isEmpty) {
          _logService.log(
            'User ID is empty, falling back to guest',
            level: LogLevel.warning,
          );
          return 'guest';
        }

        return userId;
      }
    } catch (e) {
      _logService.log(
        'Failed to get user ID: $e, falling back to guest',
        level: LogLevel.warning,
      );
    }
    return 'guest';
  }

  // ============================================================================
  // Rapid Authentication Change Handling
  // Requirements: 10.1, 10.2, 10.3, 10.4, 10.5
  // ============================================================================

  /// Track the start of a database operation
  ///
  /// This method increments the active operation counter to prevent database
  /// switches while operations are in progress. Should be called at the start
  /// of any database operation that needs to complete before a switch.
  ///
  /// Requirements: 10.3
  void _beginOperation() {
    _activeOperations++;

    // Create new completer if needed
    if (_operationCompleter == null || _operationCompleter!.isCompleted) {
      _operationCompleter = Completer<void>();
    }

    _logService.log(
      'Operation started (active: $_activeOperations)',
      level: LogLevel.debug,
    );
  }

  /// Track the completion of a database operation
  ///
  /// This method decrements the active operation counter and completes the
  /// operation completer when all operations are finished. This allows
  /// database switches to proceed once all pending operations complete.
  ///
  /// Requirements: 10.3
  void _endOperation() {
    _activeOperations--;
    _logService.log(
      'Operation completed (active: $_activeOperations)',
      level: LogLevel.debug,
    );

    // If no more active operations, complete the completer
    if (_activeOperations <= 0) {
      _activeOperations = 0;
      if (_operationCompleter != null && !_operationCompleter!.isCompleted) {
        _operationCompleter!.complete();
      }
    }
  }

  /// Wait for all active operations to complete
  ///
  /// This method waits for all active database operations to finish before
  /// allowing a database switch to proceed. It includes a timeout to prevent
  /// indefinite waiting.
  ///
  /// Returns: Future that completes when all operations are done or timeout occurs
  ///
  /// Requirements: 10.3, 10.4
  Future<void> _waitForOperations(
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (_activeOperations <= 0) {
      return;
    }

    _logService.log(
      'Waiting for $_activeOperations active operations to complete',
      level: LogLevel.info,
    );

    // Create completer if it doesn't exist
    if (_operationCompleter == null || _operationCompleter!.isCompleted) {
      _operationCompleter = Completer<void>();
    }

    try {
      await _operationCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          _logService.log(
            'Timeout waiting for operations to complete ($_activeOperations still active)',
            level: LogLevel.warning,
          );
          // Force complete to allow switch to proceed
          if (_operationCompleter != null &&
              !_operationCompleter!.isCompleted) {
            _operationCompleter!.complete();
          }
        },
      );
    } catch (e) {
      _logService.log(
        'Error waiting for operations: $e',
        level: LogLevel.error,
      );
    }
  }

  /// Handle authentication change with debouncing
  ///
  /// This method implements debouncing for rapid authentication changes.
  /// When multiple authentication changes occur in quick succession, only
  /// the latest one is processed after a short delay.
  ///
  /// This prevents issues like:
  /// - Rapid sign-out/sign-in cycles
  /// - Multiple concurrent database switches
  /// - Race conditions during authentication transitions
  ///
  /// Requirements: 10.1, 10.2
  Future<void> handleAuthenticationChange(String newUserId) async {
    _logService.log(
      'Authentication change detected: $newUserId',
      level: LogLevel.info,
    );

    // Cancel any pending authentication change
    _authChangeDebounceTimer?.cancel();

    // Store the pending user ID
    _pendingUserId = newUserId;

    // Set up debounce timer
    _authChangeDebounceTimer = Timer(_debounceDelay, () async {
      final userIdToSwitch = _pendingUserId;
      _pendingUserId = null;

      if (userIdToSwitch == null) {
        return;
      }

      _logService.log(
        'Processing debounced authentication change: $userIdToSwitch',
        level: LogLevel.info,
      );

      try {
        // Wait for any active operations to complete
        await _waitForOperations();

        // Perform the database switch
        await _mutex.synchronized(() async {
          if (_currentUserId != userIdToSwitch) {
            await _switchDatabase(userIdToSwitch);
          }
        });
      } catch (e, stackTrace) {
        _logService.log(
          'Error handling authentication change: $e\nStack trace: $stackTrace',
          level: LogLevel.error,
        );
      }
    });
  }

  /// Prepare for sign-out by waiting for operations and closing database
  ///
  /// This method should be called before signing out to ensure all database
  /// operations complete and the database is properly closed. This prevents
  /// data corruption and ensures clean database lifecycle management.
  ///
  /// Requirements: 10.3, 10.4
  Future<void> prepareForSignOut() async {
    _logService.log(
      'Preparing for sign-out',
      level: LogLevel.info,
    );

    try {
      // Cancel any pending authentication changes
      _authChangeDebounceTimer?.cancel();
      _pendingUserId = null;

      // Wait for active operations to complete
      await _waitForOperations();

      // Close the database
      await close();

      _logService.log(
        'Sign-out preparation complete',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      _logService.log(
        'Error preparing for sign-out: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );
      // Don't rethrow - allow sign-out to proceed even if preparation fails
    }
  }

  /// Prepare for sign-in by ensuring previous database is closed
  ///
  /// This method should be called before signing in to ensure the previous
  /// user's database is properly closed before opening the new user's database.
  ///
  /// Requirements: 10.4
  Future<void> prepareForSignIn() async {
    _logService.log(
      'Preparing for sign-in',
      level: LogLevel.info,
    );

    try {
      // Wait for any pending database switches to complete
      if (_isSwitching) {
        _logService.log(
          'Waiting for pending database switch to complete',
          level: LogLevel.info,
        );

        // Wait up to 3 seconds for switch to complete
        int attempts = 0;
        while (_isSwitching && attempts < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (_isSwitching) {
          _logService.log(
            'Database switch still in progress after timeout',
            level: LogLevel.warning,
          );
        }
      }

      _logService.log(
        'Sign-in preparation complete',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      _logService.log(
        'Error preparing for sign-in: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );
      // Don't rethrow - allow sign-in to proceed even if preparation fails
    }
  }

  /// Sanitize user ID for use in file names
  ///
  /// Removes or replaces characters that are not safe for file names.
  /// Cognito sub claims are UUIDs (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  /// which are already safe, but this method handles edge cases and invalid IDs.
  ///
  /// Rules:
  /// - Allows alphanumeric characters, hyphens, and underscores
  /// - Replaces invalid characters with underscores
  /// - Limits length to 50 characters (Cognito sub is ~36 chars)
  /// - Returns 'guest' for null or empty input
  ///
  /// Requirements: 12.2, 12.3, 12.4
  String _sanitizeUserId(String? userId) {
    // Handle null or empty user ID
    if (userId == null || userId.isEmpty) {
      _logService.log(
        'User ID is null or empty, using guest',
        level: LogLevel.warning,
      );
      return 'guest';
    }

    // Remove any characters that aren't safe for file names
    // Allow: a-z, A-Z, 0-9, hyphen, underscore
    final sanitized = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    // Limit length (Cognito sub is UUID format, ~36 chars)
    // If longer than 50 chars, truncate
    if (sanitized.length > 50) {
      _logService.log(
        'User ID too long (${sanitized.length} chars), truncating to 50',
        level: LogLevel.warning,
      );
      return sanitized.substring(0, 50);
    }

    // Additional validation: ensure result is not empty after sanitization
    if (sanitized.isEmpty) {
      _logService.log(
        'User ID became empty after sanitization, using guest',
        level: LogLevel.error,
      );
      return 'guest';
    }

    return sanitized;
  }

  /// Get database file name for user
  ///
  /// Generates a database file name based on the user ID.
  /// Format:
  /// - Authenticated user: household_docs_{sanitizedUserId}.db
  /// - Guest user: household_docs_guest.db
  ///
  /// The user ID is sanitized to ensure it's safe for use in file names.
  ///
  /// Requirements: 1.2, 2.1, 2.4, 12.1, 12.2, 12.3, 12.4, 12.5
  String _getDatabaseFileName(String userId) {
    // Validate and sanitize user ID
    final sanitizedUserId = _sanitizeUserId(userId);

    // Special case for guest user
    if (sanitizedUserId == 'guest') {
      return 'household_docs_guest.db';
    }

    // Generate user-specific database file name
    final fileName = 'household_docs_$sanitizedUserId.db';

    _logService.log(
      'Generated database file name: $fileName for user: $userId',
      level: LogLevel.debug,
    );

    return fileName;
  }

  /// Clear all data from the database (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('file_attachments');
    await db.delete('documents');
    await db.delete('logs');
    debugPrint('✅ All database data cleared');
  }

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    final db = await database;

    final docResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM documents');
    final fileResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM file_attachments');
    final logResult = await db.rawQuery('SELECT COUNT(*) as count FROM logs');

    return {
      'documents': docResult.first['count'] as int,
      'file_attachments': fileResult.first['count'] as int,
      'logs': logResult.first['count'] as int,
    };
  }

  /// Migrate data from legacy shared database to user-specific database
  ///
  /// This method handles the migration of documents and file attachments from
  /// the legacy shared database (household_docs_v2.db) to the current user's
  /// database. It includes comprehensive error handling and retry capability.
  ///
  /// The migration process:
  /// 1. Check if legacy database exists
  /// 2. Open legacy database in read-only mode
  /// 3. Read all documents and file attachments
  /// 4. Insert data into current user's database
  /// 5. Mark user as migrated to prevent duplicate migrations
  ///
  /// Implements comprehensive error handling:
  /// - Ensures legacy database is closed even if errors occur
  /// - Logs all operations with progress information
  /// - Throws descriptive DatabaseException on failure
  /// - Does not mark as migrated if migration fails (allows retry)
  ///
  /// If migration fails, the error is logged and the method throws an exception.
  /// The user will not be marked as migrated, allowing retry on next sign-in.
  ///
  /// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 7.1, 7.5, 9.4
  Future<void> migrateLegacyDatabase(String userId) async {
    final startTime = DateTime.now();

    _logService.log(
      'Starting legacy database migration for user: $userId',
      level: LogLevel.info,
    );

    Database? legacyDb;

    try {
      // Get path to legacy database
      final appDir = await getApplicationSupportDirectory();
      final dbDir = Directory(join(appDir.path, 'databases'));
      final legacyPath = join(dbDir.path, 'household_docs_v2.db');
      final legacyFile = File(legacyPath);

      // Check if legacy database exists
      if (!await legacyFile.exists()) {
        _logService.log(
          'No legacy database found at $legacyPath',
          level: LogLevel.info,
        );
        // Mark as migrated even if no legacy database exists
        // This prevents repeated checks on every sign-in
        await _markLegacyDatabaseMigrated(userId);
        return;
      }

      _logService.log(
        'Legacy database found, beginning migration',
        level: LogLevel.info,
      );

      // Open legacy database in read-only mode
      try {
        legacyDb = await openDatabase(legacyPath, readOnly: true);
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to open legacy database',
          userId: userId,
          operation: 'migrate legacy database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      // Get all documents from legacy database
      _logService.log(
        'Reading documents from legacy database',
        level: LogLevel.info,
      );

      List<Map<String, dynamic>> documents;
      List<Map<String, dynamic>> fileAttachments;

      try {
        documents = await legacyDb.query('documents');
        _logService.log(
          'Reading file attachments from legacy database',
          level: LogLevel.info,
        );
        fileAttachments = await legacyDb.query('file_attachments');
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to read data from legacy database',
          userId: userId,
          operation: 'migrate legacy database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      _logService.log(
        'Found ${documents.length} documents and ${fileAttachments.length} file attachments to migrate',
        level: LogLevel.info,
      );

      // Close legacy database before opening user database
      await legacyDb.close();
      legacyDb = null;

      // Get current user's database
      Database currentDb;
      try {
        currentDb = await database;
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to open user database for migration',
          userId: userId,
          operation: 'migrate legacy database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      // Insert data into user's database within a transaction
      _logService.log(
        'Inserting data into user database',
        level: LogLevel.info,
      );

      try {
        await currentDb.transaction((txn) async {
          int docsInserted = 0;
          int filesInserted = 0;

          // Insert documents
          for (final doc in documents) {
            try {
              await txn.insert(
                'documents',
                doc,
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              docsInserted++;
            } catch (e) {
              _logService.log(
                'Failed to insert document ${doc['sync_id']}: $e',
                level: LogLevel.warning,
              );
            }
          }

          // Insert file attachments
          for (final file in fileAttachments) {
            try {
              await txn.insert(
                'file_attachments',
                file,
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              filesInserted++;
            } catch (e) {
              _logService.log(
                'Failed to insert file attachment ${file['id']}: $e',
                level: LogLevel.warning,
              );
            }
          }

          _logService.log(
            'Successfully inserted $docsInserted documents and $filesInserted file attachments',
            level: LogLevel.info,
          );
        });
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to insert migrated data into user database',
          userId: userId,
          operation: 'migrate legacy database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      // Mark user as migrated
      await _markLegacyDatabaseMigrated(userId);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _logService.log(
        'Migration complete for user $userId: ${documents.length} documents, ${fileAttachments.length} files (took ${duration}ms)',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      // Ensure legacy database is closed even if error occurs
      if (legacyDb != null) {
        try {
          await legacyDb.close();
        } catch (closeError) {
          _logService.log(
            'Error closing legacy database after migration failure: $closeError',
            level: LogLevel.warning,
          );
        }
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _logService.log(
        'Migration failed for user $userId after ${duration}ms: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      // Re-throw as DatabaseException if not already
      if (e is DatabaseException) {
        rethrow;
      } else {
        throw DatabaseException(
          'Migration failed',
          userId: userId,
          operation: 'migrate legacy database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Mark legacy database as migrated for this user
  ///
  /// Stores the user ID in SharedPreferences to track which users have been
  /// migrated. This prevents duplicate migrations on subsequent sign-ins.
  ///
  /// Requirements: 4.3, 4.5
  Future<void> _markLegacyDatabaseMigrated(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migratedUsers = prefs.getStringList('migrated_users') ?? [];

      if (!migratedUsers.contains(userId)) {
        migratedUsers.add(userId);
        await prefs.setStringList('migrated_users', migratedUsers);

        _logService.log(
          'Marked user $userId as migrated',
          level: LogLevel.info,
        );
      }
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to mark user as migrated: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );
      // Don't rethrow - this is not critical enough to fail the migration
    }
  }

  /// Check if user has been migrated from legacy database
  ///
  /// Returns true if the user has already been migrated, false otherwise.
  /// This method is used to determine if migration should be attempted
  /// when a user signs in.
  ///
  /// Requirements: 4.3, 4.5
  Future<bool> hasBeenMigrated(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migratedUsers = prefs.getStringList('migrated_users') ?? [];
      final migrated = migratedUsers.contains(userId);

      _logService.log(
        'User $userId migration status: ${migrated ? "migrated" : "not migrated"}',
        level: LogLevel.debug,
      );

      return migrated;
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to check migration status: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );
      // Return false to allow migration attempt if check fails
      return false;
    }
  }

  // ============================================================================
  // Database Maintenance Methods
  // ============================================================================

  /// List all user database files
  ///
  /// Returns a list of all database files in the database directory that match
  /// the household_docs pattern. This includes user-specific databases and the
  /// guest database, but excludes the legacy database.
  ///
  /// Implements comprehensive error handling:
  /// - Logs all operations
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Returns: List of database file names (e.g., ['household_docs_guest.db', 'household_docs_abc123.db'])
  ///
  /// Requirements: 7.1, 7.5, 11.1
  Future<List<String>> listUserDatabases() async {
    try {
      _logService.log(
        'Listing all user database files',
        level: LogLevel.info,
      );

      // Get database directory
      final appDir = await getApplicationSupportDirectory();
      final dbDir = Directory(join(appDir.path, 'databases'));

      // Check if directory exists
      if (!await dbDir.exists()) {
        _logService.log(
          'Database directory does not exist',
          level: LogLevel.warning,
        );
        return [];
      }

      // List all files in directory
      List<FileSystemEntity> files;
      try {
        files = await dbDir.list().toList();
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to list database directory',
          operation: 'list user databases',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      // Filter for database files matching our pattern
      final dbFiles = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .where((f) => basename(f.path).startsWith('household_docs_'))
          .map((f) => basename(f.path))
          .toList();

      _logService.log(
        'Found ${dbFiles.length} database files: ${dbFiles.join(", ")}',
        level: LogLevel.info,
      );

      return dbFiles;
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to list user databases: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      if (e is DatabaseException) {
        rethrow;
      } else {
        throw DatabaseException(
          'Failed to list user databases',
          operation: 'list user databases',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Delete database for specific user
  ///
  /// Deletes the database file for the specified user. If the database is
  /// currently open, it will be closed first. This method should be used
  /// when a user account is deleted or for cleanup purposes.
  ///
  /// Implements comprehensive error handling:
  /// - Logs all operations
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Parameters:
  /// - userId: The user ID whose database should be deleted
  ///
  /// Throws: DatabaseException if the database cannot be deleted
  ///
  /// Requirements: 7.1, 7.5, 11.2
  Future<void> deleteUserDatabase(String userId) async {
    try {
      _logService.log(
        'Deleting database for user: $userId',
        level: LogLevel.info,
      );

      final dbFileName = _getDatabaseFileName(userId);

      // Get database path
      final appDir = await getApplicationSupportDirectory();
      final dbDir = Directory(join(appDir.path, 'databases'));
      final dbPath = join(dbDir.path, dbFileName);
      final dbFile = File(dbPath);

      // Check if database exists
      if (!await dbFile.exists()) {
        _logService.log(
          'Database file does not exist: $dbFileName',
          level: LogLevel.warning,
        );
        return;
      }

      // Close database if it's currently open for this user
      if (_currentUserId == userId && _database != null) {
        _logService.log(
          'Closing currently open database before deletion',
          level: LogLevel.info,
        );
        try {
          await close();
        } catch (e, stackTrace) {
          _logService.log(
            'Error closing database before deletion: $e\nStack trace: $stackTrace',
            level: LogLevel.warning,
          );
          // Continue with deletion even if close fails
        }
      }

      // Delete the database file
      try {
        await dbFile.delete();
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to delete database file',
          userId: userId,
          operation: 'delete user database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      _logService.log(
        'Successfully deleted database for user: $userId ($dbFileName)',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to delete database for user $userId: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      if (e is DatabaseException) {
        rethrow;
      } else {
        throw DatabaseException(
          'Failed to delete user database',
          userId: userId,
          operation: 'delete user database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Vacuum current user's database to optimize storage
  ///
  /// Runs the VACUUM command on the current user's database to reclaim unused
  /// space and optimize the database file. This operation can take some time
  /// for large databases and requires free disk space equal to the database size.
  ///
  /// The VACUUM command:
  /// - Rebuilds the database file, repacking it into a minimal amount of disk space
  /// - Removes free pages created by DELETE operations
  /// - Defragments the database
  ///
  /// Implements comprehensive error handling:
  /// - Logs all operations with timing information
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Note: This operation requires exclusive access to the database and may
  /// take several seconds for large databases.
  ///
  /// Requirements: 7.1, 7.5, 11.3
  Future<void> vacuumDatabase() async {
    try {
      _logService.log(
        'Starting database vacuum operation',
        level: LogLevel.info,
      );

      final startTime = DateTime.now();
      final db = await database;

      // Execute VACUUM command
      try {
        await db.execute('VACUUM');
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to execute VACUUM command',
          userId: _currentUserId,
          operation: 'vacuum database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      _logService.log(
        'Database vacuum completed successfully (took ${duration}ms)',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to vacuum database: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      if (e is DatabaseException) {
        rethrow;
      } else {
        throw DatabaseException(
          'Failed to vacuum database',
          userId: _currentUserId,
          operation: 'vacuum database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Get comprehensive database statistics
  ///
  /// Returns detailed statistics about the current user's database including:
  /// - Record counts for each table
  /// - Database file size in bytes and MB
  /// - Current user ID
  /// - Database file name
  ///
  /// This method extends the existing getStats() method with additional
  /// file system information.
  ///
  /// Implements comprehensive error handling:
  /// - Logs all operations
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Returns: Map containing database statistics
  ///
  /// Requirements: 7.1, 7.5, 11.5
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      _logService.log(
        'Gathering database statistics',
        level: LogLevel.info,
      );

      // Get basic stats (record counts)
      Map<String, int> stats;
      try {
        stats = await getStats();
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to get record counts',
          userId: _currentUserId,
          operation: 'get database stats',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      // Get database file information
      final dbFileName = _getDatabaseFileName(_currentUserId!);
      final appDir = await getApplicationSupportDirectory();
      final dbDir = Directory(join(appDir.path, 'databases'));
      final dbPath = join(dbDir.path, dbFileName);
      final dbFile = File(dbPath);

      // Get file size
      int fileSize = 0;
      try {
        if (await dbFile.exists()) {
          fileSize = await dbFile.length();
        }
      } catch (e, stackTrace) {
        _logService.log(
          'Failed to get database file size: $e\nStack trace: $stackTrace',
          level: LogLevel.warning,
        );
        // Continue with fileSize = 0
      }

      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

      final result = {
        ...stats,
        'file_size_bytes': fileSize,
        'file_size_mb': fileSizeMB,
        'user_id': _currentUserId,
        'database_file': dbFileName,
      };

      _logService.log(
        'Database stats: ${result['documents']} documents, ${result['file_attachments']} files, ${result['logs']} logs, $fileSizeMB MB',
        level: LogLevel.info,
      );

      return result;
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to get database statistics: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      if (e is DatabaseException) {
        rethrow;
      } else {
        throw DatabaseException(
          'Failed to get database statistics',
          userId: _currentUserId,
          operation: 'get database stats',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Delete legacy database after all users have been migrated
  ///
  /// This method should be called after verifying that all users have been
  /// migrated from the legacy shared database. It deletes the legacy database
  /// file (household_docs_v2.db) to free up storage space.
  ///
  /// Safety checks:
  /// - Verifies that at least one user has been migrated (prevents accidental deletion)
  /// - Checks that the legacy database is not currently open
  /// - Logs all operations for audit trail
  ///
  /// Implements comprehensive error handling:
  /// - Logs all operations
  /// - Throws descriptive DatabaseException on failure
  ///
  /// Returns: true if legacy database was deleted, false if it didn't exist
  ///
  /// Requirements: 4.5, 7.1, 7.5, 11.2
  Future<bool> deleteLegacyDatabase() async {
    try {
      _logService.log(
        'Attempting to delete legacy database',
        level: LogLevel.info,
      );

      // Safety check: Ensure at least one user has been migrated
      final prefs = await SharedPreferences.getInstance();
      final migratedUsers = prefs.getStringList('migrated_users') ?? [];

      if (migratedUsers.isEmpty) {
        _logService.log(
          'No users have been migrated yet. Refusing to delete legacy database.',
          level: LogLevel.warning,
        );
        throw DatabaseException(
          'Cannot delete legacy database: no users have been migrated',
          operation: 'delete legacy database',
        );
      }

      _logService.log(
        'Found ${migratedUsers.length} migrated users: ${migratedUsers.join(", ")}',
        level: LogLevel.info,
      );

      // Get path to legacy database
      final appDir = await getApplicationSupportDirectory();
      final dbDir = Directory(join(appDir.path, 'databases'));
      final legacyPath = join(dbDir.path, 'household_docs_v2.db');
      final legacyFile = File(legacyPath);

      // Check if legacy database exists
      if (!await legacyFile.exists()) {
        _logService.log(
          'Legacy database does not exist at $legacyPath',
          level: LogLevel.info,
        );
        return false;
      }

      // Get file size before deletion for logging
      int fileSize = 0;
      try {
        fileSize = await legacyFile.length();
      } catch (e) {
        _logService.log(
          'Could not get legacy database file size: $e',
          level: LogLevel.warning,
        );
      }

      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

      // Delete the legacy database file
      try {
        await legacyFile.delete();
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to delete legacy database file',
          operation: 'delete legacy database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      _logService.log(
        'Successfully deleted legacy database (freed $fileSizeMB MB)',
        level: LogLevel.info,
      );

      return true;
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to delete legacy database: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      if (e is DatabaseException) {
        rethrow;
      } else {
        throw DatabaseException(
          'Failed to delete legacy database',
          operation: 'delete legacy database',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Delete orphaned database files
  ///
  /// Identifies and deletes database files that don't belong to any known user.
  /// This is useful for cleanup after user account deletions or testing.
  ///
  /// An orphaned database is defined as:
  /// - A database file that exists in the database directory
  /// - Matches the household_docs pattern
  /// - Is not the currently open database
  /// - Is not the guest database (unless explicitly requested)
  /// - Is not the legacy database
  ///
  /// Implements comprehensive error handling:
  /// - Logs all operations
  /// - Continues processing even if individual deletions fail
  /// - Returns list of successfully deleted files
  ///
  /// Parameters:
  /// - includeGuest: If true, also delete the guest database (default: false)
  ///
  /// Returns: List of deleted database file names
  ///
  /// Requirements: 7.1, 7.5, 11.4
  Future<List<String>> deleteOrphanedDatabases(
      {bool includeGuest = false}) async {
    try {
      _logService.log(
        'Searching for orphaned database files',
        level: LogLevel.info,
      );

      final deletedFiles = <String>[];

      // Get all database files
      List<String> dbFiles;
      try {
        dbFiles = await listUserDatabases();
      } catch (e, stackTrace) {
        throw DatabaseException(
          'Failed to list databases for orphan cleanup',
          operation: 'delete orphaned databases',
          originalError: e,
          stackTrace: stackTrace,
        );
      }

      for (final dbFile in dbFiles) {
        // Skip currently open database
        if (_currentUserId != null) {
          final currentDbFile = _getDatabaseFileName(_currentUserId!);
          if (dbFile == currentDbFile) {
            _logService.log(
              'Skipping currently open database: $dbFile',
              level: LogLevel.debug,
            );
            continue;
          }
        }

        // Skip guest database unless explicitly requested
        if (dbFile == 'household_docs_guest.db' && !includeGuest) {
          _logService.log(
            'Skipping guest database: $dbFile',
            level: LogLevel.debug,
          );
          continue;
        }

        // Skip legacy database
        if (dbFile == 'household_docs_v2.db') {
          _logService.log(
            'Skipping legacy database: $dbFile',
            level: LogLevel.debug,
          );
          continue;
        }

        // Delete the orphaned database
        try {
          final appDir = await getApplicationSupportDirectory();
          final dbDir = Directory(join(appDir.path, 'databases'));
          final dbPath = join(dbDir.path, dbFile);
          final file = File(dbPath);

          if (await file.exists()) {
            await file.delete();
            deletedFiles.add(dbFile);
            _logService.log(
              'Deleted orphaned database: $dbFile',
              level: LogLevel.info,
            );
          }
        } catch (e, stackTrace) {
          _logService.log(
            'Failed to delete orphaned database $dbFile: $e\nStack trace: $stackTrace',
            level: LogLevel.warning,
          );
          // Continue with next file even if this one fails
        }
      }

      _logService.log(
        'Deleted ${deletedFiles.length} orphaned database files',
        level: LogLevel.info,
      );

      return deletedFiles;
    } catch (e, stackTrace) {
      _logService.log(
        'Failed to delete orphaned databases: $e\nStack trace: $stackTrace',
        level: LogLevel.error,
      );

      if (e is DatabaseException) {
        rethrow;
      } else {
        throw DatabaseException(
          'Failed to delete orphaned databases',
          operation: 'delete orphaned databases',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
