import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/Document.dart';
import '../models/sync_state.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/conflict_resolution_service.dart';
import 'conflict_resolution_screen.dart';

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
  late Map<String, String?> fileLabels; // Map of filePath -> label
  bool isEditing = false;
  late Document currentDocument;

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
    currentDocument = widget.document;
    _titleController = TextEditingController(text: currentDocument.title);
    _notesController = TextEditingController(text: currentDocument.notes ?? '');
    selectedCategory = currentDocument.category;
    renewalDate = currentDocument.renewalDate?.getDateTimeInUtc();
    filePaths = List.from(currentDocument.filePaths);
    fileLabels = {};
    _loadFileLabels();
  }

  Future<void> _loadFileLabels() async {
    if (currentDocument.id != null) {
      final attachments = await DatabaseService.instance
          .getFileAttachmentsWithLabels(int.parse(currentDocument.id));
      setState(() {
        fileLabels = {
          for (var attachment in attachments)
            attachment.filePath: attachment.label
        };
      });
    }
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

      // Update in database if document is saved
      if (currentDocument.id != null) {
        try {
          final rowsAffected = await DatabaseService.instance.updateFileLabel(
            int.parse(currentDocument.id),
            filePath,
            result.isEmpty ? null : result,
          );

          if (rowsAffected == 0 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning: Label may not have been saved'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Label saved successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error updating label: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save label: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
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
      final updatedDocument = Document(
        id: widget.document.id,
        userId: widget.document.userId,
        title: _titleController.text,
        category: selectedCategory,
        filePaths: filePaths,
        renewalDate: renewalDate != null
            ? amplify_core.TemporalDateTime(renewalDate!)
            : null,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: widget.document.createdAt,
        lastModified: amplify_core.TemporalDateTime.now(),
        version: widget.document.version + 1,
        syncState: widget.document.syncState,
      );

      await DatabaseService.instance.updateDocument(updatedDocument);

      // Update file attachments
      final db = DatabaseService.instance;
      final oldFiles = currentDocument.filePaths;

      // Remove files that are no longer in the list
      for (final oldFile in oldFiles) {
        if (!filePaths.contains(oldFile)) {
          await db.removeFileFromDocument(
              int.parse(currentDocument.id), oldFile);
        }
      }

      // Add new files and update labels for all files
      for (final newFile in filePaths) {
        if (!oldFiles.contains(newFile)) {
          // Add new file with label
          await db.addFileToDocument(
              int.parse(currentDocument.id), newFile, fileLabels[newFile]);
        } else {
          // Update label for existing file
          await db.updateFileLabel(
              int.parse(currentDocument.id), newFile, fileLabels[newFile]);
        }
      }

      // Cancel old notification and schedule new one if renewal date is set
      try {
        await NotificationService.instance
            .cancelReminder(int.parse(currentDocument.id));
        if (renewalDate != null) {
          await NotificationService.instance.scheduleRenewalReminder(
            int.parse(currentDocument.id),
            _titleController.text,
            renewalDate!,
          );
        }
      } catch (e) {
        // Notification scheduling failed, but continue
        debugPrint('Failed to update notification: $e');
      }

      setState(() {
        currentDocument = updatedDocument;
        isEditing = false;
      });

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
                  _titleController.text = currentDocument.title;
                  _notesController.text = currentDocument.notes ?? '';
                  selectedCategory = currentDocument.category;
                  renewalDate = currentDocument.renewalDate?.getDateTimeInUtc();
                  filePaths = List.from(currentDocument.filePaths);
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
            // Conflict resolution banner
            if (currentDocument.syncState == SyncState.conflict.toJson())
              _buildConflictBanner(),
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
                child: const Text('Save Changes'),
              ),
            ] else ...[
              _buildInfoCard('Title', currentDocument.title),
              _buildInfoCard('Category', currentDocument.category),
              if (currentDocument.renewalDate != null)
                _buildInfoCard(
                  _getDateLabel(currentDocument.category),
                  _formatDate(currentDocument.renewalDate!.getDateTimeInUtc()),
                ),
              if (currentDocument.filePaths.isNotEmpty) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Files (${currentDocument.filePaths.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...currentDocument.filePaths.map((filePath) {
                          final fileName = filePath.split('/').last;
                          final label = fileLabels[filePath];
                          final displayName = label ?? fileName;
                          return InkWell(
                            onTap: () => _openFile(filePath),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  _buildFileThumbnail(filePath),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                        if (label != null)
                                          Text(
                                            fileName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
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
              if (currentDocument.notes != null)
                _buildInfoCard('Notes', currentDocument.notes!),
              _buildInfoCard(
                'Created',
                _formatDate(currentDocument.createdAt.getDateTimeInUtc()),
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

  Widget _buildConflictBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red[800], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sync Conflict Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This document was modified on multiple devices. You need to resolve the conflict before making further changes.',
            style: TextStyle(color: Colors.red[800], fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleConflictResolution,
              icon: const Icon(Icons.build),
              label: const Text('Resolve Conflict'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConflictResolution() async {
    // Get the conflict for this document
    final conflictService = ConflictResolutionService();
    final conflicts = await conflictService.getActiveConflicts();

    final conflict = conflicts.firstWhere(
      (c) => c.documentId == currentDocument.id.toString(),
      orElse: () {
        // If no conflict found in service, create a mock one for UI purposes
        // In real scenario, this should be fetched from the sync service
        return DocumentConflict(
          id: 'temp_${currentDocument.id}',
          documentId: currentDocument.id.toString(),
          localDocument: currentDocument,
          remoteDocument: currentDocument, // This should come from remote
          type: ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );
      },
    );

    final result = await Navigator.push<Document>(
      context,
      MaterialPageRoute(
        builder: (context) => ConflictResolutionScreen(conflict: conflict),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        currentDocument = result;
        _titleController.text = result.title;
        _notesController.text = result.notes ?? '';
        selectedCategory = result.category;
        renewalDate = result.renewalDate?.getDateTimeInUtc();
        filePaths = List.from(result.filePaths);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflict resolved successfully'),
          backgroundColor: Colors.green,
        ),
      );
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
      await DatabaseService.instance
          .deleteDocument(int.parse(currentDocument.id));
      await NotificationService.instance
          .cancelReminder(int.parse(currentDocument.id));
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
