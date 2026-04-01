// Admin export data models

part of '../admin_models.dart';

class AdminExportFile {
  AdminExportFile({
    required this.fileName,
    required this.contentType,
    required this.content,
    required this.rowCount,
  });

  final String fileName;
  final String contentType;
  final String content;
  final int rowCount;

  factory AdminExportFile.fromJson(Map<String, dynamic> json) {
    return AdminExportFile(
      fileName: (json['fileName'] ?? 'admin-export.txt').toString(),
      contentType:
          (json['contentType'] ?? 'text/plain; charset=utf-8').toString(),
      content: (json['content'] ?? '').toString(),
      rowCount: _toInt(json['rowCount']) ?? 0,
    );
  }
}
