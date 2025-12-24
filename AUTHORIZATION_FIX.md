# Authorization Fix for "Not authorised to access listDocuments" Error

## Problem
New users with no documents were getting the error: "Not authorised to access listDocuments on type Query" when the app tried to sync from remote.

## Root Cause
The GraphQL schema uses owner-based authorization (`@auth(rules: [{allow: owner}])`), which automatically filters queries to only return data owned by the authenticated user. However, the GraphQL queries were manually adding `userId` filters, which conflicts with the automatic owner-based filtering.

## Solution
Removed manual `userId` filtering from GraphQL queries and let Amplify's owner-based authorization handle the filtering automatically.

### Files Modified

#### 1. `lib/services/document_sync_manager.dart`
- **Method**: `fetchAllDocuments()`
- **Change**: Removed `userId` filter from `listDocuments` query
- **Before**: `listDocuments(filter: {userId: {eq: $userId}, deleted: {ne: true}})`
- **After**: `listDocuments(filter: {deleted: {ne: true}})`

#### 2. `lib/services/realtime_sync_service.dart`
- **Methods**: All subscription methods
- **Change**: Removed `userId` filters from subscription queries
- **Before**: `onCreateDocument(filter: {userId: {eq: $userId}})`
- **After**: `onCreateDocument` (no filter needed)

### How Owner Authorization Works
1. The `@auth(rules: [{allow: owner}])` rule in the GraphQL schema automatically:
   - Adds the authenticated user's ID as the owner field
   - Filters all queries to only return records owned by the authenticated user
   - Prevents access to other users' data

2. Manual `userId` filtering conflicts with this automatic behavior and causes authorization errors.

### Testing
- New users should now be able to sync without authorization errors
- Existing users should continue to see only their own documents
- User isolation is maintained through Amplify's built-in owner authorization

### Security
This fix maintains the same security level:
- Users can only access their own documents
- Cross-user data access is prevented by Amplify's authorization layer
- No manual user ID validation is needed as Amplify handles it automatically