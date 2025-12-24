#!/usr/bin/env python3
"""
Final fix script for remaining compilation errors.
This script addresses the correct method names and remaining issues.
"""

import os
import re
import glob
from pathlib import Path

def fix_sync_identifier_method_calls(file_path):
    """Fix SyncIdentifierService method calls to use correct methods."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Replace SyncIdentifierGenerator.generate() with SyncIdentifierService.generateValidated()
    content = re.sub(
        r'SyncIdentifierGenerator\.generate\(\)',
        'SyncIdentifierService.generateValidated()',
        content
    )
    
    # Add import for SyncIdentifierService if needed and remove SyncIdentifierGenerator import
    if 'SyncIdentifierService.generateValidated()' in content:
        # Remove SyncIdentifierGenerator import if it exists
        content = re.sub(
            r"import\s+['\"]\.\.\/\.\.\/lib\/utils\/sync_identifier_generator\.dart['\"];\s*\n",
            "",
            content
        )
        
        # Add SyncIdentifierService import if not present
        if 'sync_identifier_service.dart' not in content:
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
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed SyncIdentifierService method calls in {file_path}")

def fix_document_constructor_issues(file_path):
    """Fix remaining Document constructor issues."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix cases where Document() is called without required parameters
    # Pattern: Document() with no parameters
    content = re.sub(
        r'\bDocument\(\s*\)',
        '''Document(
      syncId: SyncIdentifierService.generateValidated(),
      userId: "test-user",
      title: "Test Document", 
      category: "Test",
      filePaths: ["test.pdf"],
      createdAt: amplify_core.TemporalDateTime.now(),
      lastModified: amplify_core.TemporalDateTime.now(),
      version: 1,
      syncState: "pending"
    )''',
        content
    )
    
    # Fix SyncEvent constructor issues - SyncEvent uses 'id' not 'syncId'
    # Remove any syncId parameters from SyncEvent constructors
    content = re.sub(
        r'SyncEvent\([^)]*syncId:[^,)]*,?([^)]*)\)',
        r'SyncEvent(\1)',
        content
    )
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed Document constructor issues in {file_path}")

def fix_validation_result_constructor(file_path):
    """Fix ValidationResult constructor calls."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix ValidationResult constructor calls that are missing isValid parameter
    # Pattern: ValidationResult( without isValid
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
        print(f"Fixed ValidationResult constructor in {file_path}")

def fix_mock_file_issues(file_path):
    """Fix issues in mock files."""
    if '.mocks.dart' not in file_path:
        return
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix parameter syntax issues in mock files
    # Replace old-style parameter syntax with proper named parameters
    content = re.sub(
        r'(\w+)\s*:\s*SyncIdentifierService\s*=\s*([^,)]*)',
        r'{\1 = \2}',
        content
    )
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed mock file issues in {file_path}")

def main():
    """Main function to fix final compilation errors."""
    print("Starting final fix for remaining compilation errors...")
    
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
            fix_sync_identifier_method_calls(file_path)
            fix_document_constructor_issues(file_path)
            fix_validation_result_constructor(file_path)
            fix_mock_file_issues(file_path)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            continue
    
    print("\nFinal fix script completed!")
    print("Run 'flutter analyze' to check remaining issues.")

if __name__ == "__main__":
    main()