#!/usr/bin/env python3
"""
Fix final issues in cloud_sync_service.dart
"""

import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix malformed trackSyncEvent calls
    # Pattern: trackSyncEvent(type: ..., success: ..., latencyMs: ..., errorMessage: ..., documentId: ...(, id: uuid.v4(), ...
    pattern1 = r'trackSyncEvent\(type: ([^,]+), success: ([^,]+), latencyMs: ([^,]+), errorMessage: ([^,]+), documentId: ([^,]+)\(, id: uuid\.v4\(\), eventType: "sync_event", entityType: "document", entityId: "unknown", message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement1 = r'trackSyncEvent(\n          type: \1,\n          success: \2,\n          latencyMs: \3,\n          errorMessage: \4,\n          documentId: \5,'
    content = re.sub(pattern1, replacement1, content)
    
    # Fix malformed trackSyncEvent calls with different parameter order
    pattern2 = r'trackSyncEvent\(type: ([^,]+), success: ([^,]+), latencyMs: ([^,]+), documentId: ([^,]+)\(, id: uuid\.v4\(\), eventType: "sync_event", entityType: "document", entityId: "unknown", message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement2 = r'trackSyncEvent(\n          type: \1,\n          success: \2,\n          latencyMs: \3,\n          documentId: \4,'
    content = re.sub(pattern2, replacement2, content)
    
    # Fix toString calls without parentheses
    content = re.sub(r'\.toString\(,', '.toString(),', content)
    content = re.sub(r'document\.syncId\.toString,', 'document.syncId,', content)
    content = re.sub(r'remoteDoc\.syncId\.toString,', 'remoteDoc.syncId,', content)
    content = re.sub(r'documentId\.toString,', 'documentId,', content)
    
    # Fix remaining malformed SyncEvent calls
    # Look for patterns like: _emitEvent(SyncEvent(eventType: ..., entityType: ..., entityId: ...(, id: uuid.v4(), ...
    pattern3 = r'_emitEvent\(SyncEvent\(eventType: ([^,]+), entityType: ([^,]+), entityId: ([^,]+)\(, id: uuid\.v4\(\), message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement3 = r'_emitEvent(SyncEvent(\n        id: _uuid.v4(),\n        eventType: \1,\n        entityType: \2,\n        entityId: \3,'
    content = re.sub(pattern3, replacement3, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed {filepath}")

if __name__ == '__main__':
    fix_file('household_docs_app/lib/services/cloud_sync_service.dart')