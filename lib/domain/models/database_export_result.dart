class DatabaseExportResult {
  const DatabaseExportResult({
    required this.filePath,
    required this.createdAt,
    required this.fileSizeBytes,
  });

  final String filePath;
  final DateTime createdAt;
  final int fileSizeBytes;
}
