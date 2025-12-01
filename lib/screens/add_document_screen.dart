import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
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
  List<String> filePaths = [];

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

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        filePaths.addAll(
          result.files
              .where((file) => file.path != null)
              .map((file) => file.path!)
              .toList(),
        );
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      filePaths.removeAt(index);
    });
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
        filePaths: filePaths,
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
          filePaths: filePaths,
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

  bool _isImageFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  bool _isPdfFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return extension == 'pdf';
  }

  Widget _buildFileThumbnail(String path) {
    if (_isImageFile(path)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(path),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.image, size: 50);
          },
        ),
      );
    } else if (_isPdfFile(path)) {
      return _buildPdfThumbnail(path);
    } else {
      return Icon(
        _getFileIcon(path),
        size: 50,
        color: Theme.of(context).colorScheme.primary,
      );
    }
  }

  Widget _buildPdfThumbnail(String path) {
    return FutureBuilder<PdfDocument>(
      future: PdfDocument.openFile(path),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return FutureBuilder<PdfPage>(
            future: snapshot.data!.getPage(1),
            builder: (context, pageSnapshot) {
              if (pageSnapshot.hasData) {
                return FutureBuilder<PdfPageImage?>(
                  future: pageSnapshot.data!.render(
                    width: 50 * 3, // Higher resolution for better quality
                    height: 50 * 3,
                  ),
                  builder: (context, imageSnapshot) {
                    if (imageSnapshot.hasData && imageSnapshot.data != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          imageSnapshot.data!.bytes,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                    return const SizedBox(
                      width: 50,
                      height: 50,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox(
                width: 50,
                height: 50,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          );
        }
        if (snapshot.hasError) {
          return Icon(
            Icons.picture_as_pdf,
            size: 50,
            color: Theme.of(context).colorScheme.primary,
          );
        }
        return const SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String path) {
    final extension = path.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
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
              title: const Text('Attach Files'),
              subtitle: Text(
                filePaths.isEmpty
                    ? 'No files selected'
                    : '${filePaths.length} file(s) attached',
              ),
              trailing: const Icon(Icons.attach_file),
              onTap: _pickFiles,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            if (filePaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...filePaths.asMap().entries.map((entry) {
                final index = entry.key;
                final path = entry.value;
                final fileName = path.split('/').last;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: _buildFileThumbnail(path),
                    title: Text(
                      fileName,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => _removeFile(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                );
              }),
            ],
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
