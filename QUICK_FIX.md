# Quick Fix: Generate ModelProvider.dart

## The Problem

`amplify push` isn't generating `ModelProvider.dart` and other model files.

## The Solution (3 commands)

```bash
# 1. Enable DataStore for your API
amplify update api
# Select: "Enable DataStore for entire API"
# Conflict resolution: "Auto Merge"

# 2. Configure code generation
amplify configure codegen
# Language: dart
# File pattern: lib/graphql/**/*.graphql
# Generate all operations: Yes
# Max depth: 2
# Output: lib/models/
# Generate for API: Yes

# 3. Generate the models
amplify codegen models
```

## Verify

Check that files were created:

```bash
ls lib/models/
```

You should see:
- `ModelProvider.dart` ✅
- `Document.dart` ✅
- `FileAttachment.dart` ✅
- `Device.dart` ✅
- etc.

## If That Doesn't Work

Try this alternative:

```bash
# Clean and regenerate
rm -rf lib/models/
amplify codegen models
```

Or manually trigger:

```bash
# Update API to enable DataStore
amplify update api

# Push changes
amplify push

# Generate models
amplify codegen models
```

## Still Not Working?

Check your Amplify CLI version:

```bash
amplify --version
```

If it's below 12.0.0, update:

```bash
npm install -g @aws-amplify/cli@latest
```

Then try again:

```bash
amplify codegen models
```

## Expected Output

After running `amplify codegen models`, you should see:

```
✔ Generated GraphQL operations successfully and saved at lib/graphql
✔ Code generated successfully and saved in file lib/models
```

## Next Steps

Once models are generated:

1. ✅ Delete the placeholder `lib/models/ModelProvider.dart` (if it exists)
2. ✅ The real generated `ModelProvider.dart` will replace it
3. ✅ Run `flutter pub get`
4. ✅ Run your app: `flutter run`

The app should now compile and Amplify should initialize successfully! 🎉

## Need More Help?

See `ENABLE_DATASTORE_CODEGEN.md` for detailed troubleshooting.
