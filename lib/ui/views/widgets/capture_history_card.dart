import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tshark_interface/models/capture_history_item.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';

class CaptureHistoryCard extends StatelessWidget {
  const CaptureHistoryCard({
    super.key,
    required this.history,
    required this.onOpenFolder,
    required this.onOpenWireshark,
    required this.onRemove,
  });

  final List<CaptureHistoryItem> history;
  final ValueChanged<CaptureHistoryItem> onOpenFolder;
  final ValueChanged<CaptureHistoryItem> onOpenWireshark;
  final ValueChanged<CaptureHistoryItem> onRemove;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF13171F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.history_toggle_off, size: 28, color: Colors.white24),
              SizedBox(height: 8),
              Text(
                'No captures recorded in this session yet',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13171F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.length > 5 ? 5 : history.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.borderColor),
        itemBuilder: (context, index) {
          final item = history[index];
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.insert_drive_file_outlined, color: AppTheme.accentCyan, size: 20),
            title: Text(
              item.fileName,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${dateFormat.format(item.timestamp)} • ${item.formattedSize} • ${item.interfaceName}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 16, color: Colors.white70),
                  tooltip: 'Open in Explorer',
                  onPressed: () => onOpenFolder(item),
                ),
                IconButton(
                  icon: const Icon(Icons.launch, size: 16, color: AppTheme.accentCyan),
                  tooltip: 'Open in Wireshark',
                  onPressed: () => onOpenWireshark(item),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                  tooltip: 'Remove from History',
                  onPressed: () => onRemove(item),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
