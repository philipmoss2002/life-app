# How to Collect Subscription Debug Logs

## Quick Start

### 1. Build and Install the App

```cmd
cd household_docs_app
flutter clean
flutter build apk --release
```

Install the APK on your test device (the one with the active subscription).

### 2. Connect Device and Start Logging

Connect your Android device via USB and run:

```cmd
adb logcat -c
adb logcat | findstr "INFO"
```

This clears previous logs and shows only INFO level messages.

### 3. Open the App

Open the Household Documents app on your device. The subscription service will initialize automatically.

### 4. Look for Key Log Sections

Watch for these sections in the output:

#### Section 1: Initialization
```
═══════════════════════════════════════════════════════
INITIALIZING SUBSCRIPTION SERVICE
═══════════════════════════════════════════════════════
```

#### Section 2: Google Play Response (MOST IMPORTANT!)
```
═══════════════════════════════════════════════════════
GOOGLE PLAY RESPONSE: Received X purchase(s)
═══════════════════════════════════════════════════════
```

**This tells you if Google Play found your subscription!**

#### Section 3: Purchase Verification (if purchases found)
```
═══════════════════════════════════════════════════════
VERIFYING PURCHASE:
═══════════════════════════════════════════════════════
```

### 5. Save the Logs

To save logs to a file:

```cmd
adb logcat -d > subscription_logs.txt
```

Then open `subscription_logs.txt` and search for the sections above.

## Alternative: Use Android Studio

1. Open Android Studio
2. Go to **View → Tool Windows → Logcat**
3. Select your device
4. In the filter box, type: `tag:INFO`
5. Open the app on your device
6. Watch the Logcat output

## What to Look For

### ✅ Good Signs

```
✅ In-app purchases are available
✅ Registered as app lifecycle observer
GOOGLE PLAY RESPONSE: Received 1 purchase(s)
✅ VERIFIED: Premium monthly subscription
```

### ⚠️ Warning Signs

```
⚠️  No purchases returned from Google Play
⚠️  Products not found: {premium_monthly}
```

### ❌ Error Signs

```
❌ In-app purchases NOT available on this device
❌ Purchase stream error: ...
❌ FAILED: Product ID mismatch
```

## Quick Diagnosis

### If you see: "Received 0 purchase(s)"

**Meaning:** Google Play doesn't see any active subscriptions for this app + Google account combination.

**Possible reasons:**
1. Wrong Google account on device
2. App signature doesn't match (upload key issue)
3. Package name doesn't match
4. Subscription expired or cancelled

**Next step:** Check which Google account is signed in on the device and verify it's the one that purchased the subscription.

### If you see: "Received 1 purchase(s)" but status is still "none"

**Meaning:** Google Play found the subscription but something is wrong with verification or status update.

**Check:**
- Product ID in the purchase details
- Purchase status (purchased, restored, pending, error)
- Verification result (✅ or ❌)

### If you see: "Products not found: {premium_monthly}"

**Meaning:** The product ID `premium_monthly` is not configured in Google Play Console.

**Next step:** Go to Google Play Console → Monetize → Subscriptions and verify the product exists and is active.

## Full Log Collection Command

To collect comprehensive logs including timestamps:

```cmd
adb logcat -v time *:I | findstr /C:"subscription" /C:"purchase" /C:"GOOGLE PLAY" /C:"VERIFYING"
```

This shows:
- Timestamps
- Only INFO level and above
- Filters for subscription-related messages

## Sharing Logs

If you need to share logs for analysis:

1. Collect logs to file:
   ```cmd
   adb logcat -d -v time > full_logs.txt
   ```

2. Search for and extract the relevant sections:
   - INITIALIZING SUBSCRIPTION SERVICE
   - GOOGLE PLAY RESPONSE
   - VERIFYING PURCHASE
   - Any error messages

3. Share just those sections (they contain the diagnostic information)

## Privacy Note

The logs will show:
- Product IDs (safe to share)
- Purchase status (safe to share)
- First 20 characters of purchase token (safe to share)
- Platform information (safe to share)

The logs will NOT show:
- Full purchase tokens
- Payment information
- Personal information
- Google account details

## Testing Checklist

- [ ] Device connected via USB
- [ ] USB debugging enabled on device
- [ ] ADB working (`adb devices` shows your device)
- [ ] Logs cleared (`adb logcat -c`)
- [ ] Logging started (`adb logcat | findstr "INFO"`)
- [ ] App opened on device
- [ ] Logs captured and saved
- [ ] Key sections identified

## Common ADB Issues

### "adb is not recognized"

**Solution:** Add Android SDK platform-tools to PATH, or use full path:
```cmd
"C:\Users\YourUsername\AppData\Local\Android\Sdk\platform-tools\adb.exe" logcat
```

### "no devices/emulators found"

**Solution:**
1. Enable USB debugging on device (Settings → Developer Options)
2. Connect device via USB
3. Accept USB debugging prompt on device
4. Run `adb devices` to verify

### "device unauthorized"

**Solution:**
1. Disconnect device
2. Run `adb kill-server`
3. Reconnect device
4. Accept authorization prompt on device

## Next Steps

Once you have the logs:

1. Look for "GOOGLE PLAY RESPONSE: Received X purchase(s)"
2. If X = 0: Subscription not found (likely signature/account issue)
3. If X > 0: Check purchase details and verification result
4. Share the relevant log sections for further analysis

The logs will definitively show what Google Play is returning and help us identify the exact cause of the subscription restoration issue.
