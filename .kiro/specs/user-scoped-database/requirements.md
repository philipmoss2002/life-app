# Requirements Document

## Introduction

This specification addresses a critical security vulnerability where users can see documents from previous users due to a shared local SQLite database. The solution implements user-scoped databases where each authenticated user has their own isolated database file, ensuring complete data privacy and security. This feature will create separate database files per user, manage database lifecycle during authentication events, and migrate existing data to the new user-scoped structure.

## Glossary

- **User-Scoped Database**: A SQLite database file that is uniquely associated with a specific user, identified by their Cognito User ID (sub claim)
- **Cognito User ID**: The unique identifier (sub claim) from AWS Cognito that persists across sessions for an authenticated user
- **Database Service**: The NewDatabaseService class that manages SQLite database connections and operations
- **Authentication Service**: The AuthenticationService class that manages user authentication via AWS Cognito
- **Database Migration**: The process of moving data from the legacy shared database to user-specific databases
- **Guest Database**: A temporary database used when no user is authenticated, for offline-first functionality
- **Database Lifecycle**: The sequence of opening, using, and closing database connections tied to authentication events
- **File Attachments**: Local files stored on disk that are referenced by documents in the database
- **Legacy Database**: The existing shared database file (household_docs_v2.db) that is not user-scoped

## Requirements

### Requirement 1

**User Story:** As a user, I want my documents to be stored in a separate database from other users, so that my data remains private and isolated.

#### Acceptance Criteria

1. WHEN a user signs in THEN the system SHALL create or open a database file named with the user's Cognito User ID
2. WHEN the database file is created THEN the system SHALL use the format "household_docs_{userId}.db" where userId is the Cognito sub claim
3. WHEN a user's database is opened THEN the system SHALL ensure no other user can access that database file
4. WHEN multiple users sign in on the same device THEN the system SHALL maintain separate database files for each user
5. WHEN a user signs in again after signing out THEN the system SHALL open their existing database file with all their previous data intact

### Requirement 2

**User Story:** As a developer, I want the database service to track which user's database is currently open, so that database operations are always performed on the correct user's data.

#### Acceptance Criteria

1. WHEN the database service initializes THEN the system SHALL track the currently authenticated user's ID
2. WHEN a database operation is requested THEN the system SHALL verify the correct user's database is open
3. WHEN the authenticated user changes THEN the system SHALL close the previous database and open the new user's database
4. WHEN no user is authenticated THEN the system SHALL use a guest database for offline functionality
5. WHEN the system detects a user mismatch THEN the system SHALL automatically switch to the correct user's database before performing operations

### Requirement 3

**User Story:** As a user, I want my local data to be cleared when I sign out, so that the next user on this device cannot access my information.

#### Acceptance Criteria

1. WHEN a user signs out THEN the system SHALL close the user's database connection
2. WHEN the database connection is closed THEN the system SHALL release all file handles and locks
3. WHEN a user signs out THEN the system SHALL clear any cached database references
4. WHEN a user signs out THEN the system SHALL NOT delete the user's database file from disk
5. WHEN a user signs out THEN the system SHALL transition to using the guest database

### Requirement 4

**User Story:** As an existing user, I want my documents from the old shared database to be automatically migrated to my user-specific database, so that I don't lose any data.

#### Acceptance Criteria

1. WHEN a user signs in and a legacy shared database exists THEN the system SHALL detect the legacy database
2. WHEN the legacy database is detected THEN the system SHALL migrate all documents to the user's new database
3. WHEN migration completes successfully THEN the system SHALL mark the legacy database as migrated
4. WHEN migration fails THEN the system SHALL log the error and allow retry on next sign-in
5. WHEN all users have been migrated THEN the system SHALL provide a mechanism to delete the legacy database

### Requirement 5

**User Story:** As a user, I want my file attachments to be stored in a user-specific directory, so that other users cannot access my files.

#### Acceptance Criteria

1. WHEN a file attachment is saved THEN the system SHALL store it in a directory named with the user's Cognito User ID
2. WHEN the file directory is created THEN the system SHALL use the format "files/{userId}/" where userId is the Cognito sub claim
3. WHEN a user signs out THEN the system SHALL NOT delete the user's file directory
4. WHEN a user signs in THEN the system SHALL access only their user-specific file directory
5. WHEN file paths are stored in the database THEN the system SHALL store relative paths without the userId prefix

