import 'package:flutter/material.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/Document.dart';
import '../models/sync_state.dart';
import '../services/conflict_resolution_service.dart';
import '../services/sync_identifier_service.dart';

/// Screen for resolving synchronization conflicts
class ConflictResolutionScreen extends StatefulWidget {
  final DocumentConflict conflict;

  const ConflictResolutionScreen({
    super.key,
    required this.conflict,
  });

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  final ConflictResolutionService _conflictService =
      ConflictResolutionService();
  bool _isResolving = false;
  ConflictResolution? _selectedResolution;

  // For merge mode - track which fields to use
  final Map<String, bool> _useLocalField = {};

  @override
  void initState() {
    super.initState();
    _initializeMergeFields();
  }

  void _initializeMergeFields() {
    // Initialize merge field selections (default to local)
    _useLocalField['title'] = true;
    _useLocalField['category'] = true;
    _useLocalField['notes'] = true;
    _useLocalField['renewalDate'] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Conflict'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: _isResolving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConflictHeader(),
                  _buildResolutionOptions(),
                  if (_selectedResolution == ConflictResolution.merge)
                    _buildMergeInterface()
                  else
                    _buildComparisonView(),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildConflictHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red[800], size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sync Conflict Detected',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This document was modified on multiple devices. Choose how to resolve the conflict:',
            style: TextStyle(color: Colors.red[800]),
          ),
          const SizedBox(height: 8),
          Text(
            'Document: ${widget.conflict.localDocument.title}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionOptions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resolution Strategy:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildResolutionOption(
            ConflictResolution.keepLocal,
            'Keep This Device\'s Version',
            'Use the version from this device and discard changes from other devices',
            Icons.phone_android,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildResolutionOption(
            ConflictResolution.keepRemote,
            'Keep Other Device\'s Version',
            'Use the version from the other device and discard local changes',
            Icons.cloud,
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildResolutionOption(
            ConflictResolution.merge,
            'Merge Changes',
            'Manually select which fields to keep from each version',
            Icons.merge,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionOption(
    ConflictResolution resolution,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedResolution == resolution;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedResolution = resolution;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Version Comparison:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildVersionCard(
                  'This Device',
                  widget.conflict.localDocument,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVersionCard(
                  'Other Device',
                  widget.conflict.remoteDocument,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(String label, Document doc, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          const Divider(),
          _buildFieldRow('Title', doc.title),
          _buildFieldRow('Category', doc.category),
          _buildFieldRow('Notes', doc.notes ?? 'None'),
          _buildFieldRow(
            'Renewal Date',
            doc.renewalDate != null
                ? _formatDate(doc.renewalDate!.getDateTimeInUtc())
                : 'None',
          ),
          _buildFieldRow('Files', '${doc.filePaths.length} attached'),
          _buildFieldRow('Version', doc.version.toString()),
          _buildFieldRow(
              'Modified', _formatDateTime(doc.lastModified.getDateTimeInUtc())),
        ],
      ),
    );
  }

  Widget _buildMergeInterface() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Fields to Keep:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose which version of each field to keep in the merged document:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          _buildMergeFieldSelector(
            'Title',
            widget.conflict.localDocument.title,
            widget.conflict.remoteDocument.title,
          ),
          _buildMergeFieldSelector(
            'Category',
            widget.conflict.localDocument.category,
            widget.conflict.remoteDocument.category,
          ),
          _buildMergeFieldSelector(
            'Notes',
            widget.conflict.localDocument.notes ?? 'None',
            widget.conflict.remoteDocument.notes ?? 'None',
          ),
          _buildMergeFieldSelector(
            'Renewal Date',
            widget.conflict.localDocument.renewalDate != null
                ? _formatDate(widget.conflict.localDocument.renewalDate!
                    .getDateTimeInUtc())
                : 'None',
            widget.conflict.remoteDocument.renewalDate != null
                ? _formatDate(widget.conflict.remoteDocument.renewalDate!
                    .getDateTimeInUtc())
                : 'None',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'File attachments from both versions will be combined automatically.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeFieldSelector(
    String fieldName,
    String localValue,
    String remoteValue,
  ) {
    final useLocal = _useLocalField[fieldName.toLowerCase()] ?? true;
    final isDifferent = localValue != remoteValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDifferent ? Colors.orange[300]! : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isDifferent ? Colors.orange[50] : Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fieldName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (isDifferent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DIFFERENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _useLocalField[fieldName.toLowerCase()] = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: useLocal ? Colors.blue : Colors.grey[300]!,
                        width: useLocal ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      color: useLocal ? Colors.blue[50] : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              useLocal
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: useLocal ? Colors.blue : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'This Device',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localValue,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _useLocalField[fieldName.toLowerCase()] = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: !useLocal ? Colors.green : Colors.grey[300]!,
                        width: !useLocal ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      color: !useLocal ? Colors.green[50] : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              !useLocal
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: !useLocal ? Colors.green : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Other Device',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          remoteValue,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _selectedResolution != null ? _resolveConflict : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Resolve Conflict',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveConflict() async {
    if (_selectedResolution == null) return;

    setState(() => _isResolving = true);

    try {
      Document resolvedDocument;

      if (_selectedResolution == ConflictResolution.merge) {
        // Create custom merged document based on user selections
        resolvedDocument = await _createCustomMerge();
      } else {
        // Use the conflict resolution service for keep local/remote
        resolvedDocument = await _conflictService.resolveConflict(
          widget.conflict.id,
          _mapToResolutionStrategy(_selectedResolution!),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, resolvedDocument);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving conflict: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Document> _createCustomMerge() async {
    final local = widget.conflict.localDocument;
    final remote = widget.conflict.remoteDocument;

    // Merge file paths - combine both lists and remove duplicates
    final mergedFilePaths = <String>{
      ...local.filePaths,
      ...remote.filePaths,
    }.toList();

    // Merge file attachments - combine both lists
    final mergedAttachments = {
      ...(local.fileAttachments ?? []),
      ...(remote.fileAttachments ?? []),
    }.toList();

    // Create merged document based on user selections
    final mergedDocument = Document(
      syncId: SyncIdentifierService.generateValidated(),
      userId: local.userId,
      title: _useLocalField['title']! ? local.title : remote.title,
      category: _useLocalField['category']! ? local.category : remote.category,
      filePaths: mergedFilePaths,
      fileAttachments: mergedAttachments,
      renewalDate: _useLocalField['renewaldate']!
          ? local.renewalDate
          : remote.renewalDate,
      notes: _useLocalField['notes']! ? local.notes : remote.notes,
      createdAt: local.createdAt
              .getDateTimeInUtc()
              .isBefore(remote.createdAt.getDateTimeInUtc())
          ? local.createdAt
          : remote.createdAt,
      lastModified: amplify_core.TemporalDateTime.now(),
      version:
          (local.version > remote.version ? local.version : remote.version) + 1,
      syncState: SyncState.pending.toJson(),
      conflictId: null,
    );

    return await _conflictService.resolveConflictManually(
      widget.conflict.id,
      mergedDocument,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  ConflictResolutionStrategy _mapToResolutionStrategy(
      ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return ConflictResolutionStrategy.keepLocal;
      case ConflictResolution.keepRemote:
        return ConflictResolutionStrategy.keepRemote;
      case ConflictResolution.merge:
        return ConflictResolutionStrategy.merge;
    }
  }

  @override
  void dispose() {
    _conflictService.dispose();
    super.dispose();
  }
}
