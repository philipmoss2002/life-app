import 'dart:async';
import 'dart:io';
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

  /// Initialize the subscription service
  /// Must be called before using other methods
  Future<void> initialize() async {
    // Check if in-app purchases are available
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      throw Exception('In-app purchases not available');
    }

    // Listen to purchase updates
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription.cancel(),
      onError: (error) {
        // Handle error
        print('Purchase stream error: $error');
      },
    );

    // Check for existing purchases
    await restorePurchases();
  }

  /// Get available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final response = await _inAppPurchase.queryProductDetails(_productIds);

      if (response.error != null) {
        throw Exception('Failed to load products: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }

      return response.productDetails
          .map((details) => SubscriptionPlan.fromProductDetails(details))
          .toList();
    } catch (e) {
      print('Error getting available plans: $e');
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

      // Initiate purchase
      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

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
      print('Error purchasing subscription: $e');
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
      print('Direct user to Google Play subscription management');
    } else if (Platform.isIOS) {
      // Direct user to App Store subscription management
      print('Direct user to App Store subscription management');
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // Restored purchases will be delivered through the purchase stream
    } catch (e) {
      print('Error restoring purchases: $e');
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
    if (purchaseDetails.status == PurchaseStatus.pending) {
      // Purchase is pending, show loading indicator
      print('Purchase pending');
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      // Purchase failed
      print('Purchase error: ${purchaseDetails.error}');
      _currentStatus = SubscriptionStatus.none;
      _subscriptionController.add(_currentStatus);
    } else if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      // Verify purchase with backend
      final valid = await _verifyPurchase(purchaseDetails);

      if (valid) {
        _currentStatus = SubscriptionStatus.active;
        _updateExpirationDate(purchaseDetails);
        _subscriptionController.add(_currentStatus);
      } else {
        _currentStatus = SubscriptionStatus.none;
        _subscriptionController.add(_currentStatus);
      }
    }

    // Complete the purchase
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  /// Verify purchase with payment provider
  /// In production, this should verify with your backend server
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      // Platform-specific verification
      if (Platform.isAndroid) {
        // Verify with Google Play
        final androidDetails = purchaseDetails as GooglePlayPurchaseDetails;
        // In production, send androidDetails.verificationData to backend
        return androidDetails.billingClientPurchase.isAcknowledged ||
            purchaseDetails.status == PurchaseStatus.purchased;
      } else if (Platform.isIOS) {
        // Verify with App Store
        final iosDetails = purchaseDetails as AppStorePurchaseDetails;
        // In production, send iosDetails.verificationData to backend
        return iosDetails.skPaymentTransaction.transactionState ==
                SKPaymentTransactionStateWrapper.purchased ||
            iosDetails.skPaymentTransaction.transactionState ==
                SKPaymentTransactionStateWrapper.restored ||
            purchaseDetails.status == PurchaseStatus.purchased;
      }

      return false;
    } catch (e) {
      print('Error verifying purchase: $e');
      return false;
    }
  }

  /// Update expiration date based on purchase details
  void _updateExpirationDate(PurchaseDetails purchaseDetails) {
    // In production, get actual expiration from backend or purchase details
    // For now, set to 30 days from purchase
    _expirationDate = DateTime.now().add(const Duration(days: 30));
  }

  /// Dispose resources
  void dispose() {
    _purchaseSubscription.cancel();
    _subscriptionController.close();
  }
}
