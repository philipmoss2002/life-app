# Enable DataStore Code Generation

## Problem

After running `amplify push`, the `ModelProvider.dart` file is not being generated.

## Root Cause

DataStore code generation needs to be explicitly enabled in your Amplify project configuration.

## Solution

### Option 1: Enable via Amplify CLI (Recommended)

Run this command to enable DataStore for your API:

```bash
amplify update api
```

When prompted:
1. Select: **Enable DataStore for entire API**
2. Choose conflict resolution strategy: **Auto Merge**
3. Save and exit

Then push the changes:

```bash
amplify push
```

### Option 2: Enable via amplify/cli.json

Edit `amplify/cli.json` and add:

```json
{
  "features": {
    "graphqltransformer": {
      "addmissingownerfields": true,
      "improvepluralization": false,
      "validatetypenamereservedwords": true,
      "useexperimentalpipelinedtransformer": true,
      "enableiterativegsiupdates": true,
      "secondarykeyasgsi": true,
      "skipoverridemutationinputtypes": true,
      "transformerversion": 2,
      "suppressschemamigrationprompt": true,
      "securityenhancementnotification": false,
      "showfieldauthnotification": false,
      "usesubusernamefordefaultidentityclaim": true,
      "usefieldnameforprimarykeyconnectionfield": false,
      "enableautoindexquerynames": true,
      "respectprimarykeyattributesonconnectionfield": true,
      "shoulddeepmergedirectiveconfig": false,
      "populateownerfieldforstaticgroupauth": true
    },
    "frontend-ios": {
      "enablexcodeintegration": true
    },
    "auth": {
      "enablecaseinsensitivity": true,
      "useinclusiveterminology": true,
      "breakcirculardependency": true,
      "forcealiasattributes": false,
      "useenabledmfas": true
    },
    "codegen": {
      "useappsyncmodelgenplugin": true,
      "usedocsgeneratorplugin": true,
      "usetypesgeneratorplugin": true,
      "cleangeneratedmodelsdirectory": true,
      "retaincasestyle": true,
      "addtimestampfields": true,
      "handlelistnullabilitytransparently": true,
      "emitauthprovider": true,
      "generateindexrules": true,
      "enabledartnullsafety": true,
      "generatemodelsforlazyloadandcustomselectionset": false
    },
    "appsync": {
      "generategraphqlpermissions": true
    },
    "latestregionsupport": {
      "pinpoint": 1,
      "translate": 1,
      "transcribe": 1,
      "rekognition": 1,
      "textract": 1,
      "comprehend": 1
    },
    "project": {
      "overrides": true
    }
  },
  "debug": {}
}
```

### Option 3: Manual Configuration

1. **Edit `amplify/backend/api/householddocsapp/transform.conf.json`:**

```json
{
    "Version": 5,
    "ElasticsearchWarning": true,
    "ResolverConfig": {
        "project": {
            "ConflictHandler": "AUTOMERGE",
            "ConflictDetection": "VERSION"
        }
    }
}
```

2. **Run codegen manually:**

```bash
amplify codegen models
```

This should generate the models in `lib/models/`.

### Option 4: Use amplify configure codegen

```bash
amplify configure codegen
```

When prompted:
- Choose the code generation language target: **dart**
- Enter the file name pattern of graphql queries, mutations and subscriptions: **lib/graphql/**/*.graphql**
- Do you want to generate/update all possible GraphQL operations: **Yes**
- Enter maximum statement depth: **2**
- Enter the file name for the generated code: **lib/models/**
- Do you want to generate code for your newly created GraphQL API: **Yes**

Then run:

```bash
amplify codegen
```

## Verify DataStore is Enabled

After making changes, verify with:

```bash
amplify status
```

You should see something like:

```
| Category | Resource name      | Operation | Provider plugin   |
| -------- | ------------------ | --------- | ----------------- |
| Api      | householddocsapp   | No Change | awscloudformation |
| Auth     | householddocsapp   | No Change | awscloudformation |
| Storage  | householddocsfiles | No Change | awscloudformation |
```

## Generate Models

After enabling DataStore, generate the models:

```bash
amplify codegen models
```

This should create:
- `lib/models/ModelProvider.dart`
- `lib/models/Document.dart`
- `lib/models/FileAttachment.dart`
- `lib/models/Device.dart`
- etc.

## Check Generated Files

After running `amplify codegen models`, verify:

```bash
ls lib/models/
```

You should see:
- `ModelProvider.dart`
- `Document.dart`
- `FileAttachment.dart`
- `Device.dart`
- `SyncQueue.dart`
- `Subscription.dart`
- `StorageUsage.dart`
- `Conflict.dart`

## Troubleshooting

### Models still not generated

1. **Check your schema has @model directive:**
   ```graphql
   type Document @model @auth(rules: [{allow: owner}]) {
     id: ID!
     title: String!
     # ...
   }
   ```

2. **Try cleaning and regenerating:**
   ```bash
   rm -rf lib/models/
   amplify codegen models
   ```

3. **Check Amplify CLI version:**
   ```bash
   amplify --version
   ```
   Should be 12.0.0 or higher. Update if needed:
   ```bash
   npm install -g @aws-amplify/cli@latest
   ```

4. **Check for errors in schema:**
   ```bash
   amplify api gql-compile
   ```

### "amplify codegen models" command not found

This means you need to configure codegen first:

```bash
amplify configure codegen
```

Then try again:

```bash
amplify codegen models
```

### Models generated but not in lib/models/

Check the codegen configuration:

```bash
amplify configure codegen
```

Make sure the output path is set to `lib/models/`.

## Alternative: Use AppSync Console

If CLI isn't working, you can also generate models from AWS AppSync console:

1. Go to AWS AppSync console
2. Select your API
3. Go to "Schema" tab
4. Click "Generate code"
5. Select "Dart"
6. Download the generated code
7. Extract to `lib/models/`

## Summary

The key steps are:

1. ✅ Enable DataStore: `amplify update api` → Enable DataStore
2. ✅ Configure codegen: `amplify configure codegen`
3. ✅ Generate models: `amplify codegen models`
4. ✅ Verify files: Check `lib/models/` directory
5. ✅ Push changes: `amplify push`

After this, `ModelProvider.dart` and all model files should be generated! 🎉
