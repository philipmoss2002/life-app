# Sync Troubleshooting Guide for Users

## Quick Fixes

### Try These First

Before diving into detailed troubleshooting, try these quick solutions that resolve most sync issues:

1. **Force Refresh**: Pull down on the document list to refresh
2. **Check Internet**: Ensure you have a stable internet connection
3. **Restart App**: Close and reopen the Household Docs App
4. **Check Sign-In**: Verify you're signed in to your account
5. **Update App**: Make sure you have the latest version installed

## Common Sync Issues

### 1. Documents Not Syncing

#### Symptoms
- Changes made on one device don't appear on others
- New documents don't show up on other devices
- Sync status shows "Pending" or "Error"

#### Step-by-Step Solution

**Step 1: Check Sync Status**
1. Open the app and go to the main document list
2. Look for sync status icons next to each document
3. If you see ❌ (error) icons, tap on the document for details

**Step 2: Verify Account**
1. Go to **Settings** → **Account**
2. Confirm you're signed in with the correct email
3. If signed out, sign back in with your credentials

**Step 3: Check Internet Connection**
1. Try opening a web browser or another app that uses internet
2. If on Wi-Fi, try switching to cellular data (or vice versa)
3. Move closer to your Wi-Fi router if signal is weak

**Step 4: Force Sync**
1. Go to **Settings** → **Cloud Sync**
2. Tap **Sync Now** or **Force Sync**
3. Wait for the sync to complete (may take several minutes)

**Step 5: Check Sync Settings**
1. In **Settings** → **Cloud Sync**, ensure:
   - **Enable Cloud Sync** is turned ON
   - **Sync Frequency** is set to "Real-Time" or "Every 5 Minutes"
   - Network settings allow your current connection type

### 2. Files Not Uploading

#### Symptoms
- File attachments show "Upload Failed" status
- Files appear on one device but not others
- Upload progress gets stuck at a certain percentage

#### Step-by-Step Solution

**Step 1: Check File Requirements**
1. Verify file size is under 100MB
2. Confirm file type is supported (PDF, DOC, JPG, PNG, etc.)
3. Check that the file isn't corrupted (try opening it)

**Step 2: Check Storage Space**
1. Go to **Settings** → **Storage**
2. Verify you have available cloud storage space
3. If storage is full, delete old documents or upgrade your plan

**Step 3: Retry Upload**
1. Tap on the failed file attachment
2. Select **Retry Upload**
3. If it fails again, try removing and re-adding the file

**Step 4: Check Network Stability**
1. Ensure you have a stable internet connection
2. For large files, connect to Wi-Fi if possible
3. Avoid uploading during peak internet usage times

**Step 5: Upload One at a Time**
1. If uploading multiple files, try uploading them one by one
2. Wait for each upload to complete before starting the next
3. This helps identify if a specific file is causing issues

### 3. Slow Sync Performance

#### Symptoms
- Sync takes much longer than expected
- Progress bars move very slowly
- App becomes unresponsive during sync

#### Step-by-Step Solution

**Step 1: Check Network Speed**
1. Test your internet speed using a speed test app or website
2. If speed is slow, try:
   - Moving closer to Wi-Fi router
   - Restarting your router
   - Switching to a different network

**Step 2: Optimize Sync Settings**
1. Go to **Settings** → **Cloud Sync** → **Network Preferences**
2. If on cellular, enable **Wi-Fi Only** sync
3. Set **File Sync** to "Images Only" temporarily to speed up document sync

**Step 3: Close Other Apps**
1. Close apps that use internet heavily (streaming, downloads, etc.)
2. Pause any ongoing downloads or updates
3. This gives more bandwidth to the sync process

**Step 4: Sync During Off-Peak Hours**
1. Try syncing early morning or late evening
2. Avoid syncing during busy internet times (evenings, weekends)
3. Schedule large syncs for overnight when possible

### 4. Authentication Problems

#### Symptoms
- "Sign In Required" messages
- App keeps asking for password
- "Invalid Credentials" errors

#### Step-by-Step Solution

**Step 1: Verify Credentials**
1. Double-check your email address for typos
2. Ensure you're using the correct password
3. Check if Caps Lock is on

**Step 2: Reset Password**
1. On the sign-in screen, tap **Forgot Password**
2. Enter your email address
3. Check your email for reset instructions
4. Follow the link to create a new password

**Step 3: Clear App Data**
1. Go to your device's **Settings** → **Apps** → **Household Docs**
2. Tap **Storage** → **Clear Cache**
3. If that doesn't work, try **Clear Data** (you'll need to sign in again)

**Step 4: Update the App**
1. Check your app store for updates
2. Install any available updates
3. Restart the app after updating

### 5. Conflict Resolution Issues

#### Symptoms
- "Conflict Detected" notifications keep appearing
- Can't resolve document conflicts
- Multiple versions of the same document

#### Step-by-Step Solution

**Step 1: Understand the Conflict**
1. Tap on the conflict notification
2. Review the differences between versions
3. Note which device each version came from

**Step 2: Choose Resolution Strategy**
- **Keep Local**: If your changes are more recent/important
- **Keep Remote**: If the other device has the correct version
- **Keep Both**: If you want to preserve both versions

**Step 3: Prevent Future Conflicts**
1. Always sync before making major edits
2. Avoid editing the same document on multiple devices simultaneously
3. Use the **Refresh** button before editing

**Step 4: If Conflicts Persist**
1. Go to **Settings** → **Cloud Sync**
2. Tap **Reset Sync State**
3. This will re-sync all documents (may take time)

## Device-Specific Issues

