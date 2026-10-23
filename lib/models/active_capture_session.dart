import 'capture_config.dart';

class ActiveCaptureSession {
  const ActiveCaptureSession({
    required this.pid,
    required this.startedAt,
    required this.outputDirectory,
    required this.targetFilePath,
    required this.mode,
    required this.interfaceName,
    required this.commandLine,
    this.filter = '',
    this.snaplen = 0,
    this.isDetached = false,
  });

  final int pid;
  final DateTime startedAt;
  final String outputDirectory;
  final String targetFilePath;
  final CaptureMode mode;
  final String interfaceName;
  final String commandLine;
  final String filter;
  final int snaplen;
  final bool isDetached;

  Duration get elapsed => DateTime.now().difference(startedAt);

  Map<String, dynamic> toJson() => {
        'pid': pid,
        'startedAt': startedAt.toIso8601String(),
        'outputDirectory': outputDirectory,
        'targetFilePath': targetFilePath,
        'mode': mode.name,
        'interfaceName': interfaceName,
        'commandLine': commandLine,
        'filter': filter,
        'snaplen': snaplen,
        'isDetached': isDetached,
      };

  factory ActiveCaptureSession.fromJson(Map<String, dynamic> json) {
    return ActiveCaptureSession(
      pid: json['pid'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      outputDirectory: json['outputDirectory'] as String,
      targetFilePath: json['targetFilePath'] as String? ?? json['outputDirectory'] as String,
      mode: CaptureMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => CaptureMode.manual,
      ),
      interfaceName: json['interfaceName'] as String? ?? 'Interface',
      commandLine: json['commandLine'] as String? ?? '',
      filter: json['filter'] as String? ?? '',
      snaplen: json['snaplen'] as int? ?? 0,
      isDetached: json['isDetached'] as bool? ?? false,
    );
  }
}
