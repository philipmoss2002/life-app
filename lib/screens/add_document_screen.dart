import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'document_detail_screen.dart';

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  String selectedCategory = 'Home Insurance';
  DateTime? renewalDate;
  String? filePath;

  final List<String> categories = [
    'Home Insurance',
    'Car Insurance',
    'Mortgage',
    'Holiday',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => filePath = result.files.single.path);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: renewalDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => renewalDate = picked);
    }
  }

  Future<void> _saveDocument() async {
    if (_formKey.currentState!.validate()) {
      final document = Document(
        title: _titleController.text,
        category: selectedCategory,
        filePath: filePath,
        renewalDate: renewalDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      final id = await DatabaseService.instance.createDocument(document);

      // Schedule notification if renewal date is set
      if (renewalDate != null) {
        try {
          await NotificationService.instance.scheduleRenewalReminder(
            id,
            _titleController.text,
            renewalDate!,
          );
        } catch (e) {
          // Notification scheduling failed, but continue with navigation
          debugPrint('Failed to schedule notification: $e');
        }
      }

      if (mounted) {
        // Create the saved document with the ID
        final savedDocument = Document(
          id: id,
          title: _titleController.text,
          category: selectedCategory,
          filePath: filePath,
          renewalDate: renewalDate,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );

        // Replace the add screen with the detail screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(document: savedDocument),
          ),
        );
      }
    }
  }

  String _getDateLabel(String category) {
    switch (category) {
      case 'Holiday':
        return 'Payment Due';
      case 'Other':
        return 'Date';
      default:
        return 'Renewal Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Document'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedCategory = value!);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(_getDateLabel(selectedCategory)),
              subtitle: Text(
                renewalDate != null
                    ? '${renewalDate!.day}/${renewalDate!.month}/${renewalDate!.year}'
                    : 'Not set',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Attach File'),
              subtitle: Text(
                filePath != null
                    ? filePath!.split('/').last
                    : 'No file selected',
              ),
              trailing: const Icon(Icons.attach_file),
              onTap: _pickFile,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveDocument,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Document'),
            ),
          ],
        ),
      ),
    );
  }
}
