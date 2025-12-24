#!/usr/bin/env python3
"""
Targeted fix script for specific compilation errors.
This script fixes the most critical issues causing compilation failures.
"""

import os
import re
import glob
from pathlib import Path

def fix_sync_identifier_service_usage(file_path):
    """Fix SyncIdentifierService.generate() calls to use SyncIdentifierGenerator.generate()."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Replace SyncIdentifierService.generate() with SyncIdentifierGenerator.generate()
    content = re.sub(
        r'SyncIdentifierService\.generate\(\)',
        'SyncIdentifierGenerator.generate()',
        content
    )
    
    # Add import for SyncIdentifierGenerator if needed
    if 'SyncIdentifierGenerator.generate()' in content and 'sync_identifier_generator.dart' not in content:
        # Find the import section
        import_pattern = r"(import\s+['\"][^'\"]*['\"];?\s*\n)*"
        match = re.search(import_pattern, content)
        
        if match:
            imports_end = match.end()
            # Add the import after existing imports
            import_line = "import '../../lib/utils/sync_identifier_generator.dart';\n"
            
            # Check if it's a test file in different directory structure
            if '/test/' in file_path:
                # Adjust path based on test file location
                if file_path.count('/') >= 3:  # test/services/file.dart
                    import_line = "import '../../lib/utils/sync_identifier_generator.dart';\n"
                elif file_path.count('/') >= 2:  # test/file.dart
                    import_line = "import '../lib/utils/sync_identifier_generator.dart';\n"
            
            content = content[:imports_end] + import_line + content[imports_end:]
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed SyncIdentifierService usage in {file_path}")

def fix_temporal_datetime_import(file_path):
    """Add missing TemporalDateTime import."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Check if file uses TemporalDateTime but doesn't import amplify_core
    if 'TemporalDateTime' in content and 'amplify_core' not in content:
        # Find the import section
        import_pattern = r"(import\s+['\"][^'\"]*['\"];?\s*\n)*"
        match = re.search(import_pattern, content)
        
        if match:
            imports_end = match.end()
            # Add the import after existing imports
            import_line = "import 'package:amplify_core/amplify_core.dart' as amplify_core;\n"
            content = content[:imports_end] + import_line + content[imports_end:]
            
            # Replace TemporalDateTime with amplify_core.TemporalDateTime
            content = re.sub(r'\bTemporalDateTime\b', 'amplify_core.TemporalDateTime', content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed TemporalDateTime import in {file_path}")

def fix_broken_document_constructors(file_path):
    """Fix broken Document constructor calls that were mangled by the previous script."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix broken constructor patterns like "syncId: SyncIdentifierGenerator.generate(), userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending""
    # This pattern indicates a broken constructor call
    broken_pattern = r'syncId:\s*SyncIdentifierGenerator\.generate\(\),\s*userId:\s*"test-user",\s*title:\s*"Test Document",\s*category:\s*"Test",\s*filePaths:\s*\["test\.pdf"\],\s*createdAt:\s*amplify_core\.TemporalDateTime\.now\(\),\s*lastModified:\s*amplify_core\.TemporalDateTime\.now\(\),\s*version:\s*1,\s*syncState:\s*"pending"'
    
    # Replace with a proper minimal Document constructor
    content = re.sub(
        broken_pattern,
        'syncId: SyncIdentifierGenerator.generate(), userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"',
        content
    )
    
    # Fix syntax errors where there are missing identifiers after generate()
    content = re.sub(
        r'SyncIdentifierGenerator\.generate\(\)\s*,\s*userId:',
        'SyncIdentifierGenerator.generate(), userId:',
        content
    )
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed broken Document constructors in {file_path}")

def fix_syntax_errors(file_path):
    """Fix basic syntax errors introduced by the previous script."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix unterminated string literals (basic cases)
    lines = content.split('\n')
    fixed_lines = []
    
    for i, line in enumerate(lines):
        # Skip lines that are clearly comments
        if line.strip().startswith('//') or line.strip().startswith('/*'):
            fixed_lines.append(line)
            continue
            
        # Fix unterminated strings - if a line has an odd number of quotes and doesn't end properly
        if line.count('"') % 2 == 1:
            # Check if it's a legitimate unterminated string
            if not line.strip().endswith('",') and not line.strip().endswith('";') and not line.strip().endswith('"'):
                # Try to close the string
                if '"' in line and not line.rstrip().endswith('"'):
                    line = line.rstrip() + '"'
        
        # Fix missing semicolons in simple cases
        if line.strip() and not line.strip().endswith((';', '{', '}', ',', ')', '(')) and 'expect(' not in line and 'test(' not in line:
            # This is a heuristic - be careful
            pass
        
        fixed_lines.append(line)
    
    content = '\n'.join(fixed_lines)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed syntax errors in {file_path}")

def remove_broken_imports(file_path):
    """Remove broken import statements."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Remove the broken import that doesn't exist
    content = re.sub(
        r"import\s+['\"]\.\.\/\.\.\/lib\/services\/sync_identifier_service\.dart['\"];\s*\n",
        "",
        content
    )
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Removed broken imports in {file_path}")

def main():
    """Main function to fix specific compilation errors."""
    print("Starting targeted fix for specific compilation errors...")
    
    # Get all Dart files in test directory
    test_files = []
    for root, dirs, files in os.walk('test'):
        for file in files:
            if file.endswith('.dart') and not file.endswith('.mocks.dart'):
                test_files.append(os.path.join(root, file))
    
    print(f"Found {len(test_files)} test files to process")
    
    # Apply fixes to each file
    for file_path in test_files:
        print(f"\nProcessing {file_path}...")
        
        try:
            remove_broken_imports(file_path)
            fix_sync_identifier_service_usage(file_path)
            fix_temporal_datetime_import(file_path)
            fix_broken_document_constructors(file_path)
            fix_syntax_errors(file_path)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            continue
    
    print("\nTargeted fix script completed!")
    print("Run 'flutter analyze' to check remaining issues.")

if __name__ == "__main__":
    main()