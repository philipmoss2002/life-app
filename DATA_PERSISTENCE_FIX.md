# Data Persistence After Uninstall - Analysis & Solution

## 🔍 **Issue Analysis**

### **Current Data Storage Locations:**

#### **1. SQLite Database**
- **Location**: `getDatabasesPath()` + `household_docs.db`
- **Platform Behavior**:
  - **Android**: Usually deleted on uninstall
  - **iOS**: Usually deleted on uninstall  
  - **Some Android devices**: May persist in external storage

#### **2. File Cache (Thumbnails & Downloads)**
- **Location**: `getApplicationDocumentsDirectory()` + `/cache/` and `/thumbnails/`
- **Platform Behavior**:
  - **Android**: Often persists after uninstall (external storage)
  - **iOS**: Usually deleted on uninstall
  - **Problem**: Cache files remain on device

#### **3. User-Selected Files**
- **Location**: Original file system locations (Downloads, Documents, etc.)
- **Behavior**: Always persist (not app-owned)
- **Impact**: File references in database become invalid

### **Root Cause:**
The app uses `getApplicationDocumentsDirectory()` for caching, which on Android often maps to external storage that persists after app uninstall.

## ✅ **Solution Implementation**

### **1. Use Temporary Storage for Cache**
Replace persistent cache with temporary storage that's guaranteed to be cleaned up.

### **2. Implement Proper Data Cleanup**
Add methods to clear all app data when needed.

### **3. Use App-Internal Storage**
Ensure all app data uses internal storage that's removed on uninstall.

## 🔧 **Implementation Plan**

### **Phase 1: Fix Database Storage**
```dart
// Use getApplicationSupportDirectory() instead of getDatabasesPath()
// This ensures app-internal storage on all platforms
Future<Database> _initDB(String filePath) async {
  final appDir = await getApplicationSupportDirectory();
  final path = join(appDir.path, 'databases', filePath);
  
  // Ensure directory exists
  final dbDir = Directory(dirname(path));
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }
  
  return await openDatabase(path, version: 6, onCreate: _createDB, onUpgrade: _upgradeDB);
}
```

### **Phase 2: Fix File Cache Storage**
```dart
// Use getTemporaryDirectory() for cache files
Future<String> _getLocalCachePath(String s3Key, String syncId) async {
  final tempDir = await getTemporaryDirectory();
  final fileName = path.basename(s3Key);
  final localDir = Directory('${tempDir.path}/app_cache/$syncId');
  
  if (!await localDir.exists()) {
    await localDir.create(recursive: true);
  }
  
  return '${localDir.path}/$fileName';
}

// Use temporary directory for thumbnails
Future<String?> cacheThumbnail(String s3Key, List<int> thumbnailBytes) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final thumbnailDir = Directory('${tempDir.path}/app_thumbnails');
    
    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }
    
    final thumbnailFileName = s3Key.replaceAll('/', '_') + '_thumb.jpg';
    final thumbnailPath = '${thumbnailDir.path}/$thumbnailFileName';
    
    await File(thumbnailPath).writeAsBytes(thumbnailBytes);
    return thumbnailPath;
  } catch (e) {
    safePrint('Error caching thumbnail: $e');
    return null;
  }
}
```

### **Phase 3: Add Data Cleanup Service**
```dart
class DataCleanupService {
  static final DataCleanupService _instance = DataCleanupService._internal();
  factory DataCleanupService() => _instance;
  DataCleanupService._internal();

  /// Clear all app data (for complete reset or uninstall preparation)
  Future<void> clearAllAppData() async {
    try {
      // Clear database
      await DatabaseService.instance.clearAllData();
      
      // Clear file cache
      await _clearFileCache();
      
      // Clear thumbnails
      await _clearThumbnailCache();
      
      // Clear temporary files
      await _clearTempFiles();
      
      safePrint('All app data cleared successfully');
    } catch (e) {
      safePrint('Error clearing app data: $e');
    }
  }

  /// Clear user-specific data (for sign out)
  Future<void> clearUserData(String userId) async {
    try {
      // Clear user documents from database
      await DatabaseService.instance.clearUserData(userId);
      
      // Clear user-specific cache files
      await _clearUserCache(userId);
      
      safePrint('User data cleared for: $userId');
    } catch (e) {
      safePrint('Error clearing user data: $e');
    }
  }

  Future<void> _clearFileCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/app_cache');
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      safePrint('Error clearing file cache: $e');
    }
  }

  Future<void> _clearThumbnailCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailDir = Directory('${tempDir.path}/app_thumbnails');
      
      if (await thumbnailDir.exists()) {
        await thumbnailDir.delete(recursive: true);
      }
    } catch (e) {
      safePrint('Error clearing thumbnail cache: $e');
    }
  }

  Future<void> _clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final appTempDir = Directory('${tempDir.path}/app_temp');
      
      if (await appTempDir.exists()) {
        await appTempDir.delete(recursive: true);
      }
    } catch (e) {
      safePrint('Error clearing temp files: $e');
    }
  }

  Future<void> _clearUserCache(String userId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final userCacheDir = Directory('${tempDir.path}/app_cache/user_$userId');
      
      if (await userCacheDir.exists()) {
        await userCacheDir.delete(recursive: true);
      }
    } catch (e) {
      safePrint('Error clearing user cache: $e');
    }
  }
}
```

