import 'package:flutter/material.dart';
import 'dart:io';
import '../services/subscription_service.dart';

/// Screen displaying current subscription status
/// Shows expiration date and provides options to manage subscription
class SubscriptionStatusScreen extends StatefulWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  State<SubscriptionStatusScreen> createState() =>
      _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  SubscriptionStatus _status = SubscriptionStatus.none;
  bool _isLoading = true;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _subscriptionService.getSubscriptionStatus();
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load subscription status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Text(
          Platform.isAndroid
              ? 'To cancel your subscription, you need to manage it through Google Play Store. Would you like to be directed there?'
              : 'To cancel your subscription, you need to manage it through the App Store. Would you like to be directed there?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go to Store'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _subscriptionService.cancelSubscription();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Platform.isAndroid
                    ? 'Opening Google Play Store...'
                    : 'Opening App Store...',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() {
      _isRestoring = true;
    });

    try {
      await _subscriptionService.restorePurchases();
      // Wait a moment for the purchase stream to process
      await Future.delayed(const Duration(seconds: 2));
      await _loadSubscriptionStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 24),
          _buildSubscriptionDetails(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusInfo = _getStatusInfo();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: statusInfo.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusInfo.gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            statusInfo.icon,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            statusInfo.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusInfo.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          if (statusInfo.expirationText != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusInfo.expirationText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_status == SubscriptionStatus.active ||
              _status == SubscriptionStatus.gracePeriod) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleCancelSubscription,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Manage Subscription'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRestoring ? null : _handleRestorePurchases,
              icon: _isRestoring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore),
              label: const Text('Restore Purchases'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            icon: Icons.info_outline,
            title: 'Status',
            value: _getStatusText(),
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.calendar_today,
            title: 'Expiration Date',
            value: _getExpirationDateText(),
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.payment,
            title: 'Billing',
            value: _getBillingText(),
          ),
          const SizedBox(height: 24),
          _buildInfoBox(),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your subscription will automatically renew unless cancelled. '
              'You can manage or cancel your subscription at any time through '
              '${Platform.isAndroid ? "Google Play Store" : "the App Store"}.',
              style: TextStyle(
                color: Colors.blue[900],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo() {
    switch (_status) {
      case SubscriptionStatus.active:
        return _StatusInfo(
          icon: Icons.check_circle,
          title: 'Active',
          subtitle: 'Your premium subscription is active',
          gradientColors: [Colors.green[600]!, Colors.green[400]!],
          expirationText: 'Renews ${_getExpirationDateText()}',
        );
      case SubscriptionStatus.gracePeriod:
        return _StatusInfo(
          icon: Icons.warning,
          title: 'Grace Period',
          subtitle: 'Please update your payment method',
          gradientColors: [Colors.orange[600]!, Colors.orange[400]!],
          expirationText: 'Expires ${_getExpirationDateText()}',
        );
      case SubscriptionStatus.expired:
        return _StatusInfo(
          icon: Icons.error_outline,
          title: 'Expired',
          subtitle: 'Your subscription has expired',
          gradientColors: [Colors.red[600]!, Colors.red[400]!],
          expirationText: 'Expired ${_getExpirationDateText()}',
        );
      case SubscriptionStatus.none:
        return _StatusInfo(
          icon: Icons.cloud_off,
          title: 'No Subscription',
          subtitle: 'Subscribe to unlock premium features',
          gradientColors: [Colors.grey[600]!, Colors.grey[400]!],
        );
    }
  }

  String _getStatusText() {
    switch (_status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.gracePeriod:
        return 'Grace Period';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.none:
        return 'No Active Subscription';
    }
  }

  String _getExpirationDateText() {
    // In production, this would come from the subscription service
    // For now, return a placeholder
    if (_status == SubscriptionStatus.none) {
      return 'N/A';
    }
    // This should be retrieved from the subscription service
    final expirationDate = DateTime.now().add(const Duration(days: 30));
    return '${expirationDate.month}/${expirationDate.day}/${expirationDate.year}';
  }

  String _getBillingText() {
    if (_status == SubscriptionStatus.none) {
      return 'No active billing';
    }
    return 'Monthly - Auto-renewing';
  }
}

class _StatusInfo {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final String? expirationText;

  _StatusInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    this.expirationText,
  });
}
