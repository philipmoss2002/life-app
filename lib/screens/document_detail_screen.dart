import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../models/document.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class DocumentDetailScreen extends StatefulWidget {
  final Document document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late String selectedCategory;
  DateTime? renewalDate;
  late List<String> filePaths;
  bool isEditing = false;

  final List<String> categories = [
    'Home Insurance',
    'Car Insurance',
    'Mortgage',
    'Holiday',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.document.title);
    _notesController = TextEditingController(text: widget.document.notes ?? '');
    selectedCategory = widget.document.category;
    renewalDate = widget.document.renewalDate;
    filePaths = List.from(widget.document.filePaths);
  }

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
      final updatedDocument = Document(
        id: widget.document.id,
        title: _titleController.text,
        category: selectedCategory,
        filePaths: filePaths,
        renewalDate: renewalDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: widget.document.createdAt,
      );

      await DatabaseService.instance.updateDocument(updatedDocument);

      // Update file attachments
      final db = DatabaseService.instance;
      final oldFiles = widget.document.filePaths;

      // Remove files that are no longer in the list
      for (final oldFile in oldFiles) {
        if (!filePaths.contains(oldFile)) {
          await db.removeFileFromDocument(widget.document.id!, oldFile);
        }
      }

      // Add new files
      for (final newFile in filePaths) {
        if (!oldFiles.contains(newFile)) {
          await db.addFileToDocument(widget.document.id!, newFile);
        }
      }

      // Cancel old notification and schedule new one if renewal date is set
      try {
        await NotificationService.instance.cancelReminder(widget.document.id!);
        if (renewalDate != null) {
          await NotificationService.instance.scheduleRenewalReminder(
            widget.document.id!,
            _titleController.text,
            renewalDate!,
          );
        }
      } catch (e) {
        // Notification scheduling failed, but continue
        debugPrint('Failed to update notification: $e');
      }

      setState(() => isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            ),
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteDocument,
            ),
          if (!isEditing)
            TextButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16),
              ),
            ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  isEditing = false;
                  _titleController.text = widget.document.title;
                  _notesController.text = widget.document.notes ?? '';
                  selectedCategory = widget.document.category;
                  renewalDate = widget.document.renewalDate;
                  filePaths = List.from(widget.document.filePaths);
                });
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isEditing) ...[
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (renewalDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => renewalDate = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                  ],
                ),
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
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file, size: 20),
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
                child: const Text('Save Changes'),
              ),
            ] else ...[
              _buildInfoCard('Title', widget.document.title),
              _buildInfoCard('Category', widget.document.category),
              if (widget.document.renewalDate != null)
                _buildInfoCard(
                  _getDateLabel(widget.document.category),
                  '${widget.document.renewalDate!.day}/${widget.document.renewalDate!.month}/${widget.document.renewalDate!.year}',
                ),
              if (widget.document.filePaths.isNotEmpty) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Files (${widget.document.filePaths.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.document.filePaths.map((filePath) {
                          final fileName = filePath.split('/').last;
                          return InkWell(
                            onTap: () => _openFile(filePath),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
              if (widget.document.notes != null)
                _buildInfoCard('Notes', widget.document.notes!),
              _buildInfoCard(
                'Created',
                '${widget.document.createdAt.day}/${widget.document.createdAt.month}/${widget.document.createdAt.year}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    final result = await OpenFile.open(filePath);

    if (result.type != ResultType.done && mounted) {
      String message;
      switch (result.type) {
        case ResultType.fileNotFound:
          message = 'File not found. It may have been moved or deleted.';
          break;
        case ResultType.noAppToOpen:
          message = 'No app available to open this file type.';
          break;
        case ResultType.permissionDenied:
          message = 'Permission denied to open this file.';
          break;
        case ResultType.error:
          message = 'Error opening file: ${result.message}';
          break;
        default:
          message = 'Unable to open file.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
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

  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DatabaseService.instance.deleteDocument(widget.document.id!);
      await NotificationService.instance.cancelReminder(widget.document.id!);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
