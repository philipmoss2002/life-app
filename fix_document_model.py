#!/usr/bin/env python3
"""
Script to fix Document model references from id to syncId
"""

import os
import re
import glob

def fix_document_references(file_path):
    """Fix Document model references in a single file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Fix document.id references to document.syncId
        content = re.sub(r'document\.id\b', 'document.syncId', content)
        content = re.sub(r'doc\.id\b', 'doc.syncId', content)
        content = re.sub(r'testDoc\.id\b', 'testDoc.syncId', content)
        content = re.sub(r'localDoc\.id\b', 'localDoc.syncId', content)
        content = re.sub(r'remoteDoc\.id\b', 'remoteDoc.syncId', content)
        content = re.sub(r'savedDoc\.id\b', 'savedDoc.syncId', content)
        content = re.sub(r'updatedDoc\.id\b', 'updatedDoc.syncId', content)
        
        # Fix Document constructor calls - add syncId parameter
        # Pattern: Document( without syncId parameter
        def fix_document_constructor(match):
            constructor_content = match.group(1)
            # Check if syncId is already present
            if 'syncId:' in constructor_content:
                return match.group(0)  # Already has syncId
            
            # Add syncId as first parameter
            if constructor_content.strip():
                return f"Document(\n      syncId: SyncIdentifierService.generate(),\n{constructor_content}"
            else:
                return f"Document(\n      syncId: SyncIdentifierService.generate(),\n"
        
        # Fix Document constructors
        content = re.sub(r'Document\(\s*(\n[^)]*)', fix_document_constructor, content, flags=re.MULTILINE | re.DOTALL)
        
        # Fix specific patterns for id parameter in constructors
        content = re.sub(r'id:\s*[^,\n]+,?\s*\n', '', content)
        
        # Fix missing syncId in test Document constructors
        content = re.sub(r'Document\(\s*userId:', 'Document(\n      syncId: SyncIdentifierService.generate(),\n      userId:', content)
        
        # Save if changed
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Fixed: {file_path}")
            return True
        
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Main function to fix all Dart files"""
    
    # Get all Dart files
    dart_files = []
    for root, dirs, files in os.walk('.'):
        # Skip build and .dart_tool directories
        dirs[:] = [d for d in dirs if d not in ['.dart_tool', 'build', '.git']]
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))
    
    print(f"Found {len(dart_files)} Dart files")
    
    fixed_count = 0
    for file_path in dart_files:
        if fix_document_references(file_path):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files")

if __name__ == "__main__":
    main()