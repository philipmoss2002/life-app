import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import 'cloud_sync_service.dart';

/// Temporary service to test sync without subscription requirements
/// This bypasses subscription checks to isolate sync issues
class SyncTestService {
  static final SyncTestService _instance = SyncTestService._internal();
  factory SyncTestService() => _instance;
  SyncTestService._internal();

  /// Test if basic Amplify API calls work
  Future<bool> testAmplifyAPI() async {
    try {
      safePrint('Testing Amplify API connectivity...');

      if (!Amplify.isConfigured) {
        safePrint('❌ Amplify not configured');
        return false;
      }

      // Try a simple GraphQL query to test API connectivity
      const String testQuery = '''
        query ListDocuments {
          listDocuments {
            items {
              id
              title
            }
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: testQuery,
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        safePrint('❌ GraphQL errors: ${response.errors}');
        return false;
      }

      safePrint('✅ Amplify API test successful');
      safePrint('Response: ${response.data}');
      return true;
    } catch (e) {
      safePrint('❌ Amplify API test failed: $e');
      return false;
    }
  }

  /// Test document upload without subscription check
  Future<bool> testDocumentUpload(Document document) async {
    try {
      safePrint('Testing document upload: ${document.title}');

      if (!Amplify.isConfigured) {
        safePrint('❌ Amplify not configured');
        return false;
      }

      // Create GraphQL mutation for document upload
      const String createDocumentMutation = '''
        mutation CreateDocument(\$input: CreateDocumentInput!) {
          createDocument(input: \$input) {
            id
            title
            category
            userId
            createdAt
            lastModified
            version
            syncState
          }
        }
      ''';

      final variables = {
        'input': {
          'id': document.syncId,
          'userId': document.userId,
          'title': document.title,
          'category': document.category,
          'filePaths': document.filePaths,
          'createdAt': document.createdAt.toString(),
          'lastModified': document.lastModified.toString(),
          'version': document.version,
          'syncState': document.syncState,
          if (document.renewalDate != null)
            'renewalDate': document.renewalDate.toString(),
          if (document.notes != null) 'notes': document.notes,
        }
      };

      final request = GraphQLRequest<String>(
        document: createDocumentMutation,
        variables: variables,
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        safePrint('❌ Document upload errors: ${response.errors}');
        return false;
      }

      safePrint('✅ Document upload successful');
      safePrint('Response: ${response.data}');
      return true;
    } catch (e) {
      safePrint('❌ Document upload test failed: $e');
      return false;
    }
  }

  /// Test document query without subscription check
  Future<bool> testDocumentQuery(String userId) async {
    try {
      safePrint('Testing document query for user: $userId');

      if (!Amplify.isConfigured) {
        safePrint('❌ Amplify not configured');
        return false;
      }

      const String listDocumentsQuery = '''
        query ListDocuments(\$filter: ModelDocumentFilterInput) {
          listDocuments(filter: \$filter) {
            items {
              id
              title
              category
              userId
              createdAt
              lastModified
              version
              syncState
            }
          }
        }
      ''';

      final variables = {
        'filter': {
          'userId': {'eq': userId}
        }
      };

      final request = GraphQLRequest<String>(
        document: listDocumentsQuery,
        variables: variables,
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        safePrint('❌ Document query errors: ${response.errors}');
        return false;
      }

      safePrint('✅ Document query successful');
      safePrint('Response: ${response.data}');
      return true;
    } catch (e) {
      safePrint('❌ Document query test failed: $e');
      return false;
    }
  }

  /// Force initialize cloud sync without subscription check
  Future<bool> forceInitializeSync() async {
    try {
      safePrint('Force initializing sync without subscription check...');

      // Enable subscription bypass
      CloudSyncService.enableSubscriptionBypass();

      final syncService = CloudSyncService();

      // This will bypass the subscription check temporarily
      await syncService.initialize();
      await syncService.startSync();

      safePrint('✅ Sync force initialized');
      return true;
    } catch (e) {
      safePrint('❌ Force sync initialization failed: $e');
      return false;
    } finally {
      // Always disable bypass after test
      CloudSyncService.disableSubscriptionBypass();
    }
  }
}
