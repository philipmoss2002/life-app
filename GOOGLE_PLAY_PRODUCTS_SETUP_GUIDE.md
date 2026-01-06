# Google Play Console Products Setup Guide

## Overview

This guide explains how to set up subscription products in Google Play Console so your app can find and offer them to users.

## Current App Configuration

**Product ID in Code:** `premium_monthly`  
**Location:** `lib/services/subscription_service.dart`

```dart
// Product IDs for different platforms
static const String _monthlySubscriptionId = 'premium_monthly';
static const Set<String> _productIds = {_monthlySubscriptionId};
```

## 🔧 **Step-by-Step Setup**

### Step 1: Access Google Play Console

1. **Go to:** [play.google.com/console](https://play.google.com/console)
2. **Sign in** with your developer account
3. **Select your app** (Life App / com.lifeapp.documents)

### Step 2: Navigate to Subscriptions

1. **In the left sidebar:** Click **"Monetize"**
2. **Click:** **"Products"** → **"Subscriptions"**
3. **Click:** **"Create subscription"**

### Step 3: Create the Premium Monthly Subscription

**Basic Information:**
- **Product ID:** `premium_monthly` ⚠️ **MUST MATCH CODE**
- **Name:** `Premium Monthly`
- **Description:** `Premium features including cloud sync and unlimited storage`

**Pricing:**
- **Base Plan ID:** `monthly-plan`
- **Billing Period:** `1 month`
- **Price:** Set your desired price (e.g., $4.99/month)
- **Free Trial:** Optional (e.g., 7 days free)

**Availability:**
- **Countries:** Select all countries where you want to offer the subscription
- **Start Date:** Set to current date or future launch date

### Step 4: Configure Subscription Details

**Subscription Benefits:**
```
✓ Cloud synchronization across all devices
✓ Unlimited document storage
✓ Premium customer support
✓ Advanced features and updates
✓ Automatic backup and restore
```

**Cancellation Policy:**
```
Users can cancel anytime through Google Play Store. 
Subscription remains active until the end of the current billing period.
No refunds for partial periods.
```

### Step 5: Save and Activate

1. **Click:** **"Save"**
2. **Review all details**
3. **Click:** **"Activate"** (makes it available for purchase)

## 📱 **How the Connection Works**

### 1. App Queries Google Play
```dart
// App asks Google Play: "Do you have a product called 'premium_monthly'?"
final response = await _inAppPurchase.queryProductDetails(_productIds);
```

### 2. Google Play Responds
```dart
// Google Play returns product details if found
if (response.productDetails.isNotEmpty) {
  // Product found! Show it to user
  final product = response.productDetails.first;
  // Title: "Premium Monthly"
  // Price: "$4.99/month"
  // Description: "Premium features including..."
}
```

### 3. User Makes Purchase
```dart
// When user taps "Subscribe", app tells Google Play to start purchase
final success = await _inAppPurchase.buyNonConsumable(purchaseParam: param);
```

### 4. Google Play Handles Payment
- Shows Google Play payment dialog
- Processes payment with user's payment method
- Returns success/failure to app

## 🔍 **Product ID Matching**

**✅ CORRECT Setup:**
```
Code:     'premium_monthly'
Console:  'premium_monthly'  ← MUST MATCH EXACTLY
```

**❌ INCORRECT Setup:**
```
Code:     'premium_monthly'
Console:  'premium_subscription'  ← DIFFERENT = NOT FOUND
```

## 🛠️ **Adding More Products**

If you want multiple subscription options, update the code:

```dart
// In subscription_service.dart
static const String _monthlySubscriptionId = 'premium_monthly';
static const String _yearlySubscriptionId = 'premium_yearly';
static const String _weeklySubscriptionId = 'premium_weekly';

static const Set<String> _productIds = {
  _monthlySubscriptionId,
  _yearlySubscriptionId,
  _weeklySubscriptionId,
};
```

Then create matching products in Google Play Console:
- `premium_monthly` - $4.99/month
- `premium_yearly` - $49.99/year (save 17%)
- `premium_weekly` - $1.99/week

## 🧪 **Testing Setup**

### Test Accounts
1. **Go to:** Play Console → **Setup** → **License testing**
2. **Add test Gmail accounts**
3. **These accounts can make test purchases without being charged**

### Test Products
- Products work in **Internal Testing** and **Closed Testing**
- Test purchases are **free** for test accounts
- Test purchases **expire quickly** (usually 5 minutes)

### Verification Commands
```bash
# Check if products are found
flutter run --debug
# Look for console output:
# "Products found: [premium_monthly]"
# OR
# "Products not found: [premium_monthly]"
```

## 🚨 **Common Issues & Solutions**

### Issue 1: "Product not found"
**Cause:** Product ID mismatch  
**Solution:** Ensure exact match between code and console

### Issue 2: "Products not available"
**Cause:** Product not activated in console  
**Solution:** Go to console and click "Activate"

### Issue 3: "In-app purchases not available"
**Cause:** App not uploaded to Play Console  
**Solution:** Upload signed AAB to Internal Testing first

### Issue 4: "Purchase failed"
**Cause:** Using production account on test build  
**Solution:** Use test account or upload to Play Console

### Issue 5: "Subscription not showing"
**Cause:** App package name mismatch  
**Solution:** Ensure console app matches `com.lifeapp.documents`

## 📋 **Verification Checklist**

Before testing subscriptions:

- [ ] **Product created** in Google Play Console
- [ ] **Product ID matches** code exactly: `premium_monthly`
- [ ] **Product activated** in console
- [ ] **App uploaded** to Internal Testing (minimum)
- [ ] **Test account** added to license testing
- [ ] **Signed AAB** uploaded (not debug build)
- [ ] **Package name** matches: `com.lifeapp.documents`

## 🔄 **Testing Flow**

### 1. Upload App
```bash
# Build signed AAB
flutter build appbundle --release

# Upload to Play Console → Internal Testing
```

### 2. Add Test Users
```
Play Console → Setup → License Testing → Add Gmail accounts
```

### 3. Test Purchase
```
1. Install app from Play Console link (test users)
2. Sign in to app
3. Go to Settings → Subscription
4. Tap "Premium Monthly"
5. Should show Google Play payment dialog
6. Complete test purchase (free for test accounts)
```

## 📊 **Monitoring Subscriptions**

### Play Console Analytics
- **Monetize** → **Subscriptions** → **Dashboard**
- View subscription metrics, revenue, churn rates

### App Analytics
```dart
// Track subscription events in your app
await _analyticsService.trackSubscriptionEvent(
  type: SubscriptionEventType.purchased,
  productId: 'premium_monthly',
  success: true,
);
```

## 🔐 **Security Considerations**

### Purchase Verification
```dart
// In production, verify purchases with your backend
Future<bool> _verifyPurchase(PurchaseDetails details) async {
  // Send purchase token to your server
  // Server verifies with Google Play Billing API
  // Returns true if purchase is valid
}
```

### Backend Verification (Recommended)
1. **App sends** purchase token to your server
2. **Server calls** Google Play Billing API
3. **Server verifies** purchase is legitimate
4. **Server responds** with verification result

## 📞 **Support Resources**

### Google Play Console Help
- [Subscription Setup Guide](https://support.google.com/googleplay/android-developer/answer/140504)
- [In-App Billing Testing](https://developer.android.com/google/play/billing/test)

### Flutter Documentation
- [In-App Purchase Plugin](https://pub.dev/packages/in_app_purchase)
- [Testing In-App Purchases](https://docs.flutter.dev/cookbook/plugins/in-app-purchases)

### Troubleshooting
- **Email:** support@lifeapp.com
- **Play Console Support:** Available in console help section

---

## 🎯 **Quick Summary**

**The key connection point is the Product ID:**

1. **Code defines:** `'premium_monthly'`
2. **You create in Google Play Console:** Product with ID `'premium_monthly'`
3. **App queries Google Play:** "Do you have 'premium_monthly'?"
4. **Google Play responds:** "Yes, here are the details (price, description, etc.)"
5. **App shows subscription** to user with Google Play's pricing info

**Next Steps:**
1. Upload your signed AAB to Google Play Console
2. Create the `premium_monthly` product
3. Add test accounts
4. Test the subscription flow

The app will automatically find and display your subscription once the Product ID matches! 🎉