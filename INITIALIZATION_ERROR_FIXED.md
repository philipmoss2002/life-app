# Initialization Error Fixed

## Problem

The subscription service was throwing a `LateInitializationError` when trying to restore purchases:

```
[ERROR] Error restoring purchases (attempt 1/3): LateInitializationError: 
Field '_purchaseSubscription@1391248778' has not been initialized.
```

## Root Cause

The `_purchaseSubscription` field was declared as `late` but `restorePurchases()` was being called **before** `initialize()` was called. This happened because:

1. The field was declared as `late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription`
2. `restorePurchases()` tried to check `_purchaseSubscription.isPaused`
3. But `_purchaseSubscription` wasn't initialized yet because `initialize()` hadn't been called

## The Fix

### 1. Added Initialization Tracking Flag

```dart
bool _purchaseStreamInitialized = false;
```

This tracks whether the purchase stream has been set up.

### 2. Set Flag When Stream is Initialized

```dart
_purchaseSubscription = _inAppPurchase.purchaseStream.listen(...);
_purchaseStreamInitialized = true;  // <-- Added this
```

### 3. Check Flag Before Accessing Stream

```dart
// Check if purchase stream listener is initialized
if (!_purchaseStreamInitialized) {
  _logService.log(
    '❌ ERROR: Purchase stream not initialized! Call initialize() first.',
    level: log_svc.LogLevel.error,
  );
  throw Exception('Purchase stream not initialized. Call initialize() first.');
}

// Now safe to check if paused
if (_purchaseSubscription.isPaused) {
  ...
}
```

### 4. Updated Dispose Method

```dart
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  if (_purchaseStreamInitialized) {  // <-- Check before cancelling
    _purchaseSubscription.cancel();
    _purchaseStreamInitialized = false;
  }
  _subscriptionController.close();
}
```

## What You'll See Now

### If initialize() Not Called:

```
[INFO] Starting purchase restoration (attempt 1/3)
[INFO] Calling InAppPurchase.restorePurchases()...
[ERROR] ❌ ERROR: Purchase stream not initialized! Call initialize() first.
[ERROR] Error restoring purchases (attempt 1/3): Exception: Purchase stream not initialized. Call initialize() first.
```

This gives a clear error message instead of a cryptic `LateInitializationError`.

### If initialize() Was Called:

```
[INFO] ═══ INITIALIZING SUBSCRIPTION SERVICE ═══
[INFO] Platform: Android (Google Play)
[INFO] ✅ In-app purchases are available
[INFO] Purchase stream listener set up - waiting for purchase events
[INFO] Checking for existing purchases...
[INFO] Starting purchase restoration (attempt 1/3)
[INFO] Calling InAppPurchase.restorePurchases()...
[INFO] InAppPurchase.restorePurchases() completed
[INFO] Waiting 3 seconds for purchase stream to fire...
[INFO] 🔔 _handlePurchaseUpdates() CALLED - Purchase stream fired!
[INFO] ═══ GOOGLE PLAY RESPONSE: Received X purchase(s) ═══
```

## Why This Happened

Looking at your logs, `restorePurchases()` was called **twice** before initialization:

```
[21:15:15] [INFO] AUDIT: purchase_restoration | Action: restore_purchases | Time: 2026-01-29T21:15:15.284797 | Outcome: started
[21:15:18] [INFO] AUDIT: purchase_restoration | Action: restore_purchases | Time: 2026-01-29T21:15:18.287791 | Outcome: started
```

But there's no initialization log before these. This means something in your app is calling `restorePurchases()` before calling `initialize()`.

## Where to Check

Look for code that calls `SubscriptionService().restorePurchases()` without first calling `SubscriptionService().initialize()`.

Common places:
1. App startup code
2. Sync service initialization
3. Subscription status screen
4. Settings screen

## Correct Usage

```dart
// CORRECT: Initialize first
final subscriptionService = SubscriptionService();
await subscriptionService.initialize();  // <-- Must call this first
await subscriptionService.restorePurchases();  // <-- Then this is safe

// INCORRECT: Restore without initializing
final subscriptionService = SubscriptionService();
await subscriptionService.restorePurchases();  // <-- ERROR! Not initialized
```

## Next Steps

1. **Build and install the updated app**
2. **Check the logs** - you should now see:
   - Either: "═══ INITIALIZING SUBSCRIPTION SERVICE ═══" at the start
   - Or: "❌ ERROR: Purchase stream not initialized!" if something calls restore before init

3. **If you see the initialization error:**
   - Find where `restorePurchases()` is being called
   - Make sure `initialize()` is called first
   - Share the code location so we can fix it

4. **If initialization succeeds:**
   - Look for "🔔 _handlePurchaseUpdates() CALLED"
   - This will tell us if the purchase stream is firing

## Expected Flow

```
App Startup
    ↓
SubscriptionService().initialize()
    ↓
[INFO] ═══ INITIALIZING SUBSCRIPTION SERVICE ═══
[INFO] ✅ In-app purchases are available
[INFO] Purchase stream listener set up
    ↓
[INFO] Checking for existing purchases...
    ↓
restorePurchases()
    ↓
[INFO] Calling InAppPurchase.restorePurchases()...
[INFO] Waiting 3 seconds for purchase stream to fire...
    ↓
[INFO] 🔔 _handlePurchaseUpdates() CALLED
[INFO] ═══ GOOGLE PLAY RESPONSE: Received X purchase(s) ═══
```

## Summary

- ✅ Fixed `LateInitializationError` by adding initialization tracking
- ✅ Added clear error message if `restorePurchases()` called before `initialize()`
- ✅ Protected `dispose()` from accessing uninitialized stream
- ✅ Added diagnostic logging to track initialization state

The error is now fixed, and you'll get clear feedback about what's happening!
