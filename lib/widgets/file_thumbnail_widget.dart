import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/file_attachment.dart';

/// Widget that displays a thumbnail for a file attachment
/// Shows actual image for image files, PDF preview for PDFs, or icon for other types
class FileThumbnailWidget extends StatelessWidget {
  final FileAttachment file;
  final double size;

  const FileThumbnailWidget({
    super.key,
    required this.file,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final extension = file.fileName.toLowerCase().split('.').last;

    // Check if it's an image file
    if (_isImageFile(extension)) {
      return _buildImageThumbnail(context);
    }

    // Check if it's a PDF file
    if (extension == 'pdf') {
      return _buildPdfThumbnail(context);
    }

    // For other file types, show icon
    return _buildIconThumbnail(context, extension);
  }

  bool _isImageFile(String extension) {
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  Widget _buildImageThumbnail(BuildContext context) {
    if (file.localPath == null) {
      // File not downloaded yet, show placeholder
      return _buildIconThumbnail(context, 'image');
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(file.localPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(), // 2x for retina displays
        errorBuilder: (context, error, stackTrace) {
          // If image fails to load, show icon
          return _buildIconThumbnail(context, 'image');
        },
      ),
    );
  }

  Widget _buildPdfThumbnail(BuildContext context) {
    if (file.localPath == null) {
      // File not downloaded yet, show placeholder
      return _buildIconThumbnail(context, 'pdf');
    }

    return FutureBuilder<PdfDocument>(
      future: PdfDocument.openFile(file.localPath!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingThumbnail(context);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildIconThumbnail(context, 'pdf');
        }

        return FutureBuilder<PdfPage>(
          future: snapshot.data!.getPage(1),
          builder: (context, pageSnapshot) {
            if (pageSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingThumbnail(context);
            }

            if (pageSnapshot.hasError || !pageSnapshot.hasData) {
              return _buildIconThumbnail(context, 'pdf');
            }

            return FutureBuilder<PdfPageImage?>(
              future: pageSnapshot.data!.render(
                width: (size * 2).toInt().toDouble(),
                height: (size * 2).toInt().toDouble(),
                format: PdfPageImageFormat.png,
              ),
              builder: (context, imageSnapshot) {
                if (imageSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingThumbnail(context);
                }

                if (imageSnapshot.hasError ||
                    !imageSnapshot.hasData ||
                    imageSnapshot.data == null) {
                  return _buildIconThumbnail(context, 'pdf');
                }

                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    imageSnapshot.data!.bytes,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingThumbnail(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildIconThumbnail(BuildContext context, String extension) {
    final icon = _getFileIcon(extension);
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.5,
      ),
    );
  }

  IconData _getFileIcon(String extension) {
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
      case 'webp':
      case 'bmp':
      case 'image':
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
}
