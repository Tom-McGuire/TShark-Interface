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

  /// Sample decoded packets used by the interactive demo walkthrough.
  static const List<DemoPacket> samplePackets = [
    DemoPacket(
      number: 1,
      timestamp: '0.000000',
      source: '192.168.10.24',
      destination: '1.1.1.1',
      protocol: 'DNS',
      length: 78,
      info: 'Standard query 0x4a21 A api.internal.corp',
      dissectionLayers: [
        'Frame 1: 78 bytes on wire (624 bits), 78 bytes captured on interface eth0',
        'Ethernet II, Src: Dell_81:a2:09 (00:14:22:81:a2:09), Dst: Cisco_f0:01:01 (00:1b:54:f0:01:01)',
        'Internet Protocol Version 4, Src: 192.168.10.24, Dst: 1.1.1.1 (TTL: 64)',
        'User Datagram Protocol, Src Port: 54112, Dst Port: 53 (Length: 44)',
        'Domain Name System (query) • Transaction ID: 0x4a21 • Flags: 0x0100 Standard query',
      ],
    ),
    DemoPacket(
      number: 2,
      timestamp: '0.011420',
      source: '1.1.1.1',
      destination: '192.168.10.24',
      protocol: 'DNS',
      length: 94,
      info: 'Standard query response 0x4a21 A api.internal.corp A 10.20.4.15',
      dissectionLayers: [
        'Frame 2: 94 bytes on wire (752 bits), 94 bytes captured on interface eth0',
        'Ethernet II, Src: Cisco_f0:01:01 (00:1b:54:f0:01:01), Dst: Dell_81:a2:09 (00:14:22:81:a2:09)',
        'Internet Protocol Version 4, Src: 1.1.1.1, Dst: 192.168.10.24 (TTL: 57)',
        'User Datagram Protocol, Src Port: 53, Dst Port: 54112 (Length: 60)',
        'Domain Name System (response) • Answers: api.internal.corp: type A, class IN, addr 10.20.4.15',
      ],
    ),
    DemoPacket(
      number: 3,
      timestamp: '0.012105',
      source: '192.168.10.24',
      destination: '10.20.4.15',
      protocol: 'TCP',
      length: 74,
      info: '51822 → 443 [SYN] Seq=0 Win=64240 Len=0 MSS=1460 SACK_PERM TSval=298112',
      dissectionLayers: [
        'Frame 3: 74 bytes on wire (592 bits), 74 bytes captured on interface eth0',
        'Ethernet II, Src: Dell_81:a2:09 (00:14:22:81:a2:09), Dst: Cisco_f0:01:01 (00:1b:54:f0:01:01)',
        'Internet Protocol Version 4, Src: 192.168.10.24, Dst: 10.20.4.15 (DSCP: CS0, ECN: Not-ECT)',
        'Transmission Control Protocol, Src Port: 51822, Dst Port: 443, Seq: 0, Len: 0 [SYN]',
      ],
    ),
    DemoPacket(
      number: 4,
      timestamp: '0.024890',
      source: '10.20.4.15',
      destination: '192.168.10.24',
      protocol: 'TLSv1.3',
      length: 591,
      info: 'Server Hello, Change Cipher Spec, Application Data',
      dissectionLayers: [
        'Frame 4: 591 bytes on wire (4728 bits), 591 bytes captured on interface eth0',
        'Ethernet II, Src: Cisco_f0:01:01 (00:1b:54:f0:01:01), Dst: Dell_81:a2:09 (00:14:22:81:a2:09)',
        'Internet Protocol Version 4, Src: 10.20.4.15, Dst: 192.168.10.24',
        'Transmission Control Protocol, Src Port: 443, Dst Port: 51822, Seq: 1, Ack: 518, Len: 525',
        'Transport Layer Security • TLSv1.3 Record Layer: Handshake Protocol: Server Hello (Cipher: TLS_AES_256_GCM_SHA384)',
      ],
    ),
    DemoPacket(
      number: 5,
      timestamp: '0.089412',
      source: '192.168.10.1',
      destination: '224.0.0.18',
      protocol: 'VRRP',
      length: 60,
      info: 'Announcement (v2) VRID=10 Prio=110 IP=192.168.10.254',
      dissectionLayers: [
        'Frame 5: 60 bytes on wire (480 bits), 60 bytes captured on interface eth0',
        'Ethernet II, Src: Vrrp_00:01:0a (00:00:5e:00:01:0a), Dst: IPv4mcast_12 (01:00:5e:00:00:12)',
        'Internet Protocol Version 4, Src: 192.168.10.1, Dst: 224.0.0.18 (TTL: 255)',
        'Virtual Router Redundancy Protocol, Version 2, Packet Type 1 (Advertisement), VRID: 10, Priority: 110',
      ],
    ),
  ];
}
