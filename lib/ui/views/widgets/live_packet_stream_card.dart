import 'package:material_ui/material_ui.dart';
import 'package:tshark_interface/models/demo_packet.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/ui/views/widgets/section_card.dart';

/// Displays decoded packet frames in a selectable list with protocol badges.
class LivePacketStreamCard extends StatelessWidget {
  const LivePacketStreamCard({
    super.key,
    required this.packets,
    required this.selectedPacket,
    required this.onSelectPacket,
  });

  final List<DemoPacket> packets;
  final DemoPacket? selectedPacket;
  final ValueChanged<DemoPacket> onSelectPacket;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Live Packet Stream',
      icon: Icons.view_list_outlined,
      trailing: packets.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${packets.length} Packets',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentEmerald,
                ),
              ),
            )
          : null,
      child: packets.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Center(
                child: Text(
                  'No live packets in stream. Start a capture or click "Load Demo" to preview decoded frames.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: packets.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: AppTheme.borderColor),
                itemBuilder: (context, index) {
                  final pkt = packets[index];
                  final isSelected = selectedPacket?.number == pkt.number;
                  return InkWell(
                    onTap: () => onSelectPacket(pkt),
                    child: Container(
                      color: isSelected
                          ? AppTheme.accentCyan.withValues(alpha: 0.15)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '#${pkt.number}',
                              style: AppTheme.monoTextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.accentCyan.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pkt.protocol,
                              style: AppTheme.monoTextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pkt.source} → ${pkt.destination} (${pkt.length} B)',
                                  style: AppTheme.monoTextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pkt.info,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Displays protocol dissection layers for the currently selected packet frame.
class PacketDissectionCard extends StatelessWidget {
  const PacketDissectionCard({
    super.key,
    required this.packet,
  });

  final DemoPacket packet;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Packet Dissection (Frame #${packet.number} • ${packet.protocol})',
      icon: Icons.account_tree_outlined,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: packet.dissectionLayers.map((layer) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      layer,
                      style: AppTheme.monoTextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
