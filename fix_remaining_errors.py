#!/usr/bin/env python3
"""
Comprehensive fix script for remaining Document model compilation errors.
This script addresses the remaining ~886 errors after the sync identifier refactor.
"""

import os
import re
import glob
from pathlib import Path

def fix_sync_identifier_imports(file_path):
    """Add missing SyncIdentifierService imports to test files."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if file references SyncIdentifierService but doesn't import it
    if 'SyncIdentifierService' in content and 'sync_identifier_service.dart' not in content:
        # Find the import section
        import_pattern = r"(import\s+['\"][^'\"]*['\"];?\s*\n)*"
        match = re.search(import_pattern, content)
        
        if match:
            imports_end = match.end()
            # Add the import after existing imports
            import_line = "import '../../lib/services/sync_identifier_service.dart';\n"
            
            # Check if it's a test file in different directory structure
            if '/test/' in file_path:
                # Adjust path based on test file location
                if file_path.count('/') >= 3:  # test/services/file.dart
                    import_line = "import '../../lib/services/sync_identifier_service.dart';\n"
                elif file_path.count('/') >= 2:  # test/file.dart
                    import_line = "import '../lib/services/sync_identifier_service.dart';\n"
            
            content = content[:imports_end] + import_line + content[imports_end:]
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Added SyncIdentifierService import to {file_path}")

def fix_document_constructor_calls(file_path):
    """Fix Document constructor calls to use syncId instead of id."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern 1: Document(id: -> Document(syncId: SyncIdentifierService.generate(),
    content = re.sub(
        r'Document\(\s*id:\s*([^,\)]+)',
        r'Document(syncId: SyncIdentifierService.generate()',
        content
    )
    
    # Pattern 2: Document constructor with missing syncId parameter
    # Find Document constructors and ensure they have syncId
    document_constructor_pattern = r'Document\s*\(\s*([^)]*)\s*\)'
    
    def fix_constructor(match):
        params = match.group(1)
        if 'syncId:' not in params and params.strip():
            # Add syncId as first parameter
            return f'Document(syncId: SyncIdentifierService.generate(), {params})'
        return match.group(0)
    
    content = re.sub(document_constructor_pattern, fix_constructor, content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed Document constructor calls in {file_path}")

def fix_document_id_references(file_path):
    """Fix document.id references to use document.syncId."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern: document.id -> document.syncId (but not SyncEvent.id or other models)
    # Be careful to only replace when it's clearly a Document instance
    patterns = [
        (r'(\w+Document)\.id\b', r'\1.syncId'),
        (r'document\.id\b', r'document.syncId'),
        (r'doc\.id\b', r'doc.syncId'),
        (r'savedDocument\.id\b', r'savedDocument.syncId'),
        (r'newDocument\.id\b', r'newDocument.syncId'),
        (r'updatedDocument\.id\b', r'updatedDocument.syncId'),
        (r'localDocument\.id\b', r'localDocument.syncId'),
        (r'remoteDocument\.id\b', r'remoteDocument.syncId'),
        (r'originalDocument\.id\b', r'originalDocument.syncId'),
        (r'testDocument\.id\b', r'testDocument.syncId'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed document.id references in {file_path}")

def fix_sync_event_constructor_issues(file_path):
    """Fix SyncEvent constructor and other syntax issues."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix unterminated string literals and syntax errors
    # This is a basic fix - more complex cases might need manual intervention
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        # Fix common syntax issues
        if 'syncId: SyncIdentifierService' in line and not line.strip().endswith(','):
            if not line.strip().endswith(');') and not line.strip().endswith(','):
                line = line.rstrip() + ','
        
        # Fix unterminated strings (basic cases)
        if line.count('"') % 2 == 1 and not line.strip().endswith('",') and not line.strip().endswith('";'):
            if '"' in line and not line.strip().endswith('"'):
                line = line.rstrip() + '"'
        
        fixed_lines.append(line)
    
    content = '\n'.join(fixed_lines)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed syntax issues in {file_path}")

def fix_duplicate_syncid_arguments(file_path):
    """Fix duplicate syncId arguments in Document constructors."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern to find Document constructors with duplicate syncId
    # This is a complex pattern, so we'll do a simple approach
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        # If line has multiple syncId parameters, remove duplicates
        if line.count('syncId:') > 1:
            # Keep only the first syncId parameter
            parts = line.split('syncId:')
            if len(parts) > 2:
                # Reconstruct with only first syncId
                fixed_line = parts[0] + 'syncId:' + parts[1]
                # Find the next comma or closing paren to end the parameter
                next_param_match = re.search(r'[,)]', parts[1])
                if next_param_match:
                    end_pos = next_param_match.start() + 1
                    fixed_line = parts[0] + 'syncId:' + parts[1][:end_pos]
                    # Add remaining parameters (skip other syncId occurrences)
                    remaining = parts[1][end_pos:]
                    for i in range(2, len(parts)):
                        # Skip the syncId part and add the rest
                        param_part = parts[i]
                        comma_pos = param_part.find(',')
                        paren_pos = param_part.find(')')
                        if comma_pos != -1:
                            remaining += param_part[comma_pos:]
                        elif paren_pos != -1:
                            remaining += param_part[paren_pos:]
                    fixed_line += remaining
                line = fixed_line
        
        fixed_lines.append(line)
    
    content = '\n'.join(fixed_lines)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed duplicate syncId arguments in {file_path}")

def fix_missing_required_arguments(file_path):
    """Fix missing required arguments in Document constructors."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern to find Document constructors and add missing required fields
    document_pattern = r'Document\s*\(\s*([^)]*)\s*\)'
    
    def fix_missing_args(match):
        params_str = match.group(1)
        params = [p.strip() for p in params_str.split(',') if p.strip()]
        
        # Required parameters for Document
        required_params = {
            'syncId': 'SyncIdentifierService.generate()',
            'userId': '"test-user"',
            'title': '"Test Document"',
            'category': '"Test"',
            'filePaths': '["test.pdf"]',
            'createdAt': 'TemporalDateTime.now()',
            'lastModified': 'TemporalDateTime.now()',
            'version': '1',
            'syncState': '"pending"'
        }
        
        # Check which required params are missing
        existing_params = set()
        for param in params:
            if ':' in param:
                param_name = param.split(':')[0].strip()
                existing_params.add(param_name)
        
        # Add missing required parameters
        for req_param, default_value in required_params.items():
            if req_param not in existing_params:
                params.append(f'{req_param}: {default_value}')
        
        return f'Document({", ".join(params)})'
    
    content = re.sub(document_pattern, fix_missing_args, content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed missing required arguments in {file_path}")

def main():
    """Main function to fix all compilation errors."""
    print("Starting comprehensive fix for remaining compilation errors...")
    
    # Get all Dart files in test directory
    test_files = []
    for root, dirs, files in os.walk('test'):
        for file in files:
            if file.endswith('.dart'):
                test_files.append(os.path.join(root, file))
    
    print(f"Found {len(test_files)} test files to process")
    
    # Apply fixes to each file
    for file_path in test_files:
        print(f"\nProcessing {file_path}...")
        
        try:
            # Skip mock files for now as they have complex generated code
            if '.mocks.dart' in file_path:
                print(f"Skipping mock file: {file_path}")
                continue
                
            fix_sync_identifier_imports(file_path)
            fix_document_constructor_calls(file_path)
            fix_document_id_references(file_path)
            fix_duplicate_syncid_arguments(file_path)
            fix_missing_required_arguments(file_path)
            fix_sync_event_constructor_issues(file_path)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            continue
    
    print("\nFix script completed!")
    print("Run 'flutter analyze' to check remaining issues.")

if __name__ == "__main__":
    main()