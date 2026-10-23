import 'package:flutter/material.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';

class CapturePresetsBar extends StatelessWidget {
  const CapturePresetsBar({
    super.key,
    required this.presets,
    required this.activePresetId,
    required this.onSelectPreset,
  });

  final List<CapturePreset> presets;
  final String? activePresetId;
  final ValueChanged<CapturePreset> onSelectPreset;

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'all':
        return Icons.all_inclusive;
      case 'shield':
        return Icons.security;
      case 'globe':
        return Icons.language;
      case 'dns':
        return Icons.dns;
      case 'router':
        return Icons.router;
      case 'pulse':
        return Icons.graphic_eq;
      case 'cut':
        return Icons.content_cut;
      case 'loop':
        return Icons.loop;
      default:
        return Icons.tune;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on, size: 16, color: AppTheme.accentAmber),
            const SizedBox(width: 6),
            const Text(
              'Quick Presets',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Click a preset to configure common filters and modes automatically',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isSelected = preset.id == activePresetId;

              return Tooltip(
                message:
                    '${preset.title}\n${preset.description}\n${preset.filter.isNotEmpty ? "Filter: ${preset.filter}" : "No filter"}',
                padding: const EdgeInsets.all(8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getIcon(preset.iconName),
                        size: 14,
                        color: isSelected ? Colors.black : AppTheme.accentCyan,
                      ),
                      const SizedBox(width: 6),
                      Text(preset.title),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      onSelectPreset(preset);
                    }
                  },
                  selectedColor: AppTheme.accentCyan,
                  backgroundColor: const Color(0xFF161B24),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppTheme.accentCyan : AppTheme.borderColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
