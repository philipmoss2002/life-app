import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/new_document.dart';
import '../models/file_attachment.dart';
import '../models/sync_state.dart';
import '../repositories/document_repository.dart';
import '../services/sync_service.dart';
import '../services/authentication_service.dart';
import '../services/file_service.dart';

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

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<String> _labels;
  late List<FileAttachment> _files;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.document == null; // Edit mode if creating new
    _titleController =
        TextEditingController(text: widget.document?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.document?.description ?? '');
    _labels = List.from(widget.document?.labels ?? []);
    _files = List.from(widget.document?.files ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            _files.add(FileAttachment(
              fileName: file.name,
              localPath: file.path,
              s3Key: null,
              fileSize: file.size,
              addedAt: DateTime.now(),
            ));
          }
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  Future<void> _addLabel() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'Enter label name',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && !_labels.contains(result)) {
      setState(() {
        _labels.add(result);
      });
    }
  }

  void _removeLabel(int index) {
    setState(() {
      _labels.removeAt(index);
    });
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Document doc;

      if (widget.document == null) {
        // Create new document
        doc = Document.create(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          labels: _labels,
        );
      } else {
        // Update existing document
        doc = widget.document!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          labels: _labels,
          updatedAt: DateTime.now(),
          files: _files,
        );
      }

      // Save to repository
      if (widget.document == null) {
        await _documentRepository.createDocument(
          title: doc.title,
          description: doc.description,
          labels: doc.labels,
        );
      } else {
        await _documentRepository.updateDocument(doc);
      }

      // Add file attachments
      for (final file in _files) {
        if (file.localPath != null && file.s3Key == null) {
          await _documentRepository.addFileAttachment(
            syncId: doc.syncId,
            fileName: file.fileName,
            localPath: file.localPath!,
            s3Key: null,
            fileSize: file.fileSize,
          );
        }
      }

      // Trigger sync
      await _syncService.syncDocument(doc.syncId);

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

      // Delete from local database first
      await _documentRepository.deleteDocument(document.syncId);

      // Delete files from S3 (if any exist)
      if (s3Keys.isNotEmpty) {
        try {
          final identityPoolId = await _authService.getIdentityPoolId();
          await _fileService.deleteDocumentFiles(
            syncId: document.syncId,
            identityPoolId: identityPoolId,
            s3Keys: s3Keys,
          );
        } catch (e) {
          // Log but don't fail - local deletion succeeded
          // S3 files can be cleaned up later or manually
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
                        _descriptionController.text =
                            widget.document!.description ?? '';
                        _labels = List.from(widget.document!.labels);
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
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    _buildLabelsSection(),
                    const SizedBox(height: 16),
                    _buildFilesSection(),
                    const SizedBox(height: 24),
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
                    if (widget.document!.description != null &&
                        widget.document!.description!.isNotEmpty)
                      _buildInfoCard(
                          'Description', widget.document!.description!),
                    if (widget.document!.labels.isNotEmpty) _buildLabelsCard(),
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

  Widget _buildLabelsSection() {
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
                  'Labels',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addLabel,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_labels.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No labels added',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _labels.asMap().entries.map((entry) {
                  return Chip(
                    label: Text(entry.value),
                    onDeleted: () => _removeLabel(entry.key),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
          ],
        ),
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
                  leading: Icon(
                    _getFileIcon(file.fileName),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(file.fileName),
                  subtitle: file.fileSize != null
                      ? Text(_formatFileSize(file.fileSize!))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeFile(entry.key),
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

  Widget _buildLabelsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Labels',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.document!.labels.map((label) {
                return Chip(
                  label: Text(label),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
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
                leading: Icon(
                  _getFileIcon(file.fileName),
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(file.fileName),
                subtitle: file.fileSize != null
                    ? Text(_formatFileSize(file.fileSize!))
                    : null,
                trailing: file.localPath != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.cloud_download, color: Colors.orange),
                onTap: file.localPath != null
                    ? () => _openFile(file.localPath!)
                    : null,
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

  IconData _getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
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

  Future<void> _openFile(String filePath) async {
    // TODO: Implement file opening
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening file: ${filePath.split('/').last}'),
      ),
    );
  }
}
