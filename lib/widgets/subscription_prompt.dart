import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_plans_screen.dart';

/// Widget that displays subscription prompts and warnings
/// Can be used throughout the app to prompt users to upgrade
class SubscriptionPrompt {
  /// Show upgrade prompt when accessing cloud sync features
  static Future<bool?> showUpgradePrompt(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Premium Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cloud sync is a premium feature that allows you to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(Icons.cloud_sync, 'Sync across all devices'),
            _buildFeatureItem(Icons.backup, 'Automatic cloud backup'),
            _buildFeatureItem(Icons.security, 'Encrypted storage'),
            _buildFeatureItem(Icons.offline_bolt, 'Offline access'),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to premium to unlock these features.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  /// Show expiration warning dialog
  static Future<bool?> showExpirationWarning(
    BuildContext context,
    DateTime expirationDate,
  ) async {
    final daysRemaining = expirationDate.difference(DateTime.now()).inDays;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Colors.orange[700],
            ),
            const SizedBox(width: 8),
            const Text('Subscription Expiring'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your premium subscription will expire in $daysRemaining ${daysRemaining == 1 ? "day" : "days"}.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'After expiration, you will lose access to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem(Icons.cloud_off, 'Cloud synchronization'),
            _buildFeatureItem(Icons.devices, 'Multi-device access'),
            _buildFeatureItem(Icons.backup, 'Automatic backups'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Renew Now'),
          ),
        ],
      ),
    );
  }

  /// Show subscription expired dialog
  static Future<bool?> showExpiredDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[700],
            ),
            const SizedBox(width: 8),
            const Text('Subscription Expired'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your premium subscription has expired.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Cloud sync has been disabled. Your documents remain safe on this device, but will no longer sync to the cloud.',
            ),
            SizedBox(height: 16),
            Text(
              'Renew your subscription to restore cloud sync features.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Renew Subscription'),
          ),
        ],
      ),
    );
  }

  /// Show a banner for subscription status
  static Widget buildSubscriptionBanner(
    BuildContext context,
    SubscriptionStatus status,
    VoidCallback onTap,
  ) {
    if (status == SubscriptionStatus.active) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    Color textColor;
    IconData icon;
    String message;

    switch (status) {
      case SubscriptionStatus.gracePeriod:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        icon = Icons.warning_amber;
        message = 'Subscription in grace period - Update payment method';
        break;
      case SubscriptionStatus.expired:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        icon = Icons.error_outline;
        message = 'Subscription expired - Renew to restore cloud sync';
        break;
      case SubscriptionStatus.none:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        icon = Icons.cloud_off;
        message = 'Upgrade to premium for cloud sync';
        break;
      case SubscriptionStatus.active:
        return const SizedBox.shrink();
    }

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: textColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  /// Navigate to subscription plans screen
  static Future<bool?> navigateToPlans(BuildContext context) async {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionPlansScreen(),
      ),
    );
  }
}

/// Mixin to handle subscription state changes
/// Can be used by screens that need to respond to subscription changes
mixin SubscriptionStateMixin<T extends StatefulWidget> on State<T> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.none;

  SubscriptionStatus get subscriptionStatus => _subscriptionStatus;

  @override
  void initState() {
    super.initState();
    _initializeSubscription();
  }

  Future<void> _initializeSubscription() async {
    try {
      final status = await _subscriptionService.getSubscriptionStatus();
      if (mounted) {
        setState(() {
          _subscriptionStatus = status;
        });
      }

      // Listen to subscription changes
      _subscriptionService.subscriptionChanges.listen((status) {
        if (mounted) {
          setState(() {
            _subscriptionStatus = status;
          });
          onSubscriptionChanged(status);
        }
      });
    } catch (e) {
      // Handle error
      debugPrint('Error initializing subscription: $e');
    }
  }

  /// Override this method to handle subscription status changes
  void onSubscriptionChanged(SubscriptionStatus status) {
    // Check if we need to show warnings
    if (status == SubscriptionStatus.expired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showExpiredWarning();
        }
      });
    }
  }

  Future<void> _showExpiredWarning() async {
    final result = await SubscriptionPrompt.showExpiredDialog(context);
    if (result == true && mounted) {
      await SubscriptionPrompt.navigateToPlans(context);
    }
  }

  /// Check if user has active subscription
  bool get hasActiveSubscription =>
      _subscriptionStatus == SubscriptionStatus.active ||
      _subscriptionStatus == SubscriptionStatus.gracePeriod;

  /// Prompt user to upgrade if they don't have active subscription
  Future<bool> promptUpgradeIfNeeded() async {
    if (hasActiveSubscription) {
      return true;
    }

    final result = await SubscriptionPrompt.showUpgradePrompt(context);
    if (result == true && mounted) {
      final upgraded = await SubscriptionPrompt.navigateToPlans(context);
      return upgraded == true;
    }

    return false;
  }
}
