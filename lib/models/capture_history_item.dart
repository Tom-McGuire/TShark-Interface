import '../utils/format_utils.dart';

class CaptureHistoryItem {
  const CaptureHistoryItem({
    required this.filePath,
    required this.fileName,
    required this.timestamp,
    required this.fileSizeBytes,
    required this.interfaceName,
    this.filter = '',
    this.isRemote = false,
    this.remoteHostId,
  });

  final String filePath;
  final String fileName;
  final DateTime timestamp;
  final int fileSizeBytes;
  final String interfaceName;
  final String filter;
  final bool isRemote;
  final String? remoteHostId;

  String get formattedSize => FormatUtils.formatBytes(fileSizeBytes);

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'timestamp': timestamp.toIso8601String(),
        'fileSizeBytes': fileSizeBytes,
        'interfaceName': interfaceName,
        'filter': filter,
        'isRemote': isRemote,
        if (remoteHostId != null) 'remoteHostId': remoteHostId,
      };

  factory CaptureHistoryItem.fromJson(Map<String, dynamic> json) {
    return CaptureHistoryItem(
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      interfaceName: json['interfaceName'] as String? ?? 'Interface',
      filter: json['filter'] as String? ?? '',
      isRemote: json['isRemote'] as bool? ?? false,
      remoteHostId: json['remoteHostId'] as String?,
    );
  }
}
