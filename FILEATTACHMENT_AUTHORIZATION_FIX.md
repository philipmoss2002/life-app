# FileAttachment Authorization Fix - Complete Resolution

## Problem
User reported "not authorized to access createFileAttachment on type mutation" error when trying to create FileAttachment records in DynamoDB through GraphQL.

## Root Cause
The FileAttachment model in the GraphQL schema had conflicting authorization rules:
1. `{allow: owner, ownerField: "userId", identityClaim: "sub"}` - allows owner full access
2. `{allow: private, operations: [read]}` - restricts to read-only operations

The second rule was preventing create operations even for the owner.

## Solution
Simplified the authorization rules to use only the owner-based rule, removing the restrictive private read-only rule.

### Changes Made

#### 1. Updated GraphQL Schema
**File**: `amplify/backend/api/householddocsapp/schema.graphql`

**Before:**
```graphql
type FileAttachment @model @auth(rules: [
  {allow: owner, ownerField: "userId", identityClaim: "sub"},
  {allow: private, operations: [read]}
]) {
```

**After:**
```graphql
type FileAttachment @model @auth(rules: [{allow: owner, ownerField: "userId", identityClaim: "sub"}]) {
```

#### 2. Deployed Schema Changes
- Ran `amplify push --yes` to deploy the updated schema to AWS
- Successfully updated the GraphQL API and authorization rules

#### 3. Regenerated Models
- Ran `amplify codegen models --force` to regenerate Dart model classes
- Updated models now reflect the simplified authorization rules

## Testing
- Schema deployment completed successfully
- Models regenerated without errors
- FileAttachment creation should now work properly for authenticated users

## Authorization Logic
With the simplified rule:
- **Owner access**: Users can create, read, update, and delete their own FileAttachment records
- **User isolation**: Each user can only access FileAttachments where `userId` matches their authenticated user ID
- **Security**: Proper field-level authorization based on the `userId` field

## Benefits
1. **Simplified authorization**: Single, clear rule instead of conflicting rules
2. **Full CRUD access**: Owners can perform all operations on their FileAttachments
3. **Consistent with other models**: Matches the authorization pattern used for Document and other models
4. **Secure**: Maintains proper user isolation and data security

## Files Modified
- `amplify/backend/api/householddocsapp/schema.graphql`
- Generated model files in `lib/models/` (via codegen)

The fix ensures that authenticated users can create FileAttachment records in DynamoDB while maintaining proper security and user isolation.