import 'package:flutter/material.dart';

/// Maps a file extension to an icon + color, so lists look like a
/// real file manager instead of generic document icons.
class FileVisuals {
  static IconData iconFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return Icons.image_rounded;
      case 'mp4':
      case 'mov':
      case 'mkv':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audio_file_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'txt':
        return Icons.notes_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color colorFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE84393);
      case 'doc':
      case 'docx':
        return const Color(0xFF0984E3);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF00B894);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFE17055);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return const Color(0xFFFDCB6E);
      case 'mp4':
      case 'mov':
      case 'mkv':
        return const Color(0xFF6C5CE7);
      case 'mp3':
      case 'wav':
      case 'm4a':
        return const Color(0xFF00CEC9);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFD63031);
      default:
        return const Color(0xFF636E72);
    }
  }
}
