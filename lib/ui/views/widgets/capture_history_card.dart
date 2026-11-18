import 'package:material_ui/material_ui.dart';
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
    this.onLoadDemo,
  });

  final List<CaptureHistoryItem> history;
  final ValueChanged<CaptureHistoryItem> onOpenFolder;
  final ValueChanged<CaptureHistoryItem> onOpenWireshark;
  final ValueChanged<CaptureHistoryItem> onRemove;
  final VoidCallback? onLoadDemo;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_toggle_off, size: 28, color: AppTheme.textMuted),
              const SizedBox(height: 8),
              Text(
                'No captures recorded in this session yet',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              if (onLoadDemo != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onLoadDemo,
                  icon: const Icon(Icons.play_circle_outline, size: 15),
                  label: const Text('Load Demo', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.length > 5 ? 5 : history.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.borderColor),
        itemBuilder: (context, index) {
          final item = history[index];
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.insert_drive_file_outlined, color: AppTheme.accentCyan, size: 20),
            title: Text(
              item.fileName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${dateFormat.format(item.timestamp)} • ${item.formattedSize} • ${item.interfaceName}',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.folder_open, size: 16, color: AppTheme.textPrimary),
                  tooltip: 'Open in Explorer',
                  onPressed: () => onOpenFolder(item),
                ),
                IconButton(
                  icon: Icon(Icons.launch, size: 16, color: AppTheme.accentCyan),
                  tooltip: 'Open in Wireshark',
                  onPressed: () => onOpenWireshark(item),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: AppTheme.textMuted),
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
