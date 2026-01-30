# Amplify Schema Update Guide

**Date**: January 18, 2026  
**Purpose**: Update Amplify GraphQL schema to support Category and Date fields

## Changes Made to Schema

### 1. Added DocumentCategory Enum
```graphql
enum DocumentCategory {
  CAR_INSURANCE
  HOME_INSURANCE
  HOLIDAY
  EXPENSES
  OTHER
}
```

### 2. Updated Document Type
**Removed Fields**:
- `filePaths: [String!]!` - Replaced by FileAttachment relationship
- `renewalDate: AWSDateTime` - Replaced by generic `date` field
- `lastModified: AWSDateTime` - Renamed to `updatedAt`
- `version: Int!` - Not needed with current sync strategy
- `conflictId: String` - Not needed with current sync strategy
- `contentHash: String` - Not needed with current sync strategy

**Added Fields**:
- `category: DocumentCategory!` - Required enum field
- `date: AWSDateTime` - Optional date field (replaces renewalDate)
- `labels: [String!]` - Array of label strings

**Renamed Fields**:
- `lastModified` → `updatedAt`

### 3. Final Document Schema
```graphql
type Document @model @auth(rules: [{allow: owner, ownerField: "userId", identityClaim: "sub"}]) {
  syncId: String! @primaryKey
  userId: String! @index(name: "byUserId", sortKeyFields: ["createdAt"])
  title: String!
  category: DocumentCategory!
  date: AWSDateTime
  notes: String
  labels: [String!]
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
  syncState: String!
  deleted: Boolean
  deletedAt: AWSDateTime
}
```

## Deployment Steps

### Option 1: Update Existing API (Recommended for Development)

**⚠️ WARNING**: This will modify your existing DynamoDB tables. Backup data first!

```bash
# 1. Navigate to project directory
cd household_docs_app

# 2. Update the schema file
# The schema.graphql file has already been updated

# 3. Push changes to Amplify
amplify push

# 4. Review the changes Amplify will make
# - It will show you the schema changes
# - Confirm you want to proceed

# 5. Amplify will:
# - Update DynamoDB table schema
# - Add new columns (category, date, labels)
# - Remove old columns (filePaths, renewalDate, etc.)
# - Update GraphQL API
# - Regenerate Flutter models
```

### Option 2: Create New API (Recommended for Production)

If you have existing production data, consider creating a new API version:

```bash
# 1. Create a new API
amplify add api

# 2. Choose GraphQL
# 3. Provide a new API name (e.g., householdDocsAPIv2)
# 4. Use the updated schema.graphql
# 5. Push changes
amplify push

# 6. Update Flutter code to use new API
# 7. Migrate data from old API to new API
# 8. Remove old API when migration complete
```

## Data Migration Considerations

### Existing Data Mapping

If you have existing documents in DynamoDB, you'll need to migrate:

1. **category** (new required field):
   - Old documents don't have this field
   - Options:
     - Set all to `OTHER` by default
     - Infer from old `category` string field
     - Manual categorization

2. **date** (replaces renewalDate):
   - Copy `renewalDate` → `date`
   - Field is optional, so null is acceptable

3. **labels** (new field):
   - Initialize as empty array `[]`
   - Can be populated later

4. **updatedAt** (replaces lastModified):
   - Copy `lastModified` → `updatedAt`

### Migration Script Example

```javascript
// AWS Lambda function to migrate documents
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const tableName = 'Document-xxxxx-dev'; // Your table name
  
  // Scan all documents
  const documents = await dynamodb.scan({ TableName: tableName }).promise();
  
  for (const doc of documents.Items) {
    // Map old category string to new enum
    let category = 'OTHER';
    if (doc.category?.includes('Car')) category = 'CAR_INSURANCE';
    else if (doc.category?.includes('Home')) category = 'HOME_INSURANCE';
    else if (doc.category?.includes('Holiday')) category = 'HOLIDAY';
    else if (doc.category?.includes('Expense')) category = 'EXPENSES';
    
    // Update document
    await dynamodb.update({
      TableName: tableName,
      Key: { syncId: doc.syncId },
      UpdateExpression: 'SET category = :cat, #date = :date, labels = :labels, updatedAt = :updated REMOVE filePaths, renewalDate, lastModified, version, conflictId, contentHash',
      ExpressionAttributeNames: {
        '#date': 'date'
      },
      ExpressionAttributeValues: {
        ':cat': category,
        ':date': doc.renewalDate || null,
        ':labels': [],
        ':updated': doc.lastModified || doc.createdAt
      }
    }).promise();
  }
  
  return { statusCode: 200, body: 'Migration complete' };
};
```

## Testing After Update

### 1. Verify Schema
```bash
# Check the generated schema
cat amplify/backend/api/householddocsapp/build/schema.graphql
```

### 2. Test Queries
```graphql
# Create a document with new schema
mutation CreateDocument {
  createDocument(input: {
    syncId: "test-uuid"
    userId: "test-user"
    title: "Test Document"
    category: CAR_INSURANCE
    date: "2024-12-31T00:00:00Z"
    notes: "Test notes"
    labels: ["test"]
    syncState: "synced"
    deleted: false
  }) {
    syncId
    title
    category
    date
  }
}

# Query documents by category
query ListByCategory {
  listDocuments(filter: {category: {eq: CAR_INSURANCE}}) {
    items {
      syncId
      title
      category
      date
      labels
    }
  }
}
```

### 3. Test Flutter App
```bash
# Run the app
flutter run

# Test:
# - Create new document with category
# - Select different categories
# - Verify date label changes
# - Save and sync document
# - Verify data appears in DynamoDB
```

## Rollback Plan

If issues occur:

```bash
# 1. Revert schema changes
git checkout HEAD~1 schema.graphql

# 2. Push reverted schema
amplify push

# 3. Or restore from backup
amplify env checkout <previous-env>
```

## Important Notes

1. **Breaking Change**: This is a breaking change for existing apps
2. **Version Bump**: Consider bumping app version to 3.0.0
3. **User Communication**: Notify users of update requirements
4. **Data Backup**: Always backup DynamoDB data before schema changes
5. **Testing**: Test thoroughly in dev environment before production
6. **Gradual Rollout**: Consider phased rollout to production users

## Category Enum Mapping

| Flutter Enum | GraphQL Enum | Display Name |
|--------------|--------------|--------------|
| `carInsurance` | `CAR_INSURANCE` | Car Insurance |
| `homeInsurance` | `HOME_INSURANCE` | Home Insurance |
| `holiday` | `HOLIDAY` | Holiday |
| `expenses` | `EXPENSES` | Expenses |
| `other` | `OTHER` | Other |

## Date Field Usage by Category

| Category | Date Label | Purpose |
|----------|------------|---------|
| Car Insurance | Renewal Date | When policy renews |
| Home Insurance | Renewal Date | When policy renews |
| Holiday | Payment Due | When payment is due |
| Expenses | Date | General date field |
| Other | Date | General date field |

## Next Steps

1. ✅ Update schema.graphql (completed)
2. ⏳ Backup existing DynamoDB data
3. ⏳ Run `amplify push` to deploy changes
4. ⏳ Test in development environment
5. ⏳ Create data migration script (if needed)
6. ⏳ Update app version to 3.0.0
7. ⏳ Deploy to production
8. ⏳ Monitor for issues
