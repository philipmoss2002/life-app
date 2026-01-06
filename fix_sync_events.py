#!/usr/bin/env python3
"""
Fix SyncEvent constructor calls and analytics trackSyncEvent calls in cloud_sync_service.dart
"""

import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix SyncEvent constructor calls with malformed parameters
    # Pattern: SyncEvent(eventType: ..., entityType: ..., entityId: ...(, id: uuid.v4(), ...)
    pattern1 = r'SyncEvent\(eventType: ([^,]+), entityType: ([^,]+), entityId: ([^,]+)\(, id: uuid\.v4\(\), message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement1 = r'SyncEvent(\n        id: _uuid.v4(),\n        eventType: \1,\n        entityType: \2,\n        entityId: \3,'
    content = re.sub(pattern1, replacement1, content)
    
    # Fix trackSyncEvent calls with malformed parameters
    # Pattern: trackSyncEvent(type: ..., success: ..., latencyMs: ..., documentId: ...(, id: uuid.v4(), ...)
    pattern2 = r'trackSyncEvent\(type: ([^,]+), success: ([^,]+), latencyMs: ([^,]+), documentId: ([^,]+)\(, id: uuid\.v4\(\), eventType: "sync_event", entityType: "document", entityId: "unknown", message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement2 = r'trackSyncEvent(\n          type: \1,\n          success: \2,\n          latencyMs: \3,\n          documentId: \4,'
    content = re.sub(pattern2, replacement2, content)
    
    # Fix trackSyncEvent calls with error messages
    pattern3 = r'trackSyncEvent\(type: ([^,]+), success: ([^,]+), latencyMs: ([^,]+), errorMessage: ([^,]+)\(, id: uuid\.v4\(\), eventType: "sync_event", entityType: "document", entityId: "unknown", message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement3 = r'trackSyncEvent(\n          type: \1,\n          success: \2,\n          latencyMs: \3,\n          errorMessage: \4,'
    content = re.sub(pattern3, replacement3, content)
    
    # Fix _createSyncEvent method signature
    pattern4 = r'SyncEvent _createSyncEvent\(SyncEventType type, \{String\? entityId, String\? syncId, String\? message, Map<String, dynamic>\? metadata\}, id: uuid\.v4\(\), eventType: "sync_event", entityType: "document", entityId: "unknown", message: "Sync event", timestamp: TemporalDateTime\.now\(\)\) \{'
    replacement4 = r'SyncEvent _createSyncEvent(SyncEventType type, {String? entityId, String? syncId, String? message, Map<String, dynamic>? metadata}) {'
    content = re.sub(pattern4, replacement4, content)
    
    # Fix _createSyncEvent return statement
    pattern5 = r'return SyncEvent\(eventType: type\.value, entityType: \'sync\', entityId: entityId \?\? \'global\', syncId: syncId, message: message \?\? \'\', timestamp: amplify_core\.TemporalDateTime\.now\(\(, id: uuid\.v4\(\)\),'
    replacement5 = r'return SyncEvent(\n      id: _uuid.v4(),\n      eventType: type.value,\n      entityType: \'sync\',\n      entityId: entityId ?? \'global\',\n      syncId: syncId,\n      message: message ?? \'\',\n      timestamp: amplify_core.TemporalDateTime.now(),'
    content = re.sub(pattern5, replacement5, content)
    
    # Fix remaining SyncEvent calls with malformed parameters (batch sync)
    pattern6 = r'SyncEvent\(eventType: SyncEventType\.syncCompleted\.value, entityType: \'sync\', entityId: \'batch\', message: \'Batch synced \$\{documents\.length\} documents\', timestamp: amplify_core\.TemporalDateTime\.now\(\(, id: uuid\.v4\(\)\),'
    replacement6 = r'SyncEvent(\n        id: _uuid.v4(),\n        eventType: SyncEventType.syncCompleted.value,\n        entityType: \'sync\',\n        entityId: \'batch\',\n        message: \'Batch synced ${documents.length} documents\',\n        timestamp: amplify_core.TemporalDateTime.now(),'
    content = re.sub(pattern6, replacement6, content)
    
    # Fix SyncEvent calls with document entity
    pattern7 = r'_emitEvent\(SyncEvent\(eventType: SyncEventType\.documentUploaded\.value, entityType: \'document\', entityId: document\.syncId\.toString\(\(, id: uuid\.v4\(\), message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement7 = r'_emitEvent(SyncEvent(\n        id: _uuid.v4(),\n        eventType: SyncEventType.documentUploaded.value,\n        entityType: \'document\',\n        entityId: document.syncId,'
    content = re.sub(pattern7, replacement7, content)
    
    # Fix SyncEvent calls with remoteDoc entity
    pattern8 = r'_emitEvent\(SyncEvent\(eventType: SyncEventType\.documentDownloaded\.value, entityType: \'document\', entityId: remoteDoc\.syncId\.toString\(\(, id: uuid\.v4\(\), message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement8 = r'_emitEvent(SyncEvent(\n        id: _uuid.v4(),\n        eventType: SyncEventType.documentDownloaded.value,\n        entityType: \'document\',\n        entityId: remoteDoc.syncId,'
    content = re.sub(pattern8, replacement8, content)
    
    # Fix SyncEvent calls with conflict detected
    pattern9 = r'_emitEvent\(SyncEvent\(eventType: SyncEventType\.conflictDetected\.value, entityType: \'document\', entityId: document\.syncId\.toString\(\(, id: uuid\.v4\(\), message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement9 = r'_emitEvent(SyncEvent(\n        id: _uuid.v4(),\n        eventType: SyncEventType.conflictDetected.value,\n        entityType: \'document\',\n        entityId: document.syncId,'
    content = re.sub(pattern9, replacement9, content)
    
    # Fix SyncEvent calls with state changed
    pattern10 = r'_emitEvent\(SyncEvent\(eventType: SyncEventType\.stateChanged\.value, entityType: \'document\', entityId: documentId\.toString\(\(, id: uuid\.v4\(\), message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement10 = r'_emitEvent(SyncEvent(\n        id: _uuid.v4(),\n        eventType: SyncEventType.stateChanged.value,\n        entityType: \'document\',\n        entityId: documentId,'
    content = re.sub(pattern10, replacement10, content)
    
    # Fix SyncEvent calls with sync failed
    pattern11 = r'_emitEvent\(SyncEvent\(eventType: SyncEventType\.syncFailed\.value, entityType: \'document\', entityId: operation\.syncId \?\? operation\.documentId, message: \'Max retries reached for sync operation\', timestamp: amplify_core\.TemporalDateTime\.now\(\(, id: uuid\.v4\(\)\),'
    replacement11 = r'_emitEvent(SyncEvent(\n          id: _uuid.v4(),\n          eventType: SyncEventType.syncFailed.value,\n          entityType: \'document\',\n          entityId: operation.syncId ?? operation.documentId,\n          message: \'Max retries reached for sync operation\',\n          timestamp: amplify_core.TemporalDateTime.now(),'
    content = re.sub(pattern11, replacement11, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed {filepath}")

if __name__ == '__main__':
    fix_file('household_docs_app/lib/services/cloud_sync_service.dart')
