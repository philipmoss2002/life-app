#!/usr/bin/env python3
"""
Quick patch script to fix duplicate sync ID issues in the Flutter app.
This script adds error handling to catch and resolve duplicate sync ID errors.
"""

import os
import re

def patch_document_sync_manager():
    """Add duplicate sync ID handling to the document sync manager."""
    
    file_path = "lib/services/document_sync_manager.dart"
    
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return False
    
    print(f"📝 Patching {file_path}...")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add import for UUID if not present
    if 'package:uuid/uuid.dart' not in content:
        import_pattern = r"(import 'package:amplify_flutter/amplify_flutter.dart';)"
        import_replacement = r"\1\nimport 'package:uuid/uuid.dart';"
        content = re.sub(import_pattern, import_replacement, content)
        print("✅ Added UUID import")
    
    # Find the error handling section in uploadDocument
    error_pattern = r"(if \(response\.hasErrors\) \{[^}]+throw Exception\([^)]+\);[\s]*\})"
    
    if re.search(error_pattern, content, re.DOTALL):
        # Replace the error handling with enhanced version
        enhanced_error_handling = '''if (response.hasErrors) {
              // Check if error is due to duplicate sync identifier
              final errorMessages = response.errors.map((e) => e.message).join(', ');
              if (errorMessages.toLowerCase().contains('duplicate') && 
                  errorMessages.toLowerCase().contains('sync')) {
                _logWarning('Duplicate sync identifier error from server. Generating new sync ID.');
                
                // Generate a completely new sync identifier and retry once
                final newSyncId = const Uuid().v4();
                final retryDocument = documentToUpload.copyWith(syncId: newSyncId);
                
                _logInfo('Retrying upload with new sync ID: $newSyncId');
                
                // Create retry request
                final retryRequest = GraphQLRequest<Document>(
                  document: graphQLDocument,
                  variables: {
                    'input': {
                      'syncId': retryDocument.syncId,
                      'userId': retryDocument.userId,
                      'title': retryDocument.title,
                      'category': retryDocument.category,
                      'filePaths': retryDocument.filePaths,
                      'renewalDate': retryDocument.renewalDate?.format(),
                      'notes': retryDocument.notes,
                      'createdAt': retryDocument.createdAt.format(),
                      'lastModified': retryDocument.lastModified.format(),
                      'version': retryDocument.version,
                      'syncState': retryDocument.syncState,
                      'conflictId': retryDocument.conflictId,
                      'deleted': retryDocument.deleted,
                      'deletedAt': retryDocument.deletedAt?.format(),
                      'contentHash': retryDocument.contentHash,
                    }
                  },
                  decodePath: 'createDocument',
                  modelType: Document.classType,
                );
                
                final retryResponse = await Amplify.API.mutate(request: retryRequest).response;
                
                if (retryResponse.hasErrors) {
                  _logError('Retry failed: ${retryResponse.errors.map((e) => e.message).join(', ')}');
                  throw Exception('Upload failed after retry: ${retryResponse.errors.map((e) => e.message).join(', ')}');
                }
                
                if (retryResponse.data == null) {
                  throw Exception('Retry failed: No data returned from server');
                }
                
                _logInfo('Document uploaded successfully with new sync ID: ${retryDocument.syncId}');
                return retryResponse.data!;
              }
              
              _logError('GraphQL errors: $errorMessages');
              throw Exception('Upload failed: $errorMessages');
            }'''
        
        content = re.sub(error_pattern, enhanced_error_handling, content, flags=re.DOTALL)
        print("✅ Enhanced error handling for duplicate sync IDs")
    else:
        print("⚠️  Could not find error handling pattern to patch")
        return False
    
    # Write the patched content back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Successfully patched {file_path}")
    return True

def patch_sync_state_manager():
    """Add duplicate sync ID handling to the sync state manager."""
    
    file_path = "lib/services/sync_state_manager.dart"
    
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return False
    
    print(f"📝 Patching {file_path}...")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add error recovery in the catch block
    catch_pattern = r"(catch \(e[^}]+\) \{[^}]+rethrow;[\s]*\})"
    
    if re.search(catch_pattern, content, re.DOTALL):
        enhanced_catch = '''catch (e) {
      _logService.log('Failed to update sync state for syncId: $syncId: $e',
          level: LogLevel.error);
      
      // If the error is related to duplicate sync identifiers, try recovery
      if (e.toString().toLowerCase().contains('duplicate') && 
          e.toString().toLowerCase().contains('sync')) {
        _logService.log('Attempting recovery from duplicate sync ID error', level: LogLevel.warning);
        
        try {
          final document = await _findDocumentBySyncId(syncId);
          if (document != null) {
            // Generate new sync ID and retry
            final newSyncId = const Uuid().v4();
            final updatedDocument = document.copyWith(syncId: newSyncId);
            await _databaseService.updateDocument(updatedDocument);
            
            // Retry with new sync ID
            await updateSyncState(newSyncId, newState, metadata: metadata);
            return;
          }
        } catch (recoveryError) {
          _logService.log('Recovery attempt failed: $recoveryError', level: LogLevel.error);
        }
      }
      
      rethrow;
    }'''
        
        content = re.sub(catch_pattern, enhanced_catch, content, flags=re.DOTALL)
        print("✅ Enhanced error recovery for duplicate sync IDs")
    else:
        print("⚠️  Could not find catch block pattern to patch")
        return False
    
    # Write the patched content back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Successfully patched {file_path}")
    return True

def main():
    """Main function to apply all patches."""
    print("🚀 Starting duplicate sync ID patch...")
    
    # Change to the app directory
    if os.path.exists("household_docs_app"):
        os.chdir("household_docs_app")
    
    success_count = 0
    
    # Apply patches
    if patch_document_sync_manager():
        success_count += 1
    
    if patch_sync_state_manager():
        success_count += 1
    
    print(f"\n📊 Patch Summary:")
    print(f"✅ Successfully patched: {success_count}/2 files")
    
    if success_count == 2:
        print("🎉 All patches applied successfully!")
        print("\n📋 Next steps:")
        print("1. Run 'flutter clean' to clear build cache")
        print("2. Run 'flutter pub get' to refresh dependencies")
        print("3. Test the sync functionality")
    else:
        print("⚠️  Some patches failed. Please check the output above.")

if __name__ == "__main__":
    main()