import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/new_document.dart';
import '../models/file_attachment.dart';
import '../models/sync_state.dart';
import '../repositories/document_repository.dart';
import '../services/sync_service.dart';
import '../services/authentication_service.dart';
import '../services/file_service.dart';
import '../services/document_sync_service.dart';
import '../services/file_attachment_sync_service.dart';
import '../services/log_service.dart' as log_svc;
import '../services/subscription_status_notifier.dart';
import '../services/subscription_service.dart';
import '../widgets/file_thumbnail_widget.dart';

/// Document detail screen for viewing and editing documents
class NewDocumentDetailScreen extends StatefulWidget {
  final Document? document; // null for creating new document

  const NewDocumentDetailScreen({super.key, this.document});

  @override
  State<NewDocumentDetailScreen> createState() =>
      _NewDocumentDetailScreenState();
}

class _NewDocumentDetailScreenState extends State<NewDocumentDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentRepository = DocumentRepository();
  final _syncService = SyncService();
  final _authService = AuthenticationService();
  final _fileService = FileService();
  final _documentSyncService = DocumentSyncService();
  final _fileAttachmentSyncService = FileAttachmentSyncService();
  final _logService = log_svc.LogService();
  late final SubscriptionStatusNotifier _subscriptionNotifier;

  late TextEditingController _titleController;
  late DocumentCategory _selectedCategory;
  DateTime? _selectedDate;
  late List<FileAttachment> _files;
  late TextEditingController _notesController;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _subscriptionNotifier = SubscriptionStatusNotifier(SubscriptionService());
    _initializeSubscriptionNotifier();
    _isEditing = widget.document == null; // Edit mode if creating new
    _titleController =
        TextEditingController(text: widget.document?.title ?? '');
    _selectedCategory = widget.document?.category ?? DocumentCategory.other;
    _selectedDate = widget.document?.date;
    _files = List.from(widget.document?.files ?? []);
    _notesController =
        TextEditingController(text: widget.document?.notes ?? '');
  }

  Future<void> _initializeSubscriptionNotifier() async {
    try {
      await _subscriptionNotifier.initialize();
      _subscriptionNotifier.addListener(_onSubscriptionStatusChanged);
    } catch (e) {
      debugPrint('Failed to initialize subscription notifier: $e');
    }
  }

  void _onSubscriptionStatusChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when subscription status changes
      });
    }
  }

  @override
  void dispose() {
    _subscriptionNotifier.removeListener(_onSubscriptionStatusChanged);
    _subscriptionNotifier.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) {
          // Prompt for label
          final label = await _showAddLabelDialog(file.name);

          setState(() {
            _files.add(FileAttachment(
              fileName: file.name,
              label: label?.isEmpty == true ? null : label,
              localPath: file.path,
              s3Key: null,
              fileSize: file.size,
              addedAt: DateTime.now(),
            ));
          });
        }
      }
    }
  }

  Future<String?> _showAddLabelDialog(String fileName) async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Label for file'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $fileName'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g., Policy, Renewal, Receipt',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  Future<void> _editFileLabel(FileAttachment file) async {
    final controller = TextEditingController(text: file.label ?? '');

    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${file.fileName}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel != null) {
      setState(() {
        final index = _files.indexOf(file);
        _files[index] = file.copyWith(
          label: newLabel.isEmpty ? null : newLabel,
        );
      });
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Store the saved document with correct syncId
      Document savedDoc;

      if (widget.document == null) {
        // Create new document - USE THE RETURNED DOCUMENT
        savedDoc = await _documentRepository.createDocument(
          title: _titleController.text.trim(),
          category: _selectedCategory,
          date: _selectedDate,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      } else {
        // Update existing document
        final doc = widget.document!.copyWith(
          title: _titleController.text.trim(),
          category: _selectedCategory,
          date: _selectedDate,
          clearDate: _selectedDate == null && widget.document!.date != null,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          updatedAt: DateTime.now(),
          files: _files,
        );

        await _documentRepository.updateDocument(doc);
        savedDoc = doc;
      }

      // Add file attachments using CORRECT syncId from saved document
      // Handle file changes: additions, updates, and deletions
      final originalFileNames =
          widget.document?.files.map((f) => f.fileName).toSet() ?? {};
      final currentFileNames = _files.map((f) => f.fileName).toSet();

      // Create a map of original files for label comparison
      final originalFilesMap = widget.document != null
          ? {for (var f in widget.document!.files) f.fileName: f}
          : <String, FileAttachment>{};

      // Handle deletions - files that were in original but not in current
      for (final originalFileName in originalFileNames) {
        if (!currentFileNames.contains(originalFileName)) {
          await _documentRepository.deleteFileAttachment(
            syncId: savedDoc.syncId,
            fileName: originalFileName,
          );
        }
      }

      // Handle additions and updates
      for (final file in _files) {
        if (originalFileNames.contains(file.fileName)) {
          // Existing file - check if label changed
          final originalFile = originalFilesMap[file.fileName];
          if (originalFile != null && originalFile.label != file.label) {
            await _documentRepository.updateFileLabel(
              syncId: savedDoc.syncId,
              fileName: file.fileName,
              label: file.label,
            );
          }
        } else {
          // New file - insert it
          if (file.localPath != null && file.s3Key == null) {
            await _documentRepository.addFileAttachment(
              syncId: savedDoc.syncId,
              fileName: file.fileName,
              localPath: file.localPath!,
              s3Key: null,
              fileSize: file.fileSize,
              label: file.label,
            );
          }
        }
      }

      // Trigger sync with CORRECT syncId (catch exceptions to not fail save)
      try {
        await _syncService.syncDocument(savedDoc.syncId);
      } catch (e) {
        // Log but don't fail the save operation - sync will retry later
        debugPrint('Sync failed (will retry later): $e');
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.document == null
                ? 'Document created successfully'
                : 'Document updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to list
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument() async {
    if (widget.document == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to delete this document? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final document = widget.document!;

      // Get S3 keys before deleting from database
      final s3Keys = document.files
          .where((f) => f.s3Key != null)
          .map((f) => f.s3Key!)
          .toList();

      // 1. Delete from local database first
      await _documentRepository.deleteDocument(document.syncId);

      // 2. Delete from DynamoDB (soft delete with tombstone)
      try {
        _logService.log(
          'Deleting document from DynamoDB: ${document.syncId}',
          level: log_svc.LogLevel.info,
        );
        await _documentSyncService.deleteRemoteDocument(document.syncId);
      } catch (e) {
        // Log but don't fail - local deletion succeeded
        _logService.log(
          'Warning: Failed to delete document from DynamoDB: $e',
          level: log_svc.LogLevel.warning,
        );
        debugPrint('Warning: Failed to delete from DynamoDB: $e');
      }

      // 3. Delete FileAttachment records from DynamoDB
      try {
        _logService.log(
          'Deleting file attachments from DynamoDB for document: ${document.syncId}',
          level: log_svc.LogLevel.info,
        );

        for (final file in document.files) {
          try {
            final fileAttachmentSyncId = '${document.syncId}_${file.fileName}';
            await _fileAttachmentSyncService.deleteRemoteFileAttachment(
              syncId: fileAttachmentSyncId,
            );
          } catch (e) {
            _logService.log(
              'Warning: Failed to delete file attachment ${file.fileName}: $e',
              level: log_svc.LogLevel.warning,
            );
          }
        }
      } catch (e) {
        _logService.log(
          'Warning: Failed to delete file attachments from DynamoDB: $e',
          level: log_svc.LogLevel.warning,
        );
        debugPrint(
            'Warning: Failed to delete file attachments from DynamoDB: $e');
      }

      // 4. Delete files from S3 (if any exist)
      if (s3Keys.isNotEmpty) {
        try {
          _logService.log(
            'Deleting files from S3 for document: ${document.syncId}',
            level: log_svc.LogLevel.info,
          );

          final identityPoolId = await _authService.getIdentityPoolId();
          await _fileService.deleteDocumentFiles(
            syncId: document.syncId,
            identityPoolId: identityPoolId,
            s3Keys: s3Keys,
          );
        } catch (e) {
          // Log but don't fail - local deletion succeeded
          // S3 files can be cleaned up later or manually
          _logService.log(
            'Warning: Failed to delete S3 files: $e',
            level: log_svc.LogLevel.warning,
          );
          debugPrint('Warning: Failed to delete S3 files: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.document == null ? 'New Document' : 'Document Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Subscription indicator in app bar
          if (widget.document != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: _buildSubscriptionBadge(),
              ),
            ),
          if (!_isEditing && widget.document != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit',
            ),
          if (!_isEditing && widget.document != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _deleteDocument,
              tooltip: 'Delete',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.document == null
                  ? () => Navigator.pop(context)
                  : () {
                      setState(() {
                        _isEditing = false;
                        _titleController.text = widget.document!.title;
                        _selectedCategory = widget.document!.category;
                        _selectedDate = widget.document!.date;
                        _notesController.text = widget.document!.notes ?? '';
                        _files = List.from(widget.document!.files);
                      });
                    },
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isEditing) ...[
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DocumentCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: DocumentCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText:
                              '${_selectedCategory.dateLabel} (optional)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: _selectedDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearDate,
                                )
                              : null,
                        ),
                        child: Text(
                          _selectedDate != null
                              ? _formatDateOnly(_selectedDate!)
                              : 'Tap to select date',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFilesSection(),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveDocument,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.document == null
                              ? 'Create'
                              : 'Save Changes'),
                    ),
                  ] else ...[
                    _buildInfoCard('Title', widget.document!.title),
                    _buildInfoCard(
                        'Category', widget.document!.category.displayName),
                    if (widget.document!.date != null)
                      _buildInfoCard(
                        widget.document!.category.dateLabel,
                        _formatDateOnly(widget.document!.date!),
                      ),
                    if (widget.document!.notes != null &&
                        widget.document!.notes!.isNotEmpty)
                      _buildInfoCard('Notes', widget.document!.notes!),
                    if (widget.document!.files.isNotEmpty) _buildFilesCard(),
                    _buildInfoCard(
                      'Created',
                      _formatDate(widget.document!.createdAt),
                    ),
                    _buildInfoCard(
                      'Last Modified',
                      _formatDate(widget.document!.updatedAt),
                    ),
                    _buildSyncStatusCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionBadge() {
    final isCloudSyncEnabled = _subscriptionNotifier.isCloudSyncEnabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCloudSyncEnabled
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCloudSyncEnabled
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCloudSyncEnabled ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: isCloudSyncEnabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            isCloudSyncEnabled ? 'Cloud Synced' : 'Local Only',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCloudSyncEnabled ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Files',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Attach'),
                ),
              ],
            ),
            if (_files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No files attached',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._files.asMap().entries.map((entry) {
                final file = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: FileThumbnailWidget(
                    file: file,
                    size: 56,
                  ),
                  title: Text(
                    file.displayName, // Shows label if present, otherwise fileName
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: file.fileSize != null
                      ? Text(_formatFileSize(file.fileSize!))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editFileLabel(file),
                        tooltip: 'Edit label',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeFile(entry.key),
                        tooltip: 'Remove file',
                      ),
                    ],
                  ),
                );
              }),
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

  Widget _buildFilesCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Files (${widget.document!.files.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.document!.files.map((file) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: FileThumbnailWidget(
                  file: file,
                  size: 56,
                ),
                title: Text(
                  file.displayName, // Shows label if present, otherwise fileName
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: file.fileSize != null
                    ? Text(_formatFileSize(file.fileSize!))
                    : null,
                trailing: file.localPath != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.cloud_download, color: Colors.orange),
                onTap: () => _handleFileTap(file),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    final syncState = widget.document!.syncState;
    IconData icon;
    Color color;
    String status;

    switch (syncState) {
      case SyncState.synced:
        icon = Icons.cloud_done;
        color = Colors.green;
        status = 'Synced';
        break;
      case SyncState.pendingUpload:
        icon = Icons.cloud_upload;
        color = Colors.orange;
        status = 'Pending Upload';
        break;
      case SyncState.pendingDownload:
        icon = Icons.cloud_download;
        color = Colors.blue;
        status = 'Pending Download';
        break;
      case SyncState.uploading:
        icon = Icons.cloud_upload;
        color = Colors.blue;
        status = 'Uploading...';
        break;
      case SyncState.downloading:
        icon = Icons.cloud_download;
        color = Colors.blue;
        status = 'Downloading...';
        break;
      case SyncState.error:
        icon = Icons.error;
        color = Colors.red;
        status = 'Sync Error';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sync Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Handle file tap - download if needed, then open
  Future<void> _handleFileTap(FileAttachment file) async {
    try {
      // Request storage permission if needed
      if (!await _requestStoragePermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to view files'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // If file is already downloaded, open it
      if (file.localPath != null) {
        await _openFile(file.localPath!);
        return;
      }

      // File needs to be downloaded first
      if (file.s3Key == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not available for download'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show downloading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading ${file.displayName}...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      _logService.log(
        'Downloading file attachment: ${file.fileName}',
        level: log_svc.LogLevel.info,
      );

      // Get identity pool ID for download
      final identityPoolId = await _authService.getIdentityPoolId();

      // Download the file
      final localPath = await _fileService.downloadFile(
        s3Key: file.s3Key!,
        syncId: widget.document!.syncId,
        identityPoolId: identityPoolId,
      );

      _logService.log(
        'File downloaded successfully: $localPath',
        level: log_svc.LogLevel.info,
      );

      // Update the file attachment in database with local path
      await _documentRepository.updateFileLocalPath(
        syncId: widget.document!.syncId,
        fileName: file.fileName,
        localPath: localPath,
      );

      // Reload the document to get updated file attachments
      final updatedDoc =
          await _documentRepository.getDocument(widget.document!.syncId);
      if (updatedDoc != null) {
        setState(() {
          _files = List.from(updatedDoc.files);
        });
      }

      // Open the downloaded file
      await _openFile(localPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.displayName} downloaded and opened'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logService.log(
        'Error handling file tap: $e',
        level: log_svc.LogLevel.error,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Request storage permission for file access
  Future<bool> _requestStoragePermission() async {
    try {
      // On Android 13+ (API 33+), storage permission is not needed for app-scoped storage
      // The open_file package should work without it
      // For older Android versions, we need READ_EXTERNAL_STORAGE

      // Check if already granted
      var status = await Permission.storage.status;

      if (status.isGranted) {
        return true;
      }

      // If denied, request it
      if (status.isDenied) {
        status = await Permission.storage.request();

        if (status.isGranted) {
          return true;
        }
      }

      // If permanently denied, show settings dialog
      if (status.isPermanentlyDenied) {
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Storage permission is required to view files. '
                'Please grant permission in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await openAppSettings();
          }
        }
        return false;
      }

      // On Android 13+, the permission might be "restricted" or not applicable
      // In this case, we should try to open the file anyway
      _logService.log(
        'Storage permission status: ${status.name}, attempting to open file anyway',
        level: log_svc.LogLevel.info,
      );

      return true; // Try anyway on newer Android versions
    } catch (e) {
      _logService.log(
        'Error checking storage permission: $e',
        level: log_svc.LogLevel.warning,
      );
      // If permission check fails, try to open file anyway
      return true;
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      _logService.log(
        'Attempting to open file: $filePath',
        level: log_svc.LogLevel.info,
      );

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found at path: $filePath');
      }

      _logService.log(
        'File exists, opening with OpenFile package',
        level: log_svc.LogLevel.info,
      );

      final result = await OpenFile.open(filePath);

      _logService.log(
        'OpenFile result: ${result.type.name} - ${result.message}',
        level: log_svc.LogLevel.info,
      );

      if (result.type != ResultType.done) {
        // Show error if file couldn't be opened
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      _logService.log(
        'Error opening file: $e',
        level: log_svc.LogLevel.error,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
