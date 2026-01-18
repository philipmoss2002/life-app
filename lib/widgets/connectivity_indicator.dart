import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Widget that displays an offline indicator when network connectivity is lost
///
/// Shows a banner at the top of the screen when offline.
/// Automatically hides when connectivity is restored.
class ConnectivityIndicator extends StatefulWidget {
  final Widget child;

  const ConnectivityIndicator({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  final _connectivityService = ConnectivityService();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivityService.isOnline;

    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.orange,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'No internet connection',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
