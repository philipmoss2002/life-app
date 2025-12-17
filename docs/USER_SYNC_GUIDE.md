# Cloud Sync User Guide

## Overview

The Household Docs App now includes powerful cloud synchronization features that keep your documents and files synchronized across all your devices. This guide explains how sync works, what to expect, and how to troubleshoot common issues.

## What is Cloud Sync?

Cloud sync automatically backs up your documents and files to secure cloud storage, making them available on all your devices. When you add, edit, or delete a document on one device, the changes appear on your other devices within seconds.

### Key Benefits

- **Automatic Backup**: Your documents are automatically backed up to the cloud
- **Multi-Device Access**: Access your documents from any device
- **Real-Time Updates**: Changes sync instantly across devices
- **Offline Support**: Continue working offline; changes sync when you're back online
- **Version History**: Previous versions are preserved for recovery

## Getting Started with Sync

### 1. Enable Cloud Sync

1. Open the Household Docs App
2. Go to **Settings** → **Cloud Sync**
3. Sign in with your account or create a new one
4. Toggle **Enable Cloud Sync** to ON
5. Choose your sync preferences

### 2. Initial Sync

When you first enable cloud sync:

1. The app will upload all your existing documents
2. You'll see a progress indicator showing sync status
3. Large files may take longer to upload
4. Keep the app open during initial sync for best performance

**Tip**: Connect to Wi-Fi for faster initial sync, especially if you have many large files.

## Understanding Sync Status

### Sync Status Icons

| Icon | Status | Meaning |
|------|--------|---------|
| ✅ | Synced | Document is up to date on all devices |
| 🔄 | Syncing | Document is currently being synchronized |
| ⏸️ | Pending | Document is queued for sync |
| ❌ | Error | Sync failed - tap for details |
| 📱 | Local Only | Document exists only on this device |
| ☁️ | Cloud Only | Document exists only in the cloud |

### Document Status Details

**Tap any document** to see detailed sync information:

- **Last Synced**: When the document was last synchronized
- **Sync Status**: Current synchronization state
- **File Status**: Status of attached files
- **Conflicts**: Any version conflicts that need resolution

## Real-Time Sync Features

### Instant Updates

When someone else in your household updates a document:

1. You'll receive a notification (if enabled)
2. The document list will update automatically
3. Open documents will show a "Document Updated" banner
4. Tap **Refresh** to see the latest changes

### Live Collaboration

- Multiple people can view the same document simultaneously
- Changes from others appear with a brief highlight
- Conflicts are automatically detected and flagged for resolution

## Offline Mode

### How Offline Mode Works

When you lose internet connection:

1. The app automatically switches to offline mode
2. You can continue viewing and editing documents
3. Changes are saved locally and queued for sync
4. A "Offline" indicator appears in the status bar

### Returning Online

When internet connection is restored:

1. The app automatically detects connectivity
2. Queued changes are uploaded in order
3. You'll see sync progress for each document
4. Conflicts are detected and presented for resolution

### Offline Limitations

While offline, you cannot:
- Download new documents from other devices
- Access documents that aren't cached locally
- Upload new files larger than 10MB
- Receive real-time updates from other devices

## File Management

### Supported File Types

The app supports synchronization of:

- **Documents**: PDF, DOC, DOCX, TXT
- **Images**: JPG, PNG, GIF, HEIC
- **Spreadsheets**: XLS, XLSX, CSV
- **Other**: ZIP, RTF (up to 100MB per file)

### File Upload Process

1. **Select Files**: Choose files to attach to a document
2. **Upload Progress**: Watch the progress bar for each file
3. **Verification**: Files are verified for integrity after upload
4. **Availability**: Files become available on other devices once uploaded

### Large File Handling

For files larger than 5MB:
- Upload uses advanced multipart technology
- Progress is shown in smaller increments
- Upload can resume if interrupted
- Compression is applied when possible

## Conflict Resolution

### When Conflicts Occur

Conflicts happen when:
- The same document is edited on multiple devices while offline
- Network issues cause sync delays
- Multiple people edit the same document simultaneously

### Resolving Conflicts

When a conflict is detected:

1. **Notification**: You'll receive a conflict notification
2. **Review Options**: Choose from available resolution options:
   - **Keep Local**: Use your device's version
   - **Keep Remote**: Use the cloud version
   - **Merge Changes**: Combine both versions (when possible)
   - **Keep Both**: Save both versions as separate documents

3. **Preview Changes**: See what's different between versions
4. **Apply Resolution**: Confirm your choice to resolve the conflict

### Conflict Prevention Tips

- Sync regularly when online
- Avoid editing the same document on multiple devices simultaneously
- Use the "Refresh" button before making major edits
- Enable real-time notifications to stay informed of changes

## Sync Settings

### Access Sync Settings

1. Go to **Settings** → **Cloud Sync**
2. Adjust preferences based on your needs

### Available Settings

#### Sync Frequency
- **Real-Time**: Sync immediately when changes are made (recommended)
- **Every 5 Minutes**: Sync at regular intervals
- **Manual Only**: Sync only when you tap the sync button

#### Network Preferences
- **Wi-Fi Only**: Sync only when connected to Wi-Fi
- **Wi-Fi + Cellular**: Sync on any internet connection
- **Cellular Limit**: Set data usage limits for cellular sync

