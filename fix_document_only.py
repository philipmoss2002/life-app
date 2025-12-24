#!/usr/bin/env python3
"""
Script to fix only Document model references from id to syncId
"""

import os
import re

def fix_document_references(file_path):
    """Fix Document model references in a single file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Only fix Document-specific references, not other models
        # Look for patterns like "document.id", "doc.id" where the variable is clearly a Document
        
        # Fix document.id references to document.syncId (but not other models)
        content = re.sub(r'\bdocument\.id\b', 'document.syncId', content)
        content = re.sub(r'\btestDoc\.id\b', 'testDoc.syncId', content)
        content = re.sub(r'\blocalDoc\.id\b', 'localDoc.syncId', content)
        content = re.sub(r'\bremoteDoc\.id\b', 'remoteDoc.syncId', content)
        content = re.sub(r'\bsavedDoc\.id\b', 'savedDoc.syncId', content)
        content = re.sub(r'\bupdatedDoc\.id\b', 'updatedDoc.syncId', content)
        content = re.sub(r'\boriginalDocument\.id\b', 'originalDocument.syncId', content)
        content = re.sub(r'\bconflictDocument\.id\b', 'conflictDocument.syncId', content)
        content = re.sub(r'\berrorDocument\.id\b', 'errorDocument.syncId', content)
        
        # Fix specific patterns in Document constructors
        # Remove id: parameter from Document constructors
        content = re.sub(r'Document\(\s*id:\s*[^,\n]+,?\s*\n', 'Document(\n', content)
        
        # Fix Document constructors that start with userId (add syncId)
        content = re.sub(r'Document\(\s*userId:', 'Document(\n      syncId: SyncIdentifierService.generate(),\n      userId:', content)
        
        # Fix Document constructors that are missing syncId entirely
        def fix_document_constructor(match):
            full_match = match.group(0)
            constructor_content = match.group(1)
            
            # Check if syncId is already present
            if 'syncId:' in constructor_content:
                return full_match  # Already has syncId
            
            # Add syncId as first parameter
            return f"Document(\n      syncId: SyncIdentifierService.generate(),{constructor_content}"
        
        # Apply the fix to Document constructors
        content = re.sub(r'Document\((\s*\n\s*userId:[^)]+)', fix_document_constructor, content, flags=re.MULTILINE | re.DOTALL)
        
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
    
    # Get all Dart files except generated model files
    dart_files = []
    for root, dirs, files in os.walk('.'):
        # Skip build and .dart_tool directories
        dirs[:] = [d for d in dirs if d not in ['.dart_tool', 'build', '.git']]
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                # Skip generated model files (they should not be modified)
                if '/models/' in file_path.replace('\\', '/') and file != 'sync_event.dart':
                    continue
                dart_files.append(file_path)
    
    print(f"Found {len(dart_files)} Dart files to process")
    
    fixed_count = 0
    for file_path in dart_files:
        if fix_document_references(file_path):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files")

if __name__ == "__main__":
    main()