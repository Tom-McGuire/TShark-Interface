class CaptureInterface {
  const CaptureInterface({
    required this.index,
    required this.name,
    this.friendlyName,
    this.description,
    this.ipv4Addresses = const [],
  });

  final String index;
  final String name;
  final String? friendlyName;
  final String? description;
  final List<String> ipv4Addresses;

  CaptureInterface copyWith({
    String? index,
    String? name,
    String? friendlyName,
    String? description,
    List<String>? ipv4Addresses,
  }) {
    return CaptureInterface(
      index: index ?? this.index,
      name: name ?? this.name,
      friendlyName: friendlyName ?? this.friendlyName,
      description: description ?? this.description,
      ipv4Addresses: ipv4Addresses ?? this.ipv4Addresses,
    );
  }

  String get displayName {
    if (friendlyName != null && friendlyName!.isNotEmpty) {
      return '$index. $friendlyName';
    }
    return '$index. $name';
  }

  String get subtitle {
    if (friendlyName != null && friendlyName!.isNotEmpty) {
      return name;
    }
    return description ?? 'Interface #$index';
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'name': name,
        'friendlyName': friendlyName,
        'description': description,
        'ipv4Addresses': ipv4Addresses,
      };

  factory CaptureInterface.fromJson(Map<String, dynamic> json) {
    return CaptureInterface(
      index: json['index'] as String? ?? '1',
      name: json['name'] as String? ?? '',
      friendlyName: json['friendlyName'] as String?,
      description: json['description'] as String?,
      ipv4Addresses: (json['ipv4Addresses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureInterface &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          name == other.name;

  @override
  int get hashCode => index.hashCode ^ name.hashCode;
}
