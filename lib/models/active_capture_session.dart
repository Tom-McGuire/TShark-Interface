import 'capture_config.dart';
import 'capture_interface.dart';

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
    this.config,
    this.recoveryPolicy = RecoveryPolicy.prompt,
    this.isRemote = false,
    this.remoteHostId,
    this.remoteHostName,
    this.isUnreachable = false,
    this.unreachableReason,
    this.lastKnownSizeBytes = 0,
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
  final CaptureConfig? config;
  final RecoveryPolicy recoveryPolicy;
  final bool isRemote;
  final String? remoteHostId;
  final String? remoteHostName;
  final bool isUnreachable;
  final String? unreachableReason;
  final int lastKnownSizeBytes;

  Duration get elapsed => DateTime.now().difference(startedAt);

  ActiveCaptureSession copyWith({
    int? pid,
    DateTime? startedAt,
    String? outputDirectory,
    String? targetFilePath,
    CaptureMode? mode,
    String? interfaceName,
    String? commandLine,
    String? filter,
    int? snaplen,
    bool? isDetached,
    CaptureConfig? config,
    RecoveryPolicy? recoveryPolicy,
    bool? isRemote,
    String? remoteHostId,
    String? remoteHostName,
    bool? isUnreachable,
    String? unreachableReason,
    int? lastKnownSizeBytes,
  }) {
    return ActiveCaptureSession(
      pid: pid ?? this.pid,
      startedAt: startedAt ?? this.startedAt,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      targetFilePath: targetFilePath ?? this.targetFilePath,
      mode: mode ?? this.mode,
      interfaceName: interfaceName ?? this.interfaceName,
      commandLine: commandLine ?? this.commandLine,
      filter: filter ?? this.filter,
      snaplen: snaplen ?? this.snaplen,
      isDetached: isDetached ?? this.isDetached,
      config: config ?? this.config,
      recoveryPolicy: recoveryPolicy ?? this.recoveryPolicy,
      isRemote: isRemote ?? this.isRemote,
      remoteHostId: remoteHostId ?? this.remoteHostId,
      remoteHostName: remoteHostName ?? this.remoteHostName,
      isUnreachable: isUnreachable ?? this.isUnreachable,
      unreachableReason: unreachableReason ?? this.unreachableReason,
      lastKnownSizeBytes: lastKnownSizeBytes ?? this.lastKnownSizeBytes,
    );
  }

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
        'recoveryPolicy': recoveryPolicy.name,
        'isRemote': isRemote,
        if (remoteHostId != null) 'remoteHostId': remoteHostId,
        if (remoteHostName != null) 'remoteHostName': remoteHostName,
        'lastKnownSizeBytes': lastKnownSizeBytes,
        if (config != null) 'config': config!.toJson(),
      };

  factory ActiveCaptureSession.fromJson(Map<String, dynamic> json) {
    CaptureConfig? decodedConfig;
    if (json['config'] != null) {
      try {
        decodedConfig = CaptureConfig.fromJson(
          Map<String, dynamic>.from(json['config'] as Map),
        );
      } catch (_) {}
    }

    final mode = CaptureMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => CaptureMode.manual,
    );

    final recoveryPolicy = RecoveryPolicy.values.firstWhere(
      (p) => p.name == json['recoveryPolicy'],
      orElse: () => decodedConfig?.recoveryPolicy ?? RecoveryPolicy.prompt,
    );

    final ifaceName = json['interfaceName'] as String? ?? 'Interface';
    final outputDir = json['outputDirectory'] as String;
    final targetPath = json['targetFilePath'] as String? ?? outputDir;
    final filter = json['filter'] as String? ?? '';
    final snaplen = json['snaplen'] as int? ?? 0;

    // Fallback config if not saved explicitly
    decodedConfig ??= CaptureConfig(
      interface: CaptureInterface(index: '1', name: ifaceName),
      outputDirectory: outputDir,
      mode: mode,
      captureFilter: filter,
      snaplen: snaplen,
      recoveryPolicy: recoveryPolicy,
    );

    return ActiveCaptureSession(
      pid: json['pid'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      outputDirectory: outputDir,
      targetFilePath: targetPath,
      mode: mode,
      interfaceName: ifaceName,
      commandLine: json['commandLine'] as String? ?? '',
      filter: filter,
      snaplen: snaplen,
      isDetached: json['isDetached'] as bool? ?? false,
      config: decodedConfig,
      recoveryPolicy: recoveryPolicy,
      isRemote: json['isRemote'] as bool? ?? false,
      remoteHostId: json['remoteHostId'] as String?,
      remoteHostName: json['remoteHostName'] as String?,
      lastKnownSizeBytes: json['lastKnownSizeBytes'] as int? ?? 0,
    );
  }
}
