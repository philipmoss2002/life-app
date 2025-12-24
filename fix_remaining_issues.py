#!/usr/bin/env python3
"""
Fix remaining issues in cloud_sync_service.dart
"""

import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix toString() calls on syncId
    content = re.sub(r'document\.syncId\.toString\(\)', 'document.syncId', content)
    content = re.sub(r'remoteDoc\.syncId\.toString\(\)', 'remoteDoc.syncId', content)
    content = re.sub(r'documentId\.toString\(\)', 'documentId', content)
    
    # Fix e.toString calls (missing parentheses)
    content = re.sub(r'errorMessage: e\.toString,', 'errorMessage: e.toString(),', content)
    
    # Fix malformed SyncEvent constructor calls that still have the old format
    # Pattern: _emitEvent(SyncEvent(eventType: ..., entityType: ..., entityId: ...(, id: uuid.v4(), ...
    pattern1 = r'_emitEvent\(SyncEvent\(eventType: ([^,]+), entityType: ([^,]+), entityId: ([^,]+)\(, id: uuid\.v4\(\), message: "Sync event", timestamp: TemporalDateTime\.now\(\)\),'
    replacement1 = r'_emitEvent(SyncEvent(\n        id: _uuid.v4(),\n        eventType: \1,\n        entityType: \2,\n        entityId: \3,'
    content = re.sub(pattern1, replacement1, content)
    
    # Fix SyncOperation constructor missing id parameter
    pattern2 = r'SyncOperation\(\s*documentId:'
    replacement2 = r'SyncOperation(\n      id: _uuid.v4(),\n      documentId:'
    content = re.sub(pattern2, replacement2, content)
    
    # Fix copyWith calls that are missing id parameter
    pattern3 = r'return SyncOperation\(\s*documentId:'
    replacement3 = r'return SyncOperation(\n      id: id ?? this.id,\n      documentId:'
    content = re.sub(pattern3, replacement3, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed {filepath}")

if __name__ == '__main__':
    fix_file('household_docs_app/lib/services/cloud_sync_service.dart')