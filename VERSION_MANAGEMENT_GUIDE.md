# App Version Management Guide

## Current Version Status

**✅ Updated:** `1.0.1+2`  
**Previous:** `1.0.0+1`  
**File:** `pubspec.yaml`

## 📋 **Version Format Explained**

### Flutter Version Format: `MAJOR.MINOR.PATCH+BUILD`

```yaml
version: 1.0.1+2
         │ │ │ │
         │ │ │ └── Build Number (versionCode on Android)
         │ │ └──── Patch Version
         │ └────── Minor Version  
         └──────── Major Version
```

### What Each Number Means:

- **Major (1):** Breaking changes, major new features
- **Minor (0):** New features, backwards compatible
- **Patch (1):** Bug fixes, small improvements
- **Build (+2):** Internal build number, increments with each release

## 🔄 **When to Increment Each Number**

### Build Number (+X) - **Always Increment**
**Increment for:** Every upload to Google Play Console
```yaml
# Before upload
version: 1.0.1+2

# Next upload
version: 1.0.1+3  # Only build number changes
```

### Patch Version (X.X.X)
**Increment for:** Bug fixes, small improvements
```yaml
# Bug fix release
version: 1.0.1+2  →  version: 1.0.2+3
```

### Minor Version (X.X.0)
**Increment for:** New features, backwards compatible
```yaml
# New feature release
version: 1.0.2+3  →  version: 1.1.0+4
```

### Major Version (X.0.0)
**Increment for:** Breaking changes, major redesign
```yaml
# Major release
version: 1.1.0+4  →  version: 2.0.0+5
```

## 🎯 **Current Release: v1.0.1+2**

### What's New in This Version:
- ✅ **Fixed:** Subscription acknowledgment issue
- ✅ **Added:** GDPR account deletion functionality
- ✅ **Improved:** Purchase verification and error handling
- ✅ **Enhanced:** Subscription service reliability

### Why This Version Number:
- **Patch increment (1.0.0 → 1.0.1):** Bug fixes and improvements
- **Build increment (+1 → +2):** New build for Google Play Console

## 📱 **Platform-Specific Version Usage**

### Android (Google Play Console)
- **Version Name:** `1.0.1` (shown to users)
- **Version Code:** `2` (internal, must always increase)

### iOS (App Store Connect)
- **Version:** `1.0.1` (CFBundleShortVersionString)
- **Build:** `2` (CFBundleVersion)

## 🛠️ **How to Update Version**

### Step 1: Edit pubspec.yaml
```yaml
# Current
version: 1.0.1+2

# For next bug fix
version: 1.0.2+3

# For new feature
version: 1.1.0+4
```

### Step 2: Build and Upload
```bash
flutter clean
flutter build appbundle --release
# Upload to Google Play Console
```

## 📊 **Version History Tracking**

### Recommended Changelog Format:

```markdown
## Version 1.0.1+2 (December 2025)
### Fixed
- Subscription acknowledgment issue
- Purchase verification problems

### Added
- GDPR account deletion
- Enhanced error handling

### Changed
- Improved subscription service reliability
```

## 🚨 **Important Rules**

### ✅ **Always Do:**
- **Increment build number** for every Google Play upload
- **Test thoroughly** before incrementing version
- **Document changes** in changelog
- **Follow semantic versioning** principles

### ❌ **Never Do:**
- **Decrease version numbers** (Google Play rejects)
- **Skip build numbers** (can cause confusion)
- **Use same version** for different builds
- **Forget to update** before uploading

## 🔄 **Version Update Workflow**

### For Bug Fixes:
1. **Fix the bugs** in code
2. **Increment patch version:** `1.0.1+2` → `1.0.2+3`
3. **Test thoroughly**
4. **Build and upload**
5. **Update changelog**

### For New Features:
1. **Implement features**
2. **Increment minor version:** `1.0.2+3` → `1.1.0+4`
3. **Test thoroughly**
4. **Build and upload**
5. **Update changelog**

### For Major Changes:
1. **Implement major changes**
2. **Increment major version:** `1.1.0+4` → `2.0.0+5`
3. **Extensive testing**
4. **Build and upload**
5. **Update changelog**

## 📋 **Pre-Release Checklist**

Before incrementing version:

- [ ] **All features implemented** and tested
- [ ] **All bugs fixed** and verified
- [ ] **Tests passing** (`flutter test`)
- [ ] **No build errors** (`flutter build appbundle --release`)
- [ ] **Version number appropriate** for changes made
- [ ] **Changelog updated** with changes
- [ ] **Ready for user testing**

## 🎯 **Quick Reference**

### Current Version Commands:
```bash
# Check current version
grep "version:" pubspec.yaml

# Build with current version
flutter build appbundle --release

# Check built version
# Look in Google Play Console after upload
```

### Next Version Examples:
```yaml
# Bug fix release
version: 1.0.2+3

# Feature release  
version: 1.1.0+4

# Major release
version: 2.0.0+5
```

## 📞 **Version-Related Issues**

### "Version code X has already been used"
**Solution:** Increment build number in pubspec.yaml

### "Version name must be higher than previous"
**Solution:** Increment version number (not just build number)

### Users not seeing update
**Solution:** Ensure version name increased, not just build number

## 🎉 **Current Status**

**✅ Ready for Upload:**
- Version: `1.0.1+2`
- Changes: Subscription fixes + GDPR compliance
- Status: Ready for Google Play Console upload

**Next Steps:**
1. Build AAB: `flutter build appbundle --release`
2. Upload to Google Play Console
3. Test with users
4. Monitor for issues

---

**Remember:** Always increment the build number (+X) for every upload to Google Play Console, even if it's the same version name! 🎯