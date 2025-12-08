import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import '../models/document.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/storage_manager.dart';
import '../services/authentication_service.dart';
import 'document_detail_screen.dart';
import 'subscription_plans_screen.dart';

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final StorageManager _storageManager = StorageManager();
  final AuthenticationService _authService = AuthenticationService();

  String selectedCategory = 'Home Insurance';
  DateTime? renewalDate;
  List<String> filePaths = [];
  Map<String, String?> fileLabels = {}; // Map of filePath -> label

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
    // Check if user is authenticated for cloud storage
    final user = await _authService.getCurrentUser();
    if (user != null) {
      // Check storage quota before allowing file selection
      final storageInfo = await _storageManager.getStorageInfo();

      if (storageInfo.isOverLimit) {
        if (mounted) {
          _showStorageLimitDialog(storageInfo);
        }
        return;
      }

      if (storageInfo.isNearLimit) {
        if (mounted) {
          final proceed = await _showStorageWarningDialog(storageInfo);
          if (proceed != true) {
            return;
          }
        }
      }
    }

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      // Calculate total size of selected files
      int totalSize = 0;
      final validFiles = <String>[];

      for (final file in result.files) {
        if (file.path != null) {
          final fileSize = File(file.path!).lengthSync();
          totalSize += fileSize;
          validFiles.add(file.path!);
        }
      }

      // Check if adding these files would exceed storage
      if (user != null) {
        final hasSpace = await _storageManager.hasAvailableSpace(totalSize);
        if (!hasSpace && mounted) {
          _showStorageLimitDialog(await _storageManager.getStorageInfo());
          return;
        }
      }

      setState(() {
        filePaths.addAll(validFiles);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      final path = filePaths[index];
      filePaths.removeAt(index);
      fileLabels.remove(path);
    });
  }

  Future<void> _editFileLabel(String filePath, String fileName) async {
    final currentLabel = fileLabels[filePath];
    final controller = TextEditingController(text: currentLabel ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit File Label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File: $fileName',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'Enter a meaningful name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (currentLabel != null)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Remove Label'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Dispose controller after dialog is fully closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (result != null) {
      setState(() {
        if (result.isEmpty) {
          fileLabels.remove(filePath);
        } else {
          fileLabels[filePath] = result;
        }
      });
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
      // Check storage before saving if user is authenticated
      final user = await _authService.getCurrentUser();
      if (user != null && filePaths.isNotEmpty) {
        final storageInfo = await _storageManager.getStorageInfo();

        if (storageInfo.isOverLimit) {
          if (mounted) {
            _showStorageLimitDialog(storageInfo);
          }
          return;
        }
      }

      final document = Document(
        title: _titleController.text,
        category: selectedCategory,
        filePaths: filePaths,
        renewalDate: renewalDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      final id = await DatabaseService.instance.createDocumentWithLabels(
        document,
        fileLabels,
      );

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

  void _showStorageLimitDialog(StorageInfo storageInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Storage Limit Exceeded'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have used ${storageInfo.usagePercentage.toStringAsFixed(1)}% of your storage quota.',
            ),
            const SizedBox(height: 8),
            Text(
              'Used: ${storageInfo.usedBytesFormatted} / ${storageInfo.quotaBytesFormatted}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'You cannot upload new files until you free up space or upgrade your storage plan.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPlansScreen(),
                ),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showStorageWarningDialog(StorageInfo storageInfo) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Approaching Storage Limit'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have used ${storageInfo.usagePercentage.toStringAsFixed(1)}% of your storage quota.',
            ),
            const SizedBox(height: 8),
            Text(
              'Used: ${storageInfo.usedBytesFormatted} / ${storageInfo.quotaBytesFormatted}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Consider upgrading your storage plan or removing unused files.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPlansScreen(),
                ),
              );
            },
            child: const Text('Upgrade'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
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
                final label = fileLabels[path];
                final displayName = label ?? fileName;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: _buildFileThumbnail(path),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (label != null)
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    subtitle: label == null
                        ? TextButton.icon(
                            icon: const Icon(Icons.label_outline, size: 16),
                            label: const Text('Add label'),
                            onPressed: () => _editFileLabel(path, fileName),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                          )
                        : TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit label'),
                            onPressed: () => _editFileLabel(path, fileName),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
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