#### File Sync Options
- **Sync All Files**: Upload all attached files (recommended)
- **Images Only**: Sync only image files
- **Documents Only**: Sync only document files
- **Manual Selection**: Choose which files to sync

#### Notifications
- **Sync Completion**: Notify when sync operations complete
- **Conflicts**: Alert when conflicts need resolution
- **Errors**: Notify about sync errors
- **Updates**: Alert when documents are updated by others

### Storage Management

#### View Storage Usage
- **Total Used**: How much cloud storage you're using
- **Available**: Remaining storage in your plan
- **By Category**: Storage breakdown by file type

#### Manage Storage
- **Delete Old Versions**: Remove old document versions
- **Compress Files**: Reduce file sizes to save space
- **Archive Documents**: Move old documents to archive storage

## Troubleshooting Common Issues

### Sync Not Working

**Problem**: Documents aren't syncing between devices

**Solutions**:
1. Check internet connection
2. Verify you're signed in to the same account on all devices
3. Go to Settings → Cloud Sync → **Force Sync**
4. Restart the app
5. Check if sync is enabled in settings

### Slow Sync Performance

**Problem**: Sync is taking too long

**Solutions**:
1. Connect to Wi-Fi for faster speeds
2. Close other apps using internet
3. Sync during off-peak hours
4. Check if large files are in the queue
5. Restart your router/modem

### Files Not Uploading

**Problem**: File attachments won't upload

**Solutions**:
1. Check file size (must be under 100MB)
2. Verify file type is supported
3. Ensure sufficient storage space
4. Check internet connection stability
5. Try uploading files one at a time

### Authentication Issues

**Problem**: Can't sign in or stay signed in

**Solutions**:
1. Check email and password
2. Use "Forgot Password" if needed
3. Clear app cache and data
4. Update the app to latest version
5. Contact support if issues persist

### Conflict Resolution Problems

**Problem**: Conflicts keep appearing

**Solutions**:
1. Ensure all devices have the latest app version
2. Sync more frequently
3. Avoid editing the same document on multiple devices
4. Check system time on all devices
5. Use "Keep Remote" to reset local conflicts

### Storage Full

**Problem**: "Storage Full" error messages

**Solutions**:
1. Delete unnecessary documents
2. Remove old file versions
3. Compress large files
4. Upgrade to a higher storage plan
5. Archive old documents

## Advanced Features

### Sync Analytics

View detailed sync statistics:
- **Sync History**: See all recent sync operations
- **Performance Metrics**: Upload/download speeds and success rates
- **Error Logs**: Detailed information about sync failures
- **Usage Patterns**: When and how often you sync

### Backup and Recovery

#### Automatic Backups
- Documents are automatically backed up every time they sync
- File versions are preserved for 30 days
- Deleted documents can be recovered for 7 days

#### Manual Backup
1. Go to Settings → **Backup & Recovery**
2. Tap **Create Backup**
3. Choose what to include in the backup
4. Wait for backup completion

#### Restore from Backup
1. Go to Settings → **Backup & Recovery**
2. Select a backup from the list
3. Choose what to restore
4. Confirm the restoration

### Family Sharing

#### Set Up Family Sharing
1. Go to Settings → **Family Sharing**
2. Tap **Create Family Group**
3. Invite family members by email
4. Set permissions for each member

#### Sharing Permissions
- **View Only**: Can see documents but not edit
- **Edit**: Can view and edit documents
- **Admin**: Full access including sharing settings

### Security Features

#### Encryption
- All data is encrypted during transmission
- Files are encrypted at rest in cloud storage
- End-to-end encryption for sensitive documents

#### Access Control
- Two-factor authentication available
- Device authorization required
- Remote device management and revocation

## Getting Help

### In-App Help

1. Go to Settings → **Help & Support**
2. Browse frequently asked questions
3. Search for specific topics
4. Access video tutorials

### Contact Support

If you need additional help:

1. **Email**: support@householddocs.com
2. **In-App**: Settings → Help & Support → Contact Us
3. **Phone**: Available for premium users

When contacting support, please include:
- Your device type and app version
- Description of the issue
- Steps you've already tried
- Screenshots if applicable

### Community Resources

- **User Forum**: Connect with other users
- **Knowledge Base**: Detailed articles and guides
- **Video Tutorials**: Step-by-step visual guides
- **Release Notes**: Information about new features

## Tips for Best Performance

### Optimize Sync Performance

1. **Use Wi-Fi**: Sync is faster and more reliable on Wi-Fi
2. **Regular Sync**: Don't let too many changes accumulate
3. **File Management**: Keep file sizes reasonable when possible
4. **App Updates**: Always use the latest app version
5. **Device Storage**: Ensure adequate free space on your device

### Battery Optimization

1. **Background Sync**: Allow the app to sync in the background
2. **Battery Settings**: Exclude the app from battery optimization
3. **Charging**: Sync large amounts of data while charging
4. **Sleep Mode**: Disable sleep mode during large syncs

### Data Usage Management

1. **Wi-Fi Preference**: Set sync to prefer Wi-Fi connections
2. **Cellular Limits**: Set monthly data limits for cellular sync
3. **File Types**: Choose which file types to sync on cellular
4. **Compression**: Enable file compression to reduce data usage

This user guide provides comprehensive information about the cloud sync features. Keep it handy as you explore the powerful synchronization capabilities of the Household Docs App!