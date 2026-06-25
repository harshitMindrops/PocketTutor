import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  ImageStorageService._();
  static final instance = ImageStorageService._();

  static const _imagesDir = 'chat_images';

  /// Returns the dedicated local directory for chat images.
  Future<Directory> _getChatImagesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _imagesDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns true if [str] looks like a base64-encoded file or data URL rather than a
  /// file-system path.
  bool isBase64(String str) {
    if (str.isEmpty) return false;

    // A file-system path always starts with / (Unix) or a drive letter (Win)
    // or contains path separators.
    if (str.startsWith('/') ||
        str.startsWith('file://') ||
        str.contains('\\') ||
        (str.length > 1 && str[1] == ':')) {
      return false;
    }

    if (str.startsWith('data:')) {
      return str.contains(';base64,');
    }

    // Base64 strings are long and contain only base64-alphabet characters.
    // A realistic file is at least a few KB (several thousand chars).
    if (str.length < 100) return false;

    // Quick regex check – base64 uses A-Z, a-z, 0-9, +, /, =
    final base64RegExp = RegExp(r'^[A-Za-z0-9+/=]+$');
    // Only sample the first 200 chars to keep this fast.
    return base64RegExp.hasMatch(str.substring(0, 200));
  }

  /// Returns true if [path] is an absolute path pointing to an existing file.
  bool isValidLocalFile(String? path) {
    if (path == null || path.isEmpty) return false;
    if (isBase64(path)) return false;
    return File(path).existsSync();
  }

  /// Decodes a base64 file string (or data URL), writes it to
  /// `<appDocs>/chat_images/<messageId>.<ext>`, and returns the local path.
  ///
  /// Returns null if decoding fails.
  Future<String?> saveImageFromBase64(
    String base64Str,
    String? messageId,
  ) async {
    return saveFileFromBase64(base64Str, messageId);
  }

  /// Decodes a base64 file string (or data URL), writes it to
  /// `<appDocs>/chat_images/<messageId>.<ext>`, and returns the local path.
  ///
  /// Returns null if decoding fails.
  Future<String?> saveFileFromBase64(
    String dataUrlOrBase64,
    String? messageId,
  ) async {
    try {
      List<int> bytes;
      String ext = '.jpg';

      if (dataUrlOrBase64.startsWith('data:')) {
        final match = RegExp(
          r'^data:(.*?);base64,(.*)$',
        ).firstMatch(dataUrlOrBase64);
        if (match != null) {
          final mimeType = match.group(1) ?? '';
          final base64Data = match.group(2) ?? '';
          bytes = base64Decode(base64Data);
          if (mimeType == 'application/pdf') {
            ext = '.pdf';
          } else if (mimeType.contains('word') ||
              mimeType.contains('msword') ||
              mimeType.contains('officedocument')) {
            if (mimeType.contains('officedocument')) {
              ext = '.docx';
            } else {
              ext = '.doc';
            }
          } else if (mimeType == 'image/png') {
            ext = '.png';
          } else if (mimeType == 'image/webp') {
            ext = '.webp';
          } else if (mimeType == 'image/gif') {
            ext = '.gif';
          }
        } else {
          return null;
        }
      } else {
        bytes = base64Decode(dataUrlOrBase64);
      }

      final dir = await _getChatImagesDir();
      final file = File(p.join(dir.path, '$messageId$ext'));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Copies an existing file into the chat_images directory under a stable
  /// name based on [messageId]. Returns the new persistent path.
  ///
  /// If [sourcePath] is already inside the chat_images dir, returns it as-is.
  Future<String> ensurePersistentCopy(
    String sourcePath,
    String messageId,
  ) async {
    final dir = await _getChatImagesDir();
    final ext = p.extension(sourcePath);
    final targetPath = p.join(dir.path, '$messageId$ext');

    // Already the canonical copy — nothing to do.
    if (sourcePath == targetPath) return sourcePath;

    // If the source is already somewhere inside chat_images, keep it.
    if (p.isWithin(dir.path, sourcePath)) return sourcePath;

    try {
      await File(sourcePath).copy(targetPath);
      return targetPath;
    } catch (_) {
      return sourcePath; // Fallback: keep original path.
    }
  }

  /// Deletes the local image file for [path] if it exists and is inside the
  /// chat_images directory (to avoid accidentally deleting external files).
  Future<void> deleteImage(String? path) async {
    if (path == null || path.isEmpty) return;
    if (isBase64(path)) return; // Nothing to delete.

    try {
      final dir = await _getChatImagesDir();
      final file = File(path);
      if (file.existsSync() && p.isWithin(dir.path, file.path)) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Deletes all image files for a list of [paths].
  Future<void> deleteImages(List<String?> paths) async {
    for (final path in paths) {
      await deleteImage(path);
    }
  }
}