### iOS Devices

#### Background App Refresh
1. Go to **Settings** → **General** → **Background App Refresh**
2. Ensure it's enabled for Household Docs
3. This allows sync to continue when the app isn't active

#### Storage Optimization
1. Go to **Settings** → **General** → **iPhone Storage**
2. Find Household Docs and check storage usage
3. If storage is full, delete other apps or files

### Android Devices

#### Battery Optimization
1. Go to **Settings** → **Battery** → **Battery Optimization**
2. Find Household Docs and set to "Don't Optimize"
3. This prevents the system from stopping sync processes

#### Data Saver Mode
1. Check if Data Saver is enabled in **Settings** → **Network & Internet**
2. If enabled, add Household Docs to the unrestricted list
3. This allows sync to work even with Data Saver on

### Windows/Mac Desktop

#### Firewall Settings
1. Check if your firewall is blocking the app
2. Add Household Docs to firewall exceptions
3. Ensure ports 80 and 443 are open for HTTPS traffic

#### Proxy Settings
1. If using a corporate network, check proxy settings
2. Configure the app to use your network's proxy
3. Contact IT support if needed

## Network-Related Issues

### Wi-Fi Problems

#### Connection Issues
1. **Forget and Reconnect**: Remove the Wi-Fi network and reconnect
2. **Router Restart**: Unplug router for 30 seconds, then plug back in
3. **DNS Settings**: Try changing DNS to 8.8.8.8 or 1.1.1.1

#### Slow Wi-Fi
1. **Move Closer**: Get closer to the Wi-Fi router
2. **Check Interference**: Move away from microwaves, baby monitors
3. **Change Channel**: Access router settings and change Wi-Fi channel

### Cellular Data Issues

#### Data Restrictions
1. Check if you have sufficient data allowance
2. Verify cellular data is enabled for the app
3. Check if you're in a good coverage area

#### Carrier-Specific Issues
1. Some carriers block certain types of traffic
2. Try using a VPN if sync works on Wi-Fi but not cellular
3. Contact your carrier if issues persist

## Error Messages and Solutions

### "Sync Failed - Network Error"
**Cause**: Internet connection problems
**Solution**: 
1. Check internet connection
2. Try switching between Wi-Fi and cellular
3. Restart your router/modem

### "Sync Failed - Authentication Error"
**Cause**: Sign-in credentials are invalid or expired
**Solution**:
1. Sign out and sign back in
2. Reset password if needed
3. Update the app to latest version

### "Sync Failed - Storage Full"
**Cause**: No available cloud storage space
**Solution**:
1. Delete old documents or files
2. Upgrade to a larger storage plan
3. Archive documents you don't need frequently

### "Sync Failed - File Too Large"
**Cause**: File exceeds 100MB size limit
**Solution**:
1. Compress the file before uploading
2. Split large files into smaller parts
3. Use a file compression app

### "Sync Failed - Server Error"
**Cause**: Temporary server issues
**Solution**:
1. Wait a few minutes and try again
2. Check the app's status page for known issues
3. Contact support if error persists

## When to Contact Support

### Contact Support If:
- Issues persist after trying all troubleshooting steps
- You're getting error messages not covered in this guide
- Sync has been broken for more than 24 hours
- You suspect data loss or corruption
- Multiple users in your household are experiencing the same issue

### Before Contacting Support:

**Gather This Information:**
1. **Device Details**: Type, operating system version
2. **App Version**: Found in Settings → About
3. **Error Messages**: Screenshots if possible
4. **Steps Tried**: List what you've already attempted
5. **Timeline**: When the issue started

**How to Contact:**
1. **In-App**: Settings → Help & Support → Contact Us
2. **Email**: support@householddocs.com
3. **Phone**: Available for premium users (number in app)

### Support Response Times:
- **Critical Issues** (data loss, security): 2-4 hours
- **High Priority** (sync not working): 4-8 hours
- **Normal Issues** (performance, questions): 24-48 hours

## Prevention Tips

### Avoid Common Issues:

1. **Keep App Updated**: Enable automatic updates
2. **Regular Sync**: Don't let changes accumulate for too long
3. **Stable Internet**: Use reliable internet connections when possible
4. **Device Maintenance**: Keep your device updated and clean
5. **Storage Management**: Regularly check and manage storage space

### Best Practices:

1. **Sync Before Editing**: Always refresh before making changes
2. **One Device at a Time**: Avoid editing the same document simultaneously
3. **Wi-Fi for Large Files**: Use Wi-Fi for uploading large files
4. **Regular Backups**: Enable automatic backups in settings
5. **Monitor Notifications**: Pay attention to sync status notifications

## Advanced Troubleshooting

### Reset Sync State
**Warning**: This will re-sync all documents and may take time

1. Go to **Settings** → **Cloud Sync**
2. Tap **Advanced** → **Reset Sync State**
3. Confirm the action
4. Wait for complete re-sync (may take hours for large libraries)

### Clear App Cache
**Note**: This won't delete your documents but will clear temporary files

**iOS:**
1. Delete and reinstall the app
2. Sign back in to your account

**Android:**
1. Settings → Apps → Household Docs → Storage → Clear Cache
2. Restart the app

### Export/Import Documents
**If sync is completely broken:**

1. **Export**: Settings → Backup & Recovery → Export Documents
2. Save the export file to a safe location
3. **Reset**: Clear app data or reinstall
4. **Import**: Settings → Backup & Recovery → Import Documents

Remember: Most sync issues are temporary and resolve themselves within a few minutes. If you're experiencing persistent problems, don't hesitate to reach out to our support team for personalized assistance!