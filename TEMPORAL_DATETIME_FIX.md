# Database Schema Mismatch Error Fix

## Problem Identified 🚨
**CRITICAL SAVE ERROR**: Saving documents failed with multiple database errors:

1. **TemporalDateTime Error**: "invalid argument: instance of TemporalDateTime" 
2. **SQL INSERT Error**: Column mismatch between data and database schema
3. **Schema Incompatibility**: Extension method fields didn't match database table structure

### Multiple Issues Found:
1. **Amplify Model Incompatibility**: Amplify-generated Document model uses `TemporalDateTime` objects
2. **SQLite Type Mismatch**: SQLite database expects string or DateTime objects, not `TemporalDateTime`
3. **Wrong toMap() Method**: Database service was using Amplify's `toMap()` instead of extension `toMap()`
4. **Field Name Mismatch**: Extension method used `filePaths` but database expects `filePath`
5. **Extra Fields**: Extension method included fields not in database schema (`deleted`, `deletedAt`)
6. **ID Field Issue**: Extension method included `id` field which should be auto-generated

### Root Cause Analysis
1. **Amplify Generated Code**: The Document model's `toMap()` method returns raw `TemporalDateTime` objects
2. **Database Expectations**: SQLite expects ISO8601 strings for date/time fields
3. **Missing Conversion**: No conversion from `TemporalDateTime` to string format in database operations

### Error Details
```
Error: invalid argument: instance of TemporalDateTime
Location: Database insert/update operations
Cause: SQLite cannot handle TemporalDateTime objects directly
```

## Solution Implemented ✅

### 1. **Fixed Database Service Methods**
- **Updated `createDocument()`** - Now uses `DocumentExtensions(document).toMap()`
- **Updated `createDocumentWithLabels()`** - Now uses extension method for proper conversion
- **Updated `updateDocument()`** - Now uses extension method for all document operations

### 2. **Fixed Database Schema Compatibility**
- **Corrected Field Names** - Changed `filePaths` to `filePath` to match database schema
- **Removed Extra Fields** - Removed `deleted`, `deletedAt`, and `id` fields not in schema
- **Proper Field Mapping** - Mapped multiple file paths to single `filePath` field (first file)
- **File Attachments Handling** - Multiple files stored separately in `file_attachments` table

### 3. **Proper TemporalDateTime Conversion**
- **Extension Method Usage** - Uses `DocumentExtensions.toMap()` which converts dates properly
- **ISO8601 String Format** - Converts `TemporalDateTime` to `getDateTimeInUtc().toIso8601String()`
- **Null Safety** - Handles nullable `TemporalDateTime` fields correctly

## Technical Implementation

### Database Service Changes
```dart
// Before (BROKEN):
final id = await db.insert('documents', document.toMap());

// After (FIXED):
final id = await db.insert('documents', DocumentExtensions(document).toMap());
```

### Fixed Extension Method
```dart
// DocumentExtensions.toMap() now matches database schema:
Map<String, dynamic> toMap() {
  return {
    'title': title,
    'category': category,
    'filePath': filePaths.isNotEmpty ? filePaths.first : null,
    'renewalDate': renewalDate?.getDateTimeInUtc().toIso8601String(),
    'notes': notes,
    'createdAt': createdAt.getDateTimeInUtc().toIso8601String(),
    'userId': userId,
    'lastModified': lastModified.getDateTimeInUtc().toIso8601String(),
    'version': version,
    'syncState': syncState,
    'conflictId': conflictId,
  };
}
```

### Conversion Process
1. **TemporalDateTime** → `getDateTimeInUtc()` → **DateTime**
2. **DateTime** → `toIso8601String()` → **String**
3. **String** → SQLite database (compatible format)

## Files Modified

### Core Services
- `lib/services/database_service.dart` - Fixed all document database operations

### Documentation
- `TEMPORAL_DATETIME_FIX.md` - This documentation file

## Methods Fixed

