import 'package:flutter/material.dart';

class PathDebugScreen extends StatelessWidget {
  const PathDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S3 Path Debug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'S3 Path Structure Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPathExample('Document ID: doc123', 'File: test.pdf'),
            const SizedBox(height: 16),
            _buildPathExample('Document ID: doc456', 'File: image.jpg'),
            const SizedBox(height: 24),
            const Text(
              'Expected S3 Bucket Structure:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Text(
                'household-docs-files-dev940d5-dev/\n'
                '└── public/\n'
                '    └── documents/\n'
                '        ├── doc123/\n'
                '        │   └── 1234567890-test.pdf\n'
                '        └── doc456/\n'
                '            └── 1234567891-image.jpg',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathExample(String docInfo, String fileInfo) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final docId = docInfo.split(': ')[1];
    final fileName = fileInfo.split(': ')[1];
    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final s3Key = 'documents/$docId/$timestamp-$sanitizedFileName';
    final publicPath = 'public/$s3Key';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(docInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(fileInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Generated S3 Key:', style: TextStyle(color: Colors.grey[600])),
          Text(s3Key,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(height: 4),
          Text('Full S3 Path:', style: TextStyle(color: Colors.grey[600])),
          Text(publicPath,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
