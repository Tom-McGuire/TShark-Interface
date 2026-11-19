import '../models/capture_interface.dart';
import '../models/launch_adapter_config.dart';

/// Resolves a CLI-specified [LaunchAdapterConfig] against available capture
/// interfaces using IPv4 priority matching followed by name matching.
class AdapterMatcher {
  AdapterMatcher._();

  /// Matches [config] against [available] capture interfaces by Priority 1
  /// (IPv4 match), then Priority 2 (name/substring match).
  static CaptureInterface? match(
    List<CaptureInterface> available,
    LaunchAdapterConfig config, {
    Map<String, List<String>>? osInterfaceIps,
  }) {
    if (available.isEmpty || !config.hasAdapterOverride) {
      return null;
    }

    final targetIp = config.adapterIp?.trim();
    if (targetIp != null && targetIp.isNotEmpty) {
      final ipMatch = _matchByIp(available, targetIp, osInterfaceIps);
      if (ipMatch != null) return ipMatch;
    }

    final targetName = config.adapterName?.trim();
    if (targetName != null && targetName.isNotEmpty) {
      return _matchByName(available, targetName);
    }

    return null;
  }

  static CaptureInterface? _matchByIp(
    List<CaptureInterface> available,
    String targetIp,
    Map<String, List<String>>? osInterfaceIps,
  ) {
    for (final iface in available) {
      if (iface.ipv4Addresses.any((ip) => ip.trim() == targetIp) ||
          iface.name.trim() == targetIp) {
        return iface;
      }
    }

    final ipPattern = RegExp(
      '(^|[^0-9])${RegExp.escape(targetIp)}([^0-9]|\$)',
    );
    for (final iface in available) {
      final desc = iface.description;
      if (desc != null && ipPattern.hasMatch(desc)) {
        return iface;
      }
    }

    if (osInterfaceIps == null || osInterfaceIps.isEmpty) {
      return null;
    }

    final matchingOsNames = <String>{};
    for (final entry in osInterfaceIps.entries) {
      if (entry.value.any((ip) => ip.trim() == targetIp)) {
        final osName = entry.key.trim().toLowerCase();
        if (osName.isNotEmpty) {
          matchingOsNames.add(osName);
        }
      }
    }
    if (matchingOsNames.isEmpty) return null;

    // Exact case-insensitive match on interface name or friendly name first.
    for (final osName in matchingOsNames) {
      for (final iface in available) {
        if (iface.name.trim().toLowerCase() == osName ||
            iface.friendlyName?.trim().toLowerCase() == osName) {
          return iface;
        }
      }
    }

    // Substring fallback when OS name differs slightly from tshark label.
    for (final osName in matchingOsNames) {
      for (final iface in available) {
        final nameLower = iface.name.trim().toLowerCase();
        final friendlyLower = iface.friendlyName?.trim().toLowerCase();
        if (nameLower.contains(osName) ||
            (friendlyLower != null && friendlyLower.contains(osName)) ||
            (friendlyLower != null &&
                friendlyLower.length >= 4 &&
                osName.contains(friendlyLower))) {
          return iface;
        }
      }
    }

    return null;
  }

  static CaptureInterface? _matchByName(
    List<CaptureInterface> available,
    String targetName,
  ) {
    final needle = targetName.toLowerCase();

    for (final iface in available) {
      if (iface.name.trim().toLowerCase() == needle ||
          iface.friendlyName?.trim().toLowerCase() == needle) {
        return iface;
      }
    }

    for (final iface in available) {
      if (iface.name.toLowerCase().contains(needle) ||
          (iface.friendlyName?.toLowerCase().contains(needle) ?? false) ||
          iface.displayName.toLowerCase().contains(needle)) {
        return iface;
      }
    }

    return null;
  }
}
