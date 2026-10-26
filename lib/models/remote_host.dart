enum RemoteOsType {
  auto,
  linux,
  windows;

  String get label {
    switch (this) {
      case RemoteOsType.auto:
        return 'Auto-Detect';
      case RemoteOsType.linux:
        return 'Linux / Unix';
      case RemoteOsType.windows:
        return 'Windows (OpenSSH)';
    }
  }
}

class RemoteHost {
  const RemoteHost({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password = '',
    this.customTSharkPath,
    this.defaultOutputDirectory = '/tmp/tshark_captures',
    this.useSudo = false,
    this.osType = RemoteOsType.auto,
    this.detectedTSharkVersion,
    this.isReachable,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String? customTSharkPath;
  final String defaultOutputDirectory;
  final bool useSudo;
  final RemoteOsType osType;
  final String? detectedTSharkVersion;
  final bool? isReachable;

  String get displayLabel => '$name ($host${port != 22 ? ':$port' : ''})';

  RemoteHost copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? customTSharkPath,
    String? defaultOutputDirectory,
    bool? useSudo,
    RemoteOsType? osType,
    String? detectedTSharkVersion,
    bool? isReachable,
  }) {
    return RemoteHost(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      customTSharkPath: customTSharkPath ?? this.customTSharkPath,
      defaultOutputDirectory: defaultOutputDirectory ?? this.defaultOutputDirectory,
      useSudo: useSudo ?? this.useSudo,
      osType: osType ?? this.osType,
      detectedTSharkVersion: detectedTSharkVersion ?? this.detectedTSharkVersion,
      isReachable: isReachable ?? this.isReachable,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'customTSharkPath': customTSharkPath,
        'defaultOutputDirectory': defaultOutputDirectory,
        'useSudo': useSudo,
        'osType': osType.name,
        if (detectedTSharkVersion != null) 'detectedTSharkVersion': detectedTSharkVersion,
      };

  factory RemoteHost.fromJson(Map<String, dynamic> json) {
    final osName = json['osType'] as String?;
    final os = RemoteOsType.values.firstWhere(
      (e) => e.name == osName,
      orElse: () => RemoteOsType.auto,
    );

    return RemoteHost(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Remote Host',
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 22,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      customTSharkPath: json['customTSharkPath'] as String?,
      defaultOutputDirectory:
          json['defaultOutputDirectory'] as String? ?? '/tmp/tshark_captures',
      useSudo: json['useSudo'] as bool? ?? false,
      osType: os,
      detectedTSharkVersion: json['detectedTSharkVersion'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteHost && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
