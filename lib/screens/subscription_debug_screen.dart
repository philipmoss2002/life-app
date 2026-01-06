import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/subscription_service.dart';

class SubscriptionDebugScreen extends StatefulWidget {
  const SubscriptionDebugScreen({super.key});

  @override
  State<SubscriptionDebugScreen> createState() =>
      _SubscriptionDebugScreenState();
}

class _SubscriptionDebugScreenState extends State<SubscriptionDebugScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final List<String> _debugLogs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addLog('Debug screen initialized');
  }

  void _addLog(String message) {
    setState(() {
      _debugLogs.add('${DateTime.now().toLocal()}: $message');
    });
    debugPrint('SUBSCRIPTION DEBUG: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _debugLogs.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _initializeService,
                        child: const Text('Initialize Service'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _checkProducts,
                        child: const Text('Check Products'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _restorePurchases,
                        child: const Text('Restore Purchases'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _forceCheck,
                        child: const Text('Force Check'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _checkStatus,
                    child: const Text('Check Current Status'),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Debug logs
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _debugLogs.length,
              itemBuilder: (context, index) {
                final log = _debugLogs[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      log,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeService() async {
    setState(() => _isLoading = true);
    _addLog('Initializing subscription service...');

    try {
      await _subscriptionService.initialize();
      _addLog('✅ Subscription service initialized successfully');
    } catch (e) {
      _addLog('❌ Failed to initialize: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _checkProducts() async {
    setState(() => _isLoading = true);
    _addLog('Checking available products...');

    try {
      final plans = await _subscriptionService.getAvailablePlans();
      _addLog('✅ Found ${plans.length} products:');
      for (final plan in plans) {
        _addLog('  - ${plan.id}: ${plan.title} (${plan.price})');
      }
    } catch (e) {
      _addLog('❌ Failed to get products: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    _addLog('Restoring purchases...');

    try {
      await _subscriptionService.restorePurchases();
      _addLog('✅ Restore purchases completed');

      // Wait for purchase stream to process
      await Future.delayed(const Duration(seconds: 3));

      final status = await _subscriptionService.getSubscriptionStatus();
      _addLog('Current status after restore: ${status.name}');
    } catch (e) {
      _addLog('❌ Failed to restore purchases: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _forceCheck() async {
    setState(() => _isLoading = true);
    _addLog('Force checking purchases...');

    try {
      await _subscriptionService.forceCheckPurchases();
      _addLog('✅ Force check completed');

      // Wait for processing
      await Future.delayed(const Duration(seconds: 3));

      final status = await _subscriptionService.getSubscriptionStatus();
      _addLog('Current status after force check: ${status.name}');
    } catch (e) {
      _addLog('❌ Failed force check: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    _addLog('Checking current subscription status...');

    try {
      final status = await _subscriptionService.getSubscriptionStatus();
      _addLog('✅ Current status: ${status.name}');

      // Also check if in-app purchase is available
      final available = await InAppPurchase.instance.isAvailable();
      _addLog('In-app purchase available: $available');
    } catch (e) {
      _addLog('❌ Failed to check status: $e');
    }

    setState(() => _isLoading = false);
  }
}
