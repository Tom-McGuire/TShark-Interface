class DemoPacket {
  const DemoPacket({
    required this.number,
    required this.timestamp,
    required this.source,
    required this.destination,
    required this.protocol,
    required this.length,
    required this.info,
    required this.dissectionLayers,
  });

  final int number;
  final String timestamp;
  final String source;
  final String destination;
  final String protocol;
  final int length;
  final String info;
  final List<String> dissectionLayers;
}