### **Phase 4: Update Authentication Service**
```dart
// In AuthenticationService.signOut()
Future<void> signOut() async {
  try {
    // Get current user ID before signing out
    final currentUser = await getCurrentUser();
    
    // Sign out from Amplify
    await Amplify.Auth.signOut(
      options: const SignOutOptions(globalSignOut: true),
    );

    // Clear user-specific data
    await DataCleanupService().clearUserData(currentUser.id);
    
    _authStateController.add(AuthState.unauthenticated);
    safePrint('User signed out and data cleared');
  } catch (e) {
    safePrint('Sign out failed: $e');
    rethrow;
  }
}
```

### **Phase 5: Add Settings Option**
```dart
// In SettingsScreen - add data management section
Widget _buildDataManagementSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Data Management',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      
      ListTile(
        leading: const Icon(Icons.cleaning_services),
        title: const Text('Clear Cache'),
        subtitle: const Text('Clear temporary files and thumbnails'),
        onTap: _clearCache,
      ),
      
      ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
        subtitle: const Text('Remove all documents and files'),
        onTap: _showClearAllDataDialog,
      ),
    ],
  );
}

Future<void> _clearCache() async {
  try {
    await DataCleanupService()._clearFileCache();
    await DataCleanupService()._clearThumbnailCache();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared successfully')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing cache: $e')),
      );
    }
  }
}

Future<void> _showClearAllDataDialog() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear All Data'),
      content: const Text(
        'This will permanently delete all your documents and files. '
        'This action cannot be undone. Are you sure?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete All'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _clearAllData();
  }
}

Future<void> _clearAllData() async {
  try {
    await DataCleanupService().clearAllAppData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared successfully')),
      );
      
      // Navigate to sign-in screen
      Navigator.pushReplacementNamed(context, '/signin');
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing data: $e')),
      );
    }
  }
}
```

## 🎯 **Expected Results**

### **After Implementation:**
- ✅ **Database**: Stored in app-internal directory, removed on uninstall
- ✅ **Cache Files**: Stored in temporary directory, automatically cleaned up
- ✅ **Thumbnails**: Stored in temporary directory, automatically cleaned up
- ✅ **User Control**: Manual data clearing options in settings
- ✅ **Sign Out**: Automatic user data cleanup on sign out

### **Platform Behavior:**
- **Android**: All app data removed on uninstall
- **iOS**: All app data removed on uninstall (already working)
- **Manual**: Users can clear data anytime via settings

### **Storage Locations (After Fix):**
```
App Internal Storage (Removed on Uninstall):
├── databases/
│   └── household_docs.db
└── support_files/

Temporary Storage (Auto-cleaned):
├── app_cache/
│   └── [user_files]
├── app_thumbnails/
│   └── [thumbnails]
└── app_temp/
    └── [temporary_files]
```

## 📋 **Implementation Priority**

### **High Priority (Immediate):**
1. Fix database storage location
2. Fix file cache storage location
3. Add data cleanup service

### **Medium Priority (Next Release):**
1. Add settings UI for data management
2. Implement automatic cleanup on sign out
3. Add cache size monitoring

### **Low Priority (Future):**
1. Add data export before cleanup
2. Implement selective data clearing
3. Add storage usage analytics

**Status: 🟡 READY FOR IMPLEMENTATION - Will ensure proper data cleanup on app uninstall**