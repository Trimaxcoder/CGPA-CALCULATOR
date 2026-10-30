// lib/services/attachment_service.dart
//
// Picking and uploading photos, documents and (later) voice notes for the
// class chat.
//
// How an upload works:
//  1. Ask our backend for an upload permission for this class.
//  2. Send the file straight to Cloudinary with that permission.
//  3. Cloudinary answers with the file's link, which goes into the chat message.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/class_models.dart';
import 'api_service.dart';

/// Same limit as the server (free Cloudinary plan).
const int kMaxAttachmentBytes = 10 * 1024 * 1024;

/// A file the student chose but has not sent yet.
class PickedAttachment {
  final String name;
  final Uint8List bytes;
  final String kind; // 'image' | 'file' | 'audio'
  final String mime;

  const PickedAttachment({
    required this.name,
    required this.bytes,
    required this.kind,
    required this.mime,
  });

  int get size => bytes.length;
}

/// A problem with picking or uploading a file, with a message safe to show.
class UploadException implements Exception {
  final String message;
  const UploadException(this.message);

  @override
  String toString() => message;
}

const _imageTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
};

const _audioTypes = {
  'm4a': 'audio/mp4',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'opus': 'audio/ogg',
  'webm': 'audio/webm',
};

const _otherTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'zip': 'application/zip',
};

/// Programs and scripts are never sent through the class chat.
const _blockedTypes = {
  'exe', 'msi', 'bat', 'cmd', 'com', 'scr', 'apk', 'sh', 'jar', 'vbs', 'ps1',
  'dll', 'app', 'dmg',
};

String _extOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

class AttachmentService {
  final _client = ApiClient();

  // ── Picking ────────────────────────────────────────────────────────────────

  /// Opens the photo picker. Returns null if the student cancels.
  /// Throws [UploadException] if the file is not allowed.
  Future<PickedAttachment?> pickImage() => _pick(FileType.image);

  /// Opens the camera (phones and tablets). Returns null if cancelled.
  Future<PickedAttachment?> pickCamera() async {
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (shot == null) return null;

      final bytes = await shot.readAsBytes();
      final name = shot.name.isNotEmpty
          ? shot.name
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return validate(name: name, bytes: bytes);
    } on UploadException {
      rethrow;
    } catch (_) {
      throw const UploadException('Could not open the camera.');
    }
  }

  /// Opens the file picker (documents, PDFs, anything allowed).
  Future<PickedAttachment?> pickFile() => _pick(FileType.any);

  Future<PickedAttachment?> _pick(FileType type) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: type,
        withData: true,
        allowMultiple: false,
      );
    } catch (_) {
      throw const UploadException('Could not open the file picker.');
    }

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const UploadException('Could not read that file.');
    }

    return validate(name: file.name, bytes: bytes);
  }

  /// Checks a file and works out its kind. Throws [UploadException] if it
  /// can not be sent.
  PickedAttachment validate({
    required String name,
    required Uint8List bytes,
    String? forceKind,
  }) {
    final ext = _extOf(name);

    if (_blockedTypes.contains(ext)) {
      throw const UploadException('That type of file can not be sent here.');
    }
    if (bytes.isEmpty) {
      throw const UploadException('That file is empty.');
    }
    if (bytes.length > kMaxAttachmentBytes) {
      throw const UploadException('Files must be 10 MB or smaller.');
    }

    final String kind;
    final String mime;
    if (forceKind == 'audio') {
      kind = 'audio';
      mime = _audioTypes[ext] ?? 'audio/mp4';
    } else if (_imageTypes.containsKey(ext)) {
      kind = 'image';
      mime = _imageTypes[ext]!;
    } else if (_audioTypes.containsKey(ext)) {
      kind = 'file';
      mime = _audioTypes[ext]!;
    } else {
      kind = 'file';
      mime = _otherTypes[ext] ?? 'application/octet-stream';
    }

    return PickedAttachment(name: name, bytes: bytes, kind: kind, mime: mime);
  }

  // ── Uploading ──────────────────────────────────────────────────────────────

  /// Uploads the file held in [local] (its localBytes) and returns the same
  /// attachment with its link filled in. Throws [UploadException].
  Future<ChatAttachment> upload(String classId, ChatAttachment local) async {
    final bytes = local.localBytes;
    if (bytes == null) {
      throw const UploadException('The file is no longer available.');
    }

    // 1. Permission from our backend
    final Map<String, dynamic> slip;
    try {
      final data = await _client.post('/classes/$classId/upload-signature', {});
      slip = Map<String, dynamic>.from(data['upload'] as Map);
    } on ApiException catch (e) {
      throw UploadException(e.message);
    } catch (_) {
      throw const UploadException(
        'Could not start the upload. Check your connection.',
      );
    }

    // 2. The file itself, straight to Cloudinary
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(slip['uploadUrl'].toString()),
      )
        ..fields['api_key'] = slip['apiKey'].toString()
        ..fields['timestamp'] = slip['timestamp'].toString()
        ..fields['folder'] = slip['folder'].toString()
        ..fields['signature'] = slip['signature'].toString()
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: local.name),
        );

      final streamed = await request.send().timeout(const Duration(minutes: 2));
      final body = await streamed.stream.bytesToString();

      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // not JSON: handled below
      }

      if (streamed.statusCode != 200) {
        final err = json['error'];
        final text = err is Map ? (err['message'] ?? '').toString() : '';
        throw UploadException(
          text.isNotEmpty ? text : 'The upload was rejected. Please try again.',
        );
      }

      final url = (json['secure_url'] ?? '').toString();
      if (url.isEmpty) {
        throw const UploadException('The upload did not finish. Try again.');
      }

      return local.copyWith(
        url: url,
        duration: (json['duration'] as num?)?.round(),
      );
    } on UploadException {
      rethrow;
    } on TimeoutException {
      throw const UploadException('The upload took too long. Try again.');
    } catch (_) {
      throw const UploadException(
        'Upload failed. Check your connection and try again.',
      );
    }
  }
}