# DocumentDB Sync - Raw GraphQL Fix

## Root Cause

`ModelMutations` and `ModelQueries` **DO NOT EXIST** in Amplify Flutter v2.0.0 GraphQL API.

These helpers were part of:
- Amplify DataStore (which we're not using)
- Older versions of Amplify
- Different Amplify platforms (iOS/Android native)

## Solution: Use Raw GraphQL

We must write GraphQL queries and mutations manually.

## Implementation

### Create Mutation
```dart
Future<void> _createRemoteDocument(local.Document localDoc, String userId) async {
  try {
    final mutation = '''
      mutation CreateDocument(
        \$syncId: String!,
        \$userId: String!,
        \$title: String!,
        \$category: String!,
        \$renewalDate: AWSDateTime,
        \$notes: String,
        \$createdAt: AWSDateTime!,
        \$lastModified: AWSDateTime!,
        \$syncState: String!,
        \$deleted: Boolean,
        \$filePaths: [String!]!,
        \$version: Int!
      ) {
        createDocument(input: {
          syncId: \$syncId,
          userId: \$userId,
          title: \$title,
          category: \$category,
          renewalDate: \$renewalDate,
          notes: \$notes,
          createdAt: \$createdAt,
          lastModified: \$lastModified,
          syncState: \$syncState,
          deleted: \$deleted,
          filePaths: \$filePaths,
          version: \$version
        }) {
          syncId
          userId
          title
          category
          renewalDate
          notes
          createdAt
          lastModified
          syncState
          deleted
        }
      }
    ''';

    final request = GraphQLRequest<String>(
      document: mutation,
      variables: {
        'syncId': localDoc.syncId,
        'userId': userId,
        'title': localDoc.title,
        'category': _mapCategoryToRemote(localDoc.category),
        'renewalDate': localDoc.date?.toIso8601String(),
        'notes': localDoc.notes,
        'createdAt': localDoc.createdAt.toIso8601String(),
        'lastModified': localDoc.updatedAt.toIso8601String(),
        'syncState': localDoc.syncState.name,
        'deleted': false,
        'filePaths': [],
        'version': 1,
      },
    );

    final response = await Amplify.API.mutate(request: request).response;

    if (response.hasErrors) {
      throw DocumentSyncException(
        'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
      );
    }

    _logService.log('Created remote document: ${localDoc.syncId}', level: log_svc.LogLevel.info);
  } catch (e) {
    _logService.log('Failed to create remote document: $e', level: log_svc.LogLevel.error);
    rethrow;
  }
}
```

### Update Mutation
```dart
Future<void> _updateRemoteDocument(local.Document localDoc, String userId) async {
  try {
    final mutation = '''
      mutation UpdateDocument(
        \$syncId: String!,
        \$userId: String!,
        \$title: String!,
        \$category: String!,
        \$renewalDate: AWSDateTime,
        \$notes: String,
        \$createdAt: AWSDateTime!,
        \$lastModified: AWSDateTime!,
        \$syncState: String!,
        \$deleted: Boolean,
        \$filePaths: [String!]!,
        \$version: Int!
      ) {
        updateDocument(input: {
          syncId: \$syncId,
          userId: \$userId,
          title: \$title,
          category: \$category,
          renewalDate: \$renewalDate,
          notes: \$notes,
          createdAt: \$createdAt,
          lastModified: \$lastModified,
          syncState: \$syncState,
          deleted: \$deleted,
          filePaths: \$filePaths,
          version: \$version
        }) {
          syncId
          userId
          title
          category
          updatedAt
        }
      }
    ''';

    final request = GraphQLRequest<String>(
      document: mutation,
      variables: {
        'syncId': localDoc.syncId,
        'userId': userId,
        'title': localDoc.title,
        'category': _mapCategoryToRemote(localDoc.category),
        'renewalDate': localDoc.date?.toIso8601String(),
        'notes': localDoc.notes,
        'createdAt': localDoc.createdAt.toIso8601String(),
        'lastModified': localDoc.updatedAt.toIso8601String(),
        'syncState': localDoc.syncState.name,
        'deleted': false,
        'filePaths': [],
        'version': 1,
      },
    );

    final response = await Amplify.API.mutate(request: request).response;

    if (response.hasErrors) {
      throw DocumentSyncException(
        'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
      );
    }

    _logService.log('Updated remote document: ${localDoc.syncId}', level: log_svc.LogLevel.info);
  } catch (e) {
    _logService.log('Failed to update remote document: $e', level: log_svc.LogLevel.error);
    rethrow;
  }
}
```

### Get Query
```dart
Future<remote.Document?> _fetchRemoteDocument(String syncId) async {
  try {
    final query = '''
      query GetDocument(\$syncId: String!) {
        getDocument(syncId: \$syncId) {
          syncId
          userId
          title
          category
          renewalDate
          notes
          createdAt
          lastModified
          syncState
          deleted
          deletedAt
          filePaths
          version
        }
      }
    ''';

    final request = GraphQLRequest<String>(
      document: query,
      variables: {'syncId': syncId},
    );

    final response = await Amplify.API.query(request: request).response;

    if (response.hasErrors) {
      _logService.log(
        'GraphQL errors fetching document: ${response.errors.map((e) => e.message).join(", ")}',
        level: log_svc.LogLevel.warning,
      );
      return null;
    }

    if (response.data == null) {
      return null;
    }

    // Parse JSON response into Document model
    final jsonData = jsonDecode(response.data!);
    final docData = jsonData['getDocument'];
    
    if (docData == null) {
      return null;
    }

    return remote.Document.fromJson(docData);
  } catch (e) {
    _logService.log('Failed to fetch remote document $syncId: $e', level: log_svc.LogLevel.error);
    return null;
  }
}
```

### List Query
```dart
Future<List<remote.Document>> _fetchAllRemoteDocuments(String userId) async {
  try {
    final query = '''
      query ListDocuments(\$userId: String!) {
        listDocuments(filter: {userId: {eq: \$userId}}) {
          items {
            syncId
            userId
            title
            category
            renewalDate
            notes
            createdAt
            lastModified
            syncState
            deleted
            deletedAt
            filePaths
            version
          }
        }
      }
    ''';

    final request = GraphQLRequest<String>(
      document: query,
      variables: {'userId': userId},
    );

    final response = await Amplify.API.query(request: request).response;

    if (response.hasErrors) {
      throw DocumentSyncException(
        'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
      );
    }

    if (response.data == null) {
      return [];
    }

    // Parse JSON response
    final jsonData = jsonDecode(response.data!);
    final items = jsonData['listDocuments']['items'] as List;

    return items
        .map((item) => remote.Document.fromJson(item))
        .toList();
  } catch (e) {
    _logService.log('Failed to fetch all remote documents: $e', level: log_svc.LogLevel.error);
    rethrow;
  }
}
```

## Key Changes

1. **No ModelMutations/ModelQueries** - Use `GraphQLRequest<String>` directly
2. **Manual GraphQL strings** - Write mutations and queries as strings
3. **JSON parsing** - Parse response.data as JSON and convert to models
4. **DateTime format** - Use `.toIso8601String()` for AWSDateTime fields

## Why This Works

- GraphQLRequest is the base API in Amplify Flutter
- Works with any GraphQL schema
- No dependency on DataStore or model helpers
- Full control over queries and mutations

## Implementation Steps

1. Replace all `ModelMutations.create/update` with raw GraphQL mutations
2. Replace all `ModelQueries.get/list` with raw GraphQL queries
3. Add `import 'dart:convert';` for JSON parsing
4. Parse responses manually using `jsonDecode` and `Model.fromJson()`

This is the correct approach for Amplify Flutter v2.0.0 GraphQL API.
