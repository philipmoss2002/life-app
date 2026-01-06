import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/Document.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart';
import 'document_detail_screen.dart';

class UpcomingRenewalsScreen extends StatefulWidget {
  const UpcomingRenewalsScreen({super.key});

  @override
  State<UpcomingRenewalsScreen> createState() => _UpcomingRenewalsScreenState();
}

class _UpcomingRenewalsScreenState extends State<UpcomingRenewalsScreen> {
  List<Document> upcomingRenewals = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingRenewals();
  }

  Future<void> _loadUpcomingRenewals() async {
    setState(() => isLoading = true);

    // Get current user from auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      setState(() {
        upcomingRenewals = [];
        isLoading = false;
      });
      return;
    }

    final allDocs =
        await DatabaseService.instance.getUserDocuments(currentUser.id);
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    final upcoming = allDocs.where((doc) {
      if (doc.renewalDate == null) return false;
      final renewalDateTime = doc.renewalDate!.getDateTimeInUtc();
      return renewalDateTime.isAfter(now) &&
          renewalDateTime.isBefore(thirtyDaysFromNow);
    }).toList();

    upcoming.sort((a, b) => a.renewalDate!.compareTo(b.renewalDate!));

    setState(() {
      upcomingRenewals = upcoming;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Reminders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : upcomingRenewals.isEmpty
              ? _buildEmptyState()
              : _buildRenewalsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[400]),
          const SizedBox(height: 16),
          Text(
            'No upcoming reminders',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'All your documents are up to date!',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewalsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: upcomingRenewals.length,
      itemBuilder: (context, index) {
        final doc = upcomingRenewals[index];
        final daysUntilRenewal = doc.renewalDate!
            .getDateTimeInUtc()
            .difference(DateTime.now())
            .inDays;
        final isUrgent = daysUntilRenewal <= 7;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isUrgent ? Colors.red[50] : null,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(doc.category),
                color: Colors.white,
              ),
            ),
            title: Text(
              doc.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(doc.category),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isUrgent ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_getDatePrefix(doc.category)} Due: ${_formatDate(doc.renewalDate!.getDateTimeInUtc())}',
                      style: TextStyle(
                        color: isUrgent ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getDaysText(daysUntilRenewal),
                  style: TextStyle(
                    fontSize: 12,
                    color: isUrgent ? Colors.red[700] : Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentDetailScreen(document: doc),
                ),
              );
              _loadUpcomingRenewals();
            },
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Home Insurance':
        return Icons.home;
      case 'Car Insurance':
        return Icons.directions_car;
      case 'Mortgage':
        return Icons.account_balance;
      case 'Holiday':
        return Icons.flight_takeoff;
      default:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getDaysText(int days) {
    if (days == 0) return 'Due today!';
    if (days == 1) return 'Due tomorrow!';
    if (days <= 7) return 'Due in $days days - Urgent!';
    return 'Due in $days days';
  }

  String _getDatePrefix(String category) {
    switch (category) {
      case 'Holiday':
        return 'Payment';
      case 'Other':
        return '';
      default:
        return 'Renewal';
    }
  }
}
