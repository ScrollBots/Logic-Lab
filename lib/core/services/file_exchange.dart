import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class FileExchangeException implements Exception {
  const FileExchangeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PickedTextFile {
  const PickedTextFile({required this.name, required this.content});

  final String name;
  final String content;
}

/// Platform file integration used only for user-initiated import/export.
/// No file is ever read or written silently, and exports contain plain,
/// portable JSON/CSV rather than internal application paths.
class FileExchange {
  const FileExchange._();

  static const int _maxImportBytes = 5 * 1024 * 1024;

  static Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    try {
      final List<int> bytes = <int>[...utf8.encode(content)];
      final XFile file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: mimeType,
        name: fileName,
      );
      await Share.shareXFiles(
        <XFile>[file],
        fileNameOverrides: <String>[fileName],
        subject: subject,
        text: subject,
      );
    } catch (error) {
      throw FileExchangeException('اشتراک‌گذاری فایل انجام نشد: $error');
    }
  }

  static Future<PickedTextFile?> pickJsonFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final PlatformFile file = result.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        throw const FileExchangeException(
          'دسترسی به محتوای فایل ممکن نشد. دوباره تلاش کنید.',
        );
      }
      if (bytes.lengthInBytes > _maxImportBytes) {
        throw const FileExchangeException(
          'حجم فایل بیش از حد مجاز (۵ مگابایت) است.',
        );
      }
      try {
        final String content = utf8.decode(bytes);
        return PickedTextFile(name: file.name, content: content);
      } on FormatException {
        throw const FileExchangeException(
          'فایل انتخاب‌شده متن UTF-8 معتبر نیست.',
        );
      }
    } on FileExchangeException {
      rethrow;
    } catch (error) {
      throw FileExchangeException('انتخاب فایل انجام نشد: $error');
    }
  }

  static Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
