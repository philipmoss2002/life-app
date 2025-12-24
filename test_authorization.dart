import 'package:amplify_flutter/amplify_flutter.dart';
import 'lib/models/Document.dart';
import 'lib/services/authentication_service.dart';
import 'lib/services/sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

/// Simple test to verify GraphQL authorization is working
Future<void> testAuthorization() async {
  try {
    print('🔍 Testing GraphQL authorization...');

    // Get current user
    final authService = AuthenticationService();
    final currentUser = await authService.getCurrentUser();

    if (currentUser == null) {
      print('❌ No authenticated user found');
      return;
    }

    print('✅ Authenticated user: ${currentUser.id}');

    // Create a test document
    final testDocument = Document(
      syncId: SyncIdentifierService.generateValidated(),
      userId: currentUser.id,
      title: 'Authorization Test Document',
      category: 'Test',
      filePaths: [],
      createdAt: amplify_core.TemporalDateTime.now(),
      lastModified: amplify_core.TemporalDateTime.now(),
      version: 1,
      syncState: 'pending',
    );

    print('🔍 Creating document with userId: ${testDocument.userId}');

    // Try to create document via GraphQL
    const graphQLDocument = '''
      mutation CreateDocument(\$input: CreateDocumentInput!) {
        createDocument(input: \$input) {
          syncId
          userId
          title
          category
          createdAt
        }
      }
    ''';

    final request = GraphQLRequest<Document>(
      document: graphQLDocument,
      variables: {
        'input': {
          'syncId': testDocument.syncId,
          'userId': testDocument.userId,
          'title': testDocument.title,
          'category': testDocument.category,
          'filePaths': testDocument.filePaths,
          'createdAt': testDocument.createdAt.format(),
          'lastModified': testDocument.lastModified.format(),
          'version': testDocument.version,
          'syncState': testDocument.syncState,
        }
      },
      decodePath: 'createDocument',
      modelType: Document.classType,
    );

    final response = await Amplify.API.mutate(request: request).response;

    if (response.hasErrors) {
      print(
          '❌ GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
      return;
    }

    if (response.data == null) {
      print('❌ No data returned from GraphQL mutation');
      return;
    }

    print('✅ Document created successfully!');
    print('📄 Document syncId: ${response.data!.syncId}');
    print('👤 Document userId: ${response.data!.userId}');

    // Test listing documents
    print('🔍 Testing document listing...');

    const listQuery = '''
      query ListDocuments {
        listDocuments {
          items {
            syncId
            userId
            title
            category
          }
        }
      }
    ''';

    final listRequest = GraphQLRequest<PaginatedResult<Document>>(
      document: listQuery,
      decodePath: 'listDocuments',
      modelType: const PaginatedModelType(Document.classType),
    );

    final listResponse = await Amplify.API.query(request: listRequest).response;

    if (listResponse.hasErrors) {
      print(
          '❌ List query errors: ${listResponse.errors.map((e) => e.message).join(', ')}');
      return;
    }

    final documents = listResponse.data?.items ?? [];
    print('✅ Listed ${documents.length} documents');

    for (final doc in documents) {
      if (doc != null) {
        print('📄 Document: ${doc.title} (userId: ${doc.userId})');
      }
    }

    print('🎉 Authorization test completed successfully!');
  } catch (e) {
    print('❌ Authorization test failed: $e');
  }
}