### Requirement 6

**User Story:** As a developer, I want the system to handle guest/offline mode gracefully, so that users can use the app without authentication.

#### Acceptance Criteria

1. WHEN no user is authenticated THEN the system SHALL use a guest database named "household_docs_guest.db"
2. WHEN a guest user creates documents THEN the system SHALL store them in the guest database
3. WHEN a guest user signs in THEN the system SHALL offer to migrate guest data to their user account
4. WHEN guest data migration is accepted THEN the system SHALL copy all guest documents to the user's database
5. WHEN guest data migration completes THEN the system SHALL clear the guest database

### Requirement 7

**User Story:** As a developer, I want comprehensive error handling for database operations, so that the system remains stable when database issues occur.

#### Acceptance Criteria

1. WHEN a database operation fails THEN the system SHALL throw a descriptive DatabaseException
2. WHEN a user's database file is corrupted THEN the system SHALL log the error and create a new database
3. WHEN database initialization fails THEN the system SHALL retry with exponential backoff up to 3 times
4. WHEN a database cannot be opened THEN the system SHALL fall back to the guest database
5. WHEN a database error occurs THEN the system SHALL log the error with full context including user ID and operation type

### Requirement 8

**User Story:** As a developer, I want all database access to be properly synchronized, so that concurrent operations don't cause data corruption.

#### Acceptance Criteria

1. WHEN multiple operations access the database simultaneously THEN the system SHALL serialize access using a mutex lock
2. WHEN a database switch is in progress THEN the system SHALL queue new operations until the switch completes
3. WHEN a database operation is in progress THEN the system SHALL prevent database switching until the operation completes
4. WHEN the app is backgrounded during a database operation THEN the system SHALL complete the operation before closing the database
5. WHEN the app is terminated THEN the system SHALL gracefully close all open database connections

### Requirement 9

**User Story:** As a system administrator, I want the system to log all database lifecycle events, so that I can monitor and debug database issues.

#### Acceptance Criteria

1. WHEN a database is opened THEN the system SHALL log the event with user ID and database file name
2. WHEN a database is closed THEN the system SHALL log the event with user ID and duration it was open
3. WHEN a database switch occurs THEN the system SHALL log both the old and new user IDs
4. WHEN a migration occurs THEN the system SHALL log the migration start, progress, and completion
5. WHEN a database error occurs THEN the system SHALL log the error with full stack trace and context

### Requirement 10

**User Story:** As a user, I want the system to handle rapid sign-in/sign-out cycles gracefully, so that the app remains responsive and stable.

#### Acceptance Criteria

1. WHEN a user signs out and immediately signs in THEN the system SHALL handle the rapid transition without errors
2. WHEN multiple sign-in attempts occur in quick succession THEN the system SHALL debounce and use the latest authentication state
3. WHEN a database operation is in progress during sign-out THEN the system SHALL wait for the operation to complete before closing the database
4. WHEN a sign-in occurs while a previous database is closing THEN the system SHALL wait for the close to complete before opening the new database
5. WHEN rapid authentication changes occur THEN the system SHALL maintain data integrity without corruption or loss

### Requirement 11

**User Story:** As a developer, I want the database service to provide methods for database maintenance, so that I can manage database files and optimize storage.

#### Acceptance Criteria

1. WHEN a maintenance method is called THEN the system SHALL provide a method to list all user database files
2. WHEN a user account is deleted THEN the system SHALL provide a method to delete that user's database file
3. WHEN database optimization is requested THEN the system SHALL provide a method to vacuum the current user's database
4. WHEN storage cleanup is needed THEN the system SHALL provide a method to delete orphaned database files
5. WHEN database statistics are requested THEN the system SHALL provide methods to get database size and record counts

### Requirement 12

**User Story:** As a developer, I want the system to validate user IDs before creating database files, so that invalid user IDs don't create corrupted file names.

#### Acceptance Criteria

1. WHEN a user ID is received THEN the system SHALL validate it matches the expected Cognito sub format
2. WHEN a user ID contains invalid characters THEN the system SHALL sanitize the ID for use in file names
3. WHEN a user ID is empty or null THEN the system SHALL throw a DatabaseException
4. WHEN a user ID is too long THEN the system SHALL hash it to create a valid file name
5. WHEN a user ID validation fails THEN the system SHALL log the error and fall back to guest database
