import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'log_service.dart' as log_svc;

/// Service for monitoring network connectivity
///
/// Provides connectivity status and notifies listeners when connectivity changes.
/// Integrates with SyncService to trigger sync when connectivity is restored.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _logService = log_svc.LogService();
  final _connectivityController = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  /// Stream of connectivity status (true = online, false = offline)
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Check if device is currently online
  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_isInitialized) {
      _logService.log(
        'Connectivity service already initialized',
        level: log_svc.LogLevel.warning,
      );
      return;
    }

    _logService.log(
      'Initializing connectivity service',
      level: log_svc.LogLevel.info,
    );

    // Check initial connectivity
    await _checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    _isInitialized = true;

    _logService.log(
      'Connectivity service initialized, initial status: ${_isOnline ? "online" : "offline"}',
      level: log_svc.LogLevel.info,
    );
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      _logService.log(
        'Failed to check connectivity: $e',
        level: log_svc.LogLevel.error,
      );
      // Assume online if check fails
      _isOnline = true;
    }
  }

  /// Handle connectivity change
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // Consider device online if any connection type is available
    // (mobile, wifi, ethernet, etc.)
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    _logService.log(
      'Connectivity changed: ${_isOnline ? "online" : "offline"} (${results.map((r) => r.name).join(", ")})',
      level: log_svc.LogLevel.info,
    );

    // Notify listeners
    _connectivityController.add(_isOnline);

    // Log connectivity restoration
    if (!wasOnline && _isOnline) {
      _logService.log(
        'Network connectivity restored',
        level: log_svc.LogLevel.info,
      );
    }

    // Log connectivity loss
    if (wasOnline && !_isOnline) {
      _logService.log(
        'Network connectivity lost',
        level: log_svc.LogLevel.warning,
      );
    }
  }

  /// Manually check connectivity (useful for testing or manual refresh)
  Future<bool> checkConnectivity() async {
    await _checkConnectivity();
    return _isOnline;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    _isInitialized = false;

    _logService.log(
      'Connectivity service disposed',
      level: log_svc.LogLevel.info,
    );
  }
}
