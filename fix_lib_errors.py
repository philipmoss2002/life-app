#!/usr/bin/env python3
"""
Fix script for main application code (lib/) compilation errors.
This script addresses the critical issues in the main application.
"""

import os
import re
import glob
from pathlib import Path

def fix_sync_identifier_service_calls(file_path):
    """Fix SyncIdentifierService method calls in lib/ files."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Replace SyncIdentifierService.generate() with SyncIdentifierService.generateValidated()
    content = re.sub(
        r'SyncIdentifierService\.generate\(\)',
        'SyncIdentifierService.generateValidated()',
        content
    )
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed SyncIdentifierService calls in {file_path}")

def fix_document_id_references(file_path):
    """Fix document.id references to use document.syncId."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern: document.id -> document.syncId (but not SyncEvent.id or other models)
    patterns = [
        (r'(\w*[Dd]ocument)\.id\b', r'\1.syncId'),
        (r'document\.id\b', r'document.syncId'),
        (r'doc\.id\b', r'doc.syncId'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed document.id references in {file_path}")

def fix_sync_event_constructors(file_path):
    """Fix SyncEvent constructor calls to include required parameters."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix SyncEvent constructor calls that are missing required parameters
    # Pattern: SyncEvent( without required parameters
    sync_event_pattern = r'SyncEvent\s*\(\s*([^)]*)\)'
    
    def fix_sync_event_constructor(match):
        params = match.group(1)
        
        # Required parameters for SyncEvent
        required_params = {
            'id': 'uuid.v4()',
            'eventType': '"sync_event"',
            'entityType': '"document"',
            'entityId': '"unknown"',
            'message': '"Sync event"',
            'timestamp': 'TemporalDateTime.now()'
        }
        
        # Check which required params are missing
        existing_params = set()
        if params.strip():
            for param in params.split(','):
                if ':' in param:
                    param_name = param.split(':')[0].strip()
                    existing_params.add(param_name)
        
        # Add missing required parameters
        param_list = []
        if params.strip():
            param_list = [p.strip() for p in params.split(',') if p.strip()]
        
        for req_param, default_value in required_params.items():
            if req_param not in existing_params:
                param_list.append(f'{req_param}: {default_value}')
        
        return f'SyncEvent({", ".join(param_list)})'
    
    content = re.sub(sync_event_pattern, fix_sync_event_constructor, content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed SyncEvent constructors in {file_path}")

def fix_validation_result_constructors(file_path):
    """Fix ValidationResult constructor calls."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix ValidationResult constructor calls that are missing isValid parameter
    validation_pattern = r'ValidationResult\s*\(\s*([^)]*)\)'
    
    def fix_validation_constructor(match):
        params = match.group(1)
        if 'isValid:' not in params:
            # Add isValid: true as first parameter
            if params.strip():
                return f'ValidationResult(isValid: true, {params})'
            else:
                return 'ValidationResult(isValid: true)'
        return match.group(0)
    
    content = re.sub(validation_pattern, fix_validation_constructor, content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed ValidationResult constructors in {file_path}")

def fix_missing_imports(file_path):
    """Add missing imports for uuid and TemporalDateTime."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Add uuid import if SyncEvent is used but uuid is not imported
    if 'SyncEvent(' in content and 'uuid.v4()' in content and 'package:uuid/uuid.dart' not in content:
        # Find the import section
        import_pattern = r"(import\s+['\"][^'\"]*['\"];?\s*\n)*"
        match = re.search(import_pattern, content)
        
        if match:
            imports_end = match.end()
            import_line = "import 'package:uuid/uuid.dart';\n"
            content = content[:imports_end] + import_line + content[imports_end:]
    
    # Add TemporalDateTime import if used but not imported
    if 'TemporalDateTime' in content and 'amplify_core' not in content:
        # Find the import section
        import_pattern = r"(import\s+['\"][^'\"]*['\"];?\s*\n)*"
        match = re.search(import_pattern, content)
        
        if match:
            imports_end = match.end()
            import_line = "import 'package:amplify_core/amplify_core.dart' as amplify_core;\n"
            content = content[:imports_end] + import_line + content[imports_end:]
            
            # Replace TemporalDateTime with amplify_core.TemporalDateTime
            content = re.sub(r'\bTemporalDateTime\b', 'amplify_core.TemporalDateTime', content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed missing imports in {file_path}")

def main():
    """Main function to fix lib/ compilation errors."""
    print("Starting fix for main application code (lib/) compilation errors...")
    
    # Get all Dart files in lib directory
    lib_files = []
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                lib_files.append(os.path.join(root, file))
    
    print(f"Found {len(lib_files)} lib files to process")
    
    # Apply fixes to each file
    for file_path in lib_files:
        print(f"\nProcessing {file_path}...")
        
        try:
            fix_sync_identifier_service_calls(file_path)
            fix_document_id_references(file_path)
            fix_sync_event_constructors(file_path)
            fix_validation_result_constructors(file_path)
            fix_missing_imports(file_path)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            continue
    
    print("\nLib fix script completed!")
    print("Run 'flutter analyze lib/' to check remaining issues.")

if __name__ == "__main__":
    main()