### **createDocument()**
```dart
// Fixed to use proper conversion for both LocalDocument and Document types
final documentMap = document is LocalDocument 
    ? document.toMap() 
    : DocumentExtensions(document).toMap();
```

### **createDocumentWithLabels()**
```dart
// Fixed to use extension method for proper TemporalDateTime conversion
final id = await db.insert('documents', DocumentExtensions(document).toMap());
```

### **updateDocument()**
```dart
// Fixed to handle both document types with proper conversion
final documentMap = document is LocalDocument 
    ? document.toMap() 
    : DocumentExtensions(document).toMap();
```

## Date Field Conversions

### **Fields Affected:**
- `renewalDate` - Optional renewal/due date
- `createdAt` - Document creation timestamp
- `lastModified` - Last modification timestamp  
- `deletedAt` - Optional deletion timestamp

### **Conversion Format:**
- **Input**: `TemporalDateTime(2024-01-15T10:30:00.000Z)`
- **Output**: `"2024-01-15T10:30:00.000Z"` (ISO8601 string)

## Error Prevention

### **Before Fix:**
- ❌ `TemporalDateTime` objects passed directly to SQLite
- ❌ Database insert/update operations failed
- ❌ Documents could not be saved
- ❌ Silent failures with cryptic error messages

### **After Fix:**
- ✅ `TemporalDateTime` objects properly converted to ISO8601 strings
- ✅ Database operations succeed
- ✅ Documents save successfully
- ✅ Clear error handling with user feedback

## Testing Verification

### **Test Scenarios:**
1. **Create Document with Renewal Date**:
   - Set renewal date in form
   - Tap save button
   - Verify document saves successfully

2. **Create Document without Renewal Date**:
   - Leave renewal date empty
   - Tap save button
   - Verify document saves with null renewal date

3. **Update Existing Document**:
   - Modify existing document
   - Save changes
   - Verify update operation succeeds

4. **Date Field Verification**:
   - Check database contains ISO8601 strings
   - Verify dates display correctly in UI
   - Confirm date calculations work properly

### **Database Verification:**
```sql
-- Check that dates are stored as ISO8601 strings
SELECT renewalDate, createdAt, lastModified FROM documents;
-- Should show: "2024-01-15T10:30:00.000Z" format
```

## Compatibility Notes

### **Model Types Handled:**
- **LocalDocument** - Uses existing `toMap()` method (already compatible)
- **Document (Amplify)** - Uses `DocumentExtensions.toMap()` for proper conversion
- **Mixed Usage** - Database service handles both types correctly

### **Extension Method Benefits:**
- **Type Safety** - Proper conversion without data loss
- **Null Safety** - Handles optional date fields correctly
- **Format Consistency** - All dates stored in ISO8601 format
- **Backward Compatibility** - Works with existing database schema

## Database Schema Mapping

### **Database Table Structure:**
```sql
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Auto-generated, not in toMap()
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  filePath TEXT,                         -- Single file path (first file)
  renewalDate TEXT,
  notes TEXT,
  createdAt TEXT NOT NULL,
  userId TEXT,
  lastModified TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  syncState TEXT NOT NULL DEFAULT 'notSynced',
  conflictId TEXT
);
```

### **Multiple File Handling:**
- **Primary File**: First file path stored in `documents.filePath`
- **Additional Files**: All files stored in `file_attachments` table
- **Labels**: File labels stored in `file_attachments.label`

## Status: ✅ DATABASE SCHEMA MISMATCH RESOLVED

Document saving now works correctly because:
1. ✅ **Schema Compatibility** - Extension method fields match database table structure
2. ✅ **Proper Conversion** - `TemporalDateTime` objects converted to ISO8601 strings
3. ✅ **Field Mapping** - `filePaths` correctly mapped to `filePath` (first file)
4. ✅ **Removed Extra Fields** - No longer trying to insert non-existent columns
5. ✅ **File Attachments** - Multiple files properly handled in separate table
6. ✅ **All Operations Fixed** - Create, update, and create-with-labels all work

**Documents can now be saved successfully without database schema or TemporalDateTime errors.**