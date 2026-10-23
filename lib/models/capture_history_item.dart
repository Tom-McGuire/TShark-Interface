class CaptureHistoryItem {
  const CaptureHistoryItem({
    required this.filePath,
    required this.fileName,
    required this.timestamp,
    required this.fileSizeBytes,
    required this.interfaceName,
    this.filter = '',
  });

  final String filePath;
  final String fileName;
  final DateTime timestamp;
  final int fileSizeBytes;
  final String interfaceName;
  final String filter;

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'timestamp': timestamp.toIso8601String(),
        'fileSizeBytes': fileSizeBytes,
        'interfaceName': interfaceName,
        'filter': filter,
      };

  factory CaptureHistoryItem.fromJson(Map<String, dynamic> json) {
    return CaptureHistoryItem(
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      interfaceName: json['interfaceName'] as String? ?? 'Interface',
      filter: json['filter'] as String? ?? '',
    );
  }
}
