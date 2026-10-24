import 'capture_interface.dart';

enum CaptureMode {
  manual,
  timed,
  ringBuffer,
  packetCount;

  String get label {
    switch (this) {
      case CaptureMode.manual:
        return 'Manual Stop';
      case CaptureMode.timed:
        return 'Timed Duration';
      case CaptureMode.ringBuffer:
        return 'Ring Buffer (Rolling)';
      case CaptureMode.packetCount:
        return 'Packet Count';
    }
  }

  String get description {
    switch (this) {
      case CaptureMode.manual:
        return 'Captures continuously until you click Stop.';
      case CaptureMode.timed:
        return 'Stops automatically after a specified time window.';
      case CaptureMode.ringBuffer:
        return 'Rotates capture files by time or size, retaining the latest N files.';
      case CaptureMode.packetCount:
        return 'Stops automatically after capturing a target number of packets.';
    }
  }
}

enum RecoveryPolicy {
  none,
  prompt,
  auto;

  String get label {
    switch (this) {
      case RecoveryPolicy.none:
        return 'Disabled';
      case RecoveryPolicy.prompt:
        return 'Prompt to Resume';
      case RecoveryPolicy.auto:
        return 'Auto-Restart on Boot';
    }
  }

  String get description {
    switch (this) {
      case RecoveryPolicy.none:
        return 'Do not restore capture after reboot or unexpected termination.';
      case RecoveryPolicy.prompt:
        return 'Flag interrupted capture and prompt to resume when the app starts.';
      case RecoveryPolicy.auto:
        return 'Automatically restart capture with the same settings on app start (ideal for unattended setups).';
    }
  }

  bool get isNone => this == RecoveryPolicy.none;
  bool get isPrompt => this == RecoveryPolicy.prompt;
  bool get isAuto => this == RecoveryPolicy.auto;
}

class CaptureConfig {
  const CaptureConfig({
    required this.interface,
    required this.outputDirectory,
    this.filePrefix = 'capture',
    this.createSubfolder = true,
    this.mode = CaptureMode.manual,
    this.durationMinutes = 10,
    this.durationHours = 0,
    this.ringRotateMinutes = 10,
    this.ringRotateFilesizeMb = 100,
    this.ringFilesCount = 5,
    this.ringRotateBySize = false,
    this.packetCountLimit = 10000,
    this.captureFilter = '',
    this.snaplen = 0,
    this.promiscuous = true,
    this.recoveryPolicy = RecoveryPolicy.prompt,
  });

  final CaptureInterface interface;
  final String outputDirectory;
  final String filePrefix;
  final bool createSubfolder;
  final CaptureMode mode;

  // Timed mode
  final int durationMinutes;
  final int durationHours;

  // Ring buffer mode
  final int ringRotateMinutes;
  final int ringRotateFilesizeMb;
  final int ringFilesCount;
  final bool ringRotateBySize;

  // Packet limit mode
  final int packetCountLimit;

  // Advanced capture options
  final String captureFilter;
  final int snaplen; // 0 = full packet, >0 = packet payload slice
  final bool promiscuous;

  // Reboot / crash recovery policy
  final RecoveryPolicy recoveryPolicy;

  int get totalTimedSeconds => (durationHours * 3600) + (durationMinutes * 60);

  CaptureConfig copyWith({
    CaptureInterface? interface,
    String? outputDirectory,
    String? filePrefix,
    bool? createSubfolder,
    CaptureMode? mode,
    int? durationMinutes,
    int? durationHours,
    int? ringRotateMinutes,
    int? ringRotateFilesizeMb,
    int? ringFilesCount,
    bool? ringRotateBySize,
    int? packetCountLimit,
    String? captureFilter,
    int? snaplen,
    bool? promiscuous,
    RecoveryPolicy? recoveryPolicy,
  }) {
    return CaptureConfig(
      interface: interface ?? this.interface,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      filePrefix: filePrefix ?? this.filePrefix,
      createSubfolder: createSubfolder ?? this.createSubfolder,
      mode: mode ?? this.mode,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationHours: durationHours ?? this.durationHours,
      ringRotateMinutes: ringRotateMinutes ?? this.ringRotateMinutes,
      ringRotateFilesizeMb: ringRotateFilesizeMb ?? this.ringRotateFilesizeMb,
      ringFilesCount: ringFilesCount ?? this.ringFilesCount,
      ringRotateBySize: ringRotateBySize ?? this.ringRotateBySize,
      packetCountLimit: packetCountLimit ?? this.packetCountLimit,
      captureFilter: captureFilter ?? this.captureFilter,
      snaplen: snaplen ?? this.snaplen,
      promiscuous: promiscuous ?? this.promiscuous,
      recoveryPolicy: recoveryPolicy ?? this.recoveryPolicy,
    );
  }

  Map<String, dynamic> toJson() => {
        'interface': interface.toJson(),
        'outputDirectory': outputDirectory,
        'filePrefix': filePrefix,
        'createSubfolder': createSubfolder,
        'mode': mode.name,
        'durationMinutes': durationMinutes,
        'durationHours': durationHours,
        'ringRotateMinutes': ringRotateMinutes,
        'ringRotateFilesizeMb': ringRotateFilesizeMb,
        'ringFilesCount': ringFilesCount,
        'ringRotateBySize': ringRotateBySize,
        'packetCountLimit': packetCountLimit,
        'captureFilter': captureFilter,
        'snaplen': snaplen,
        'promiscuous': promiscuous,
        'recoveryPolicy': recoveryPolicy.name,
      };

  factory CaptureConfig.fromJson(Map<String, dynamic> json) {
    return CaptureConfig(
      interface: CaptureInterface.fromJson(
        Map<String, dynamic>.from(json['interface'] as Map),
      ),
      outputDirectory: json['outputDirectory'] as String? ?? '',
      filePrefix: json['filePrefix'] as String? ?? 'capture',
      createSubfolder: json['createSubfolder'] as bool? ?? true,
      mode: CaptureMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => CaptureMode.manual,
      ),
      durationMinutes: json['durationMinutes'] as int? ?? 10,
      durationHours: json['durationHours'] as int? ?? 0,
      ringRotateMinutes: json['ringRotateMinutes'] as int? ?? 10,
      ringRotateFilesizeMb: json['ringRotateFilesizeMb'] as int? ?? 100,
      ringFilesCount: json['ringFilesCount'] as int? ?? 5,
      ringRotateBySize: json['ringRotateBySize'] as bool? ?? false,
      packetCountLimit: json['packetCountLimit'] as int? ?? 10000,
      captureFilter: json['captureFilter'] as String? ?? '',
      snaplen: json['snaplen'] as int? ?? 0,
      promiscuous: json['promiscuous'] as bool? ?? true,
      recoveryPolicy: RecoveryPolicy.values.firstWhere(
        (p) => p.name == json['recoveryPolicy'],
        orElse: () => RecoveryPolicy.prompt,
      ),
    );
  }
}
