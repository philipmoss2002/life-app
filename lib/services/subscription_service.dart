import 'dart:async';
import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// Enum representing subscription status
enum SubscriptionStatus {
  active,
  expired,
  gracePeriod,
  none,
}

/// Model representing a subscription plan
class SubscriptionPlan {
  final String id;
  final String title;
  final String description;
  final String price;
  final String duration;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.duration,
  });

  factory SubscriptionPlan.fromProductDetails(ProductDetails details) {
    return SubscriptionPlan(
      id: details.id,
      title: details.title,
      description: details.description,
      price: details.price,
      duration: 'Monthly', // Default, can be parsed from details
    );
  }
}

/// Model representing a purchase result
class PurchaseResult {
  final bool success;
  final String? error;
  final SubscriptionStatus status;

  PurchaseResult({
    required this.success,
    this.error,
    required this.status,
  });
}

/// Service to manage premium subscriptions and payment processing
/// Integrates with Google Play Billing and App Store
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final StreamController<SubscriptionStatus> _subscriptionController =
      StreamController<SubscriptionStatus>.broadcast();

  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  SubscriptionStatus _currentStatus = SubscriptionStatus.none;
  DateTime? _expirationDate;

  // Product IDs for different platforms
  static const String _monthlySubscriptionId = 'premium_monthly';
  static const Set<String> _productIds = {_monthlySubscriptionId};

  /// Stream of subscription status changes
  Stream<SubscriptionStatus> get subscriptionChanges =>
      _subscriptionController.stream;

  bool _isInitialized = false;

  /// Initialize the subscription service
  /// Must be called before using other methods
  Future<void> initialize() async {
    if (_isInitialized) {
      safePrint('Subscription service already initialized');
      return;
    }

    try {
      safePrint('Starting subscription service initialization...');

      // Check if in-app purchases are available
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw Exception('In-app purchases not available on this device');
      }
      safePrint('In-app purchases are available');

      // Listen to purchase updates
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          safePrint('Purchase stream closed');
          _purchaseSubscription.cancel();
        },
        onError: (error) {
          safePrint('Purchase stream error: $error');
        },
      );
      safePrint('Purchase stream listener set up');

      // Check for existing purchases and pending acknowledgments
      safePrint('Checking for existing purchases...');
      await restorePurchases();

      // Check for any pending purchases that need acknowledgment
      await _checkPendingPurchases();

      _isInitialized = true;
      safePrint('Subscription service initialization completed successfully');
    } catch (e) {
      safePrint('Failed to initialize subscription service: $e');
      rethrow;
    }
  }

  /// Check for pending purchases that need acknowledgment
  Future<void> _checkPendingPurchases() async {
    try {
      safePrint('Checking for pending purchases...');

      // Query past purchases to see if any need acknowledgment
      if (Platform.isAndroid) {
        // On Android, restore purchases will trigger the purchase stream
        // which will handle any unacknowledged purchases
        await _inAppPurchase.restorePurchases();
      }

      safePrint('Pending purchase check completed');
    } catch (e) {
      safePrint('Error checking pending purchases: $e');
    }
  }

  /// Force check for purchases (useful for debugging)
  Future<void> forceCheckPurchases() async {
    try {
      safePrint('Force checking for purchases...');

      if (!_isInitialized) {
        await initialize();
      }

      // Restore purchases to trigger any pending ones
      await restorePurchases();

      // Also manually check past purchases
      await _inAppPurchase.restorePurchases();

      safePrint('Force check completed');
    } catch (e) {
      safePrint('Error in force check: $e');
    }
  }

  /// Get available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final response = await _inAppPurchase.queryProductDetails(_productIds);

      if (response.error != null) {
        throw Exception('Failed to load products: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        safePrint('Products not found: ${response.notFoundIDs}');
      }

      return response.productDetails
          .map((details) => SubscriptionPlan.fromProductDetails(details))
          .toList();
    } catch (e) {
      safePrint('Error getting available plans: $e');
      rethrow;
    }
  }

  /// Purchase a subscription
  Future<PurchaseResult> purchaseSubscription(String planId) async {
    try {
      final response = await _inAppPurchase.queryProductDetails({planId});

      if (response.error != null) {
        return PurchaseResult(
          success: false,
          error: response.error!.message,
          status: SubscriptionStatus.none,
        );
      }

      if (response.productDetails.isEmpty) {
        return PurchaseResult(
          success: false,
          error: 'Product not found',
          status: SubscriptionStatus.none,
        );
      }

      final productDetails = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: productDetails);

      // Initiate subscription purchase (NOT buyNonConsumable)
      bool success;
      if (Platform.isAndroid) {
        // For Android subscriptions, use buyNonConsumable (it handles subscriptions)
        success =
            await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // For iOS subscriptions, use buyNonConsumable (it handles subscriptions)
        success =
            await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }

      if (!success) {
        return PurchaseResult(
          success: false,
          error: 'Failed to initiate purchase',
          status: SubscriptionStatus.none,
        );
      }

      // Purchase initiated, result will come through purchase stream
      return PurchaseResult(
        success: true,
        status: SubscriptionStatus.none,
      );
    } catch (e) {
      safePrint('Error purchasing subscription: $e');
      return PurchaseResult(
        success: false,
        error: e.toString(),
        status: SubscriptionStatus.none,
      );
    }
  }

  /// Get current subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    // Check if subscription is expired
    if (_expirationDate != null && DateTime.now().isAfter(_expirationDate!)) {
      _currentStatus = SubscriptionStatus.expired;
      _subscriptionController.add(_currentStatus);
    }

    // If status is none and service is initialized, check for existing purchases
    if (_currentStatus == SubscriptionStatus.none && _isInitialized) {
      try {
        safePrint(
            'Checking for existing purchases to update subscription status...');
        await restorePurchases();
        // Give a moment for the purchase stream to process any restored purchases
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        safePrint('Error checking existing purchases: $e');
      }
    }

    return _currentStatus;
  }

  /// Cancel subscription
  /// Note: Actual cancellation happens through platform stores
  /// This method updates local state
  Future<void> cancelSubscription() async {
    // On Android and iOS, users must cancel through their respective stores
    // This method can be used to update local state or trigger navigation
    // to the store's subscription management page

    if (Platform.isAndroid) {
      // Direct user to Google Play subscription management
      safePrint('Direct user to Google Play subscription management');
    } else if (Platform.isIOS) {
      // Direct user to App Store subscription management
      safePrint('Direct user to App Store subscription management');
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // Restored purchases will be delivered through the purchase stream
    } catch (e) {
      safePrint('Error restoring purchases: $e');
      rethrow;
    }
  }

  /// Handle purchase updates from the purchase stream
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      _processPurchase(purchaseDetails);
    }
  }

  /// Process individual purchase
  Future<void> _processPurchase(PurchaseDetails purchaseDetails) async {
    safePrint(
        'Processing purchase: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');

    if (purchaseDetails.status == PurchaseStatus.pending) {
      // Purchase is pending, show loading indicator
      safePrint('Purchase pending for ${purchaseDetails.productID}');
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      // Purchase failed
      safePrint('Purchase error: ${purchaseDetails.error}');
      _currentStatus = SubscriptionStatus.none;
      _subscriptionController.add(_currentStatus);
    } else if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      safePrint('Purchase successful for ${purchaseDetails.productID}');

      // Verify purchase with backend (or local verification for now)
      final valid = await _verifyPurchase(purchaseDetails);

      if (valid) {
        // Update subscription status FIRST
        _currentStatus = SubscriptionStatus.active;
        _updateExpirationDate(purchaseDetails);
        _subscriptionController.add(_currentStatus);

        safePrint('Subscription activated successfully');

        // CRITICAL: Acknowledge the purchase for Android
        if (Platform.isAndroid &&
            purchaseDetails is GooglePlayPurchaseDetails) {
          if (!purchaseDetails.billingClientPurchase.isAcknowledged) {
            safePrint('Acknowledging Android purchase...');
            // The acknowledgment happens automatically when we complete the purchase
          }
        }
      } else {
        _currentStatus = SubscriptionStatus.none;
        _subscriptionController.add(_currentStatus);
        safePrint('Purchase verification failed');
      }
    }

    // CRITICAL: Always complete the purchase to acknowledge it
    if (purchaseDetails.pendingCompletePurchase) {
      safePrint('Completing purchase acknowledgment...');
      try {
        await _inAppPurchase.completePurchase(purchaseDetails);
        safePrint('Purchase completed and acknowledged successfully');
      } catch (e) {
        safePrint('Error completing purchase: $e');
      }
    }
  }

  /// Verify purchase with payment provider
  /// In production, this should verify with your backend server
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      safePrint('Verifying purchase for ${purchaseDetails.productID}');

      // For now, accept all purchases that have the correct status
      // In production, you should verify with your backend server
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Platform-specific verification
        if (Platform.isAndroid) {
          final androidDetails = purchaseDetails as GooglePlayPurchaseDetails;
          safePrint(
              'Android purchase verification - Product: ${androidDetails.productID}');

          // Check if it's our subscription product
          if (androidDetails.productID == _monthlySubscriptionId) {
            safePrint('Verified: Premium monthly subscription');
            return true;
          }
        } else if (Platform.isIOS) {
          final iosDetails = purchaseDetails as AppStorePurchaseDetails;
          safePrint(
              'iOS purchase verification - Product: ${iosDetails.productID}');

          // Check if it's our subscription product
          if (iosDetails.productID == _monthlySubscriptionId) {
            safePrint('Verified: Premium monthly subscription');
            return true;
          }
        }
      }

      safePrint(
          'Purchase verification failed - Status: ${purchaseDetails.status}, Product: ${purchaseDetails.productID}');
      return false;
    } catch (e) {
      safePrint('Error verifying purchase: $e');
      return false;
    }
  }

  /// Update expiration date based on purchase details
  void _updateExpirationDate(PurchaseDetails purchaseDetails) {
    // In production, get actual expiration from backend or purchase details
    // For now, set to 30 days from purchase
    _expirationDate = DateTime.now().add(const Duration(days: 30));
  }

  /// Clear subscription state for user sign out
  void clearSubscriptionState() {
    safePrint('Clearing subscription state for user sign out');
    _currentStatus = SubscriptionStatus.none;
    _expirationDate = null;
    _subscriptionController.add(_currentStatus);
  }

  /// Reset subscription state for new user
  void resetForNewUser() {
    safePrint('Resetting subscription state for new user');
    clearSubscriptionState();
    // Note: Don't cancel purchase subscription as it's needed for new purchases
  }

  /// Dispose resources
  void dispose() {
    _purchaseSubscription.cancel();
    _subscriptionController.close();
  }
}
