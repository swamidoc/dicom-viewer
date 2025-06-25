import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

const String apiBase = "http://127.0.0.1:8000"; // Change for your backend

Future<List<File>> getAllFilesInFolder(String folderPath) async {
  final dir = Directory(folderPath);
  final List<File> files = [];
  if (await dir.exists()) {
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }
  }
  return files;
}

Future<void> pickAndUploadFilesAndFolders(BuildContext context) async {
  List<File> filesToUpload = [];

  // Pick files
  FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    allowedExtensions: ['dcm', 'dicom', 'jpg', 'jpeg', 'jp2', 'png', 'bmp'],
    type: FileType.custom,
  );
  if (fileResult != null) {
    for (var file in fileResult.files) {
      if (file.path != null) filesToUpload.add(File(file.path!));
    }
  }

  // Pick folder (on desktop/web)
  String? folderPath;
  if (!Platform.isAndroid && !Platform.isIOS) {
    folderPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pick a folder (optional)');
    if (folderPath != null) {
      List<File> folderFiles = await getAllFilesInFolder(folderPath);
      filesToUpload.addAll(folderFiles.where((f) => ['.dcm','.dicom','.jpg','.jpeg','.jp2','.png','.bmp']
          .contains(p.extension(f.path).toLowerCase())));
    }
  }

  if (filesToUpload.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No files selected.')));
    return;
  }

  try {
    var uri = Uri.parse("$apiBase/upload/");
    var request = http.MultipartRequest('POST', uri);
    for (var file in filesToUpload) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }
    var streamed = await request.send();
    var response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${response.body}')));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
  }
}