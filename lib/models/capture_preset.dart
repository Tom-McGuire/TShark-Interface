import 'capture_config.dart';

class CapturePreset {
  const CapturePreset({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    this.filter = '',
    this.mode = CaptureMode.manual,
    this.snaplen = 0,
    this.ringFilesCount = 5,
    this.ringRotateMinutes = 10,
    this.ringRotateFilesizeMb = 100,
    this.ringRotateBySize = false,
    this.isBuiltIn = true,
  });

  final String id;
  final String title;
  final String description;
  final String iconName;
  final String filter;
  final CaptureMode mode;
  final int snaplen;
  final int ringFilesCount;
  final int ringRotateMinutes;
  final int ringRotateFilesizeMb;
  final bool ringRotateBySize;
  final bool isBuiltIn;

  static List<CapturePreset> get builtInPresets => [
        const CapturePreset(
          id: 'all_traffic',
          title: 'All Traffic',
          description: 'Captures all packets on the interface without any filtering.',
          iconName: 'all',
          filter: '',
          mode: CaptureMode.manual,
        ),
        const CapturePreset(
          id: 'exclude_mgmt',
          title: 'Exclude SSH & RDP',
          description: 'Suppresses administrative sessions (ports 22 & 3389) to prevent capture echo loops.',
          iconName: 'shield',
          filter: 'not port 22 and not port 3389',
          mode: CaptureMode.manual,
        ),
        const CapturePreset(
          id: 'web_traffic',
          title: 'Web Traffic',
          description: 'Captures standard HTTP, HTTPS, and alt web ports (80, 443, 8080, 8443).',
          iconName: 'globe',
          filter: 'tcp port 80 or tcp port 443 or tcp port 8080 or tcp port 8443',
          mode: CaptureMode.manual,
        ),
        const CapturePreset(
          id: 'dns_only',
          title: 'DNS Resolution',
          description: 'Captures UDP & TCP DNS queries and answers on port 53.',
          iconName: 'dns',
          filter: 'port 53',
          mode: CaptureMode.manual,
        ),
        const CapturePreset(
          id: 'dhcp_bootp',
          title: 'DHCP & BootP',
          description: 'Captures dynamic IP assignment and lease negotiation traffic (ports 67 & 68).',
          iconName: 'router',
          filter: 'port 67 or port 68',
          mode: CaptureMode.manual,
        ),
        const CapturePreset(
          id: 'icmp_ping',
          title: 'ICMP / Ping',
          description: 'Captures ICMP and ICMPv6 echo requests, replies, and unreachable notices.',
          iconName: 'pulse',
          filter: 'icmp or icmp6',
          mode: CaptureMode.manual,
        ),
        const CapturePreset(
          id: 'headers_only',
          title: 'Headers Only (96B)',
          description: 'Slices packets at 96 bytes. Retains IP/TCP/UDP headers while cutting large payloads to conserve space.',
          iconName: 'cut',
          filter: '',
          mode: CaptureMode.manual,
          snaplen: 96,
        ),
        const CapturePreset(
          id: 'rolling_24h',
          title: '24/7 Ring Buffer',
          description: 'Continuous ring buffer: rotates every 100MB and preserves the most recent 10 files.',
          iconName: 'loop',
          filter: 'not port 22 and not port 3389',
          mode: CaptureMode.ringBuffer,
          ringRotateFilesizeMb: 100,
          ringRotateBySize: true,
          ringFilesCount: 10,
        ),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'iconName': iconName,
        'filter': filter,
        'mode': mode.name,
        'snaplen': snaplen,
        'ringFilesCount': ringFilesCount,
        'ringRotateMinutes': ringRotateMinutes,
        'ringRotateFilesizeMb': ringRotateFilesizeMb,
        'ringRotateBySize': ringRotateBySize,
        'isBuiltIn': isBuiltIn,
      };

  factory CapturePreset.fromJson(Map<String, dynamic> json) {
    return CapturePreset(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'custom',
      filter: json['filter'] as String? ?? '',
      mode: CaptureMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => CaptureMode.manual,
      ),
      snaplen: json['snaplen'] as int? ?? 0,
      ringFilesCount: json['ringFilesCount'] as int? ?? 5,
      ringRotateMinutes: json['ringRotateMinutes'] as int? ?? 10,
      ringRotateFilesizeMb: json['ringRotateFilesizeMb'] as int? ?? 100,
      ringRotateBySize: json['ringRotateBySize'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }
}
