import 'package:flutter/material.dart';
import '../models/document.dart';
import '../services/database_service.dart';
import 'add_document_screen.dart';
import 'document_detail_screen.dart';
import 'upcoming_renewals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> categories = [
    'All',
    'Home Insurance',
    'Car Insurance',
    'Mortgage',
    'Holiday',
    'Other',
  ];
  String selectedCategory = 'All';
  List<Document> documents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => isLoading = true);
    final docs = selectedCategory == 'All'
        ? await DatabaseService.instance.getAllDocuments()
        : await DatabaseService.instance
            .getDocumentsByCategory(selectedCategory);
    setState(() {
      documents = docs;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Documents'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Upcoming Renewals',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UpcomingRenewalsScreen(),
                ),
              );
              _loadDocuments();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUpcomingRenewalsBanner(),
          _buildCategoryFilter(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : documents.isEmpty
                    ? _buildEmptyState()
                    : _buildDocumentList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDocumentScreen()),
          );
          _loadDocuments();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUpcomingRenewalsBanner() {
    final upcomingCount = documents.where((doc) {
      if (doc.renewalDate == null) return false;
      final daysUntil = doc.renewalDate!.difference(DateTime.now()).inDays;
      return daysUntil >= 0 && daysUntil <= 30;
    }).length;

    if (upcomingCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UpcomingRenewalsScreen(),
          ),
        );
        _loadDocuments();
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[800], size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upcoming Renewals',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange[900],
                    ),
                  ),
                  Text(
                    '$upcomingCount ${upcomingCount == 1 ? 'document' : 'documents'} due within 30 days',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.orange[800]),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => selectedCategory = category);
                _loadDocuments();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first document',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(doc.category),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(doc.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.category),
                if (doc.renewalDate != null)
                  Text(
                    '${_getDateLabel(doc.category)}: ${_formatDate(doc.renewalDate!)}',
                    style: TextStyle(
                      color:
                          _isRenewalSoon(doc.renewalDate!) ? Colors.red : null,
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
              _loadDocuments();
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

  bool _isRenewalSoon(DateTime renewalDate) {
    final daysUntilRenewal = renewalDate.difference(DateTime.now()).inDays;
    return daysUntilRenewal <= 30 && daysUntilRenewal >= 0;
  }

  String _getDateLabel(String category) {
    switch (category) {
      case 'Holiday':
        return 'Payment Due';
      case 'Other':
        return 'Date';
      default:
        return 'Renewal';
    }
  }
}
