/// Startup network adapter pre-selection configuration parsed from CLI flags.
class LaunchAdapterConfig {
  const LaunchAdapterConfig({
    this.adapterIp,
    this.adapterName,
  });

  final String? adapterIp;
  final String? adapterName;

  /// Whether either `--adapter-ip` or `--adapter-name` has a non-empty override.
  bool get hasAdapterOverride =>
      (adapterIp != null && adapterIp!.trim().isNotEmpty) ||
      (adapterName != null && adapterName!.trim().isNotEmpty);

  /// Alias for [hasAdapterOverride].
  bool get hasOverride => hasAdapterOverride;

  /// Parses `--adapter-ip` and `--adapter-name` arguments in `--flag value` or
  /// `--flag=value` forms, trimming whitespace and treating empty values as `null`.
  factory LaunchAdapterConfig.fromArgs(List<String> args) {
    String? ip;
    String? name;

    String? normalize(String raw) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--adapter-ip' && i + 1 < args.length) {
        ip = normalize(args[i + 1]);
        i++;
      } else if (arg.startsWith('--adapter-ip=')) {
        ip = normalize(arg.substring('--adapter-ip='.length));
      } else if (arg == '--adapter-name' && i + 1 < args.length) {
        name = normalize(args[i + 1]);
        i++;
      } else if (arg.startsWith('--adapter-name=')) {
        name = normalize(arg.substring('--adapter-name='.length));
      }
    }

    return LaunchAdapterConfig(
      adapterIp: ip,
      adapterName: name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaunchAdapterConfig &&
          runtimeType == other.runtimeType &&
          adapterIp == other.adapterIp &&
          adapterName == other.adapterName;

  @override
  int get hashCode => Object.hash(adapterIp, adapterName);

  @override
  String toString() =>
      'LaunchAdapterConfig(adapterIp: $adapterIp, adapterName: $adapterName)';
}
