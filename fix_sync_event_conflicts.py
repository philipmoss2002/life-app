#!/usr/bin/env python3
"""
Fix SyncEvent conflicts by updating all references to use LocalSyncEvent
"""

import os
import re

def fix_sync_event_references(file_path):
    """Fix SyncEvent references in a single file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Skip the generated SyncEvent model file
        if 'lib/models/SyncEvent.dart' in file_path:
            return False
            
        # Replace SyncEvent constructor calls with LocalSyncEvent
        content = re.sub(r'\bSyncEvent\(', 'LocalSyncEvent(', content)
        
        # Replace SyncEvent in type annotations and declarations
        # But preserve import statements
        lines = content.split('\n')
        new_lines = []
        
        for line in lines:
            if 'import' not in line and 'SyncEvent' in line:
                # Replace SyncEvent with LocalSyncEvent, but not in comments
                if not line.strip().startswith('//') and not line.strip().startswith('*'):
                    line = re.sub(r'\bSyncEvent\b', 'LocalSyncEvent', line)
            new_lines.append(line)
        
        content = '\n'.join(new_lines)
        
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Fixed SyncEvent references in {file_path}")
            return True
        else:
            print(f"ℹ️  No changes needed in {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    """Main function to fix all SyncEvent conflicts"""
    print("🔧 Fixing SyncEvent conflicts...")
    
    # Files that need to be updated
    files_to_fix = [
        'lib/services/cloud_sync_service.dart',
        'lib/services/realtime_sync_service.dart',
        'lib/services/sync_identifier_analytics_service.dart',
        'lib/services/sync_api_documentation.dart',
        'lib/services/analytics_service.dart',
        'lib/services/offline_sync_queue_service.dart',
        'lib/screens/sync_diagnostic_screen.dart',
        'lib/screens/error_trace_screen.dart',
    ]
    
    fixed_count = 0
    
    for file_path in files_to_fix:
        full_path = os.path.join('.', file_path)
        if os.path.exists(full_path):
            if fix_sync_event_references(full_path):
                fixed_count += 1
        else:
            print(f"⚠️  File not found: {full_path}")
    
    print(f"\n🎉 Fixed {fixed_count} files")
    print("✅ SyncEvent conflicts resolved!")

if __name__ == "__main__":
    main()