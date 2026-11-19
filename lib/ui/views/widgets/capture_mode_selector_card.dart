import 'package:material_ui/material_ui.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/ui/views/widgets/capture_filter_input.dart';
import 'package:tshark_interface/ui/views/widgets/section_card.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

/// Configuration card for BPF capture filter input, capture mode selection,
/// and mode-specific parameters (timed duration, ring buffer, packet count limit).
class CaptureModeSelectorCard extends StatefulWidget {
  const CaptureModeSelectorCard({
    super.key,
    required this.vm,
  });

  final TSharkCaptureViewModel vm;

  @override
  State<CaptureModeSelectorCard> createState() =>
      _CaptureModeSelectorCardState();
}

class _CaptureModeSelectorCardState extends State<CaptureModeSelectorCard> {
  final _packetLimitController = TextEditingController();
  final _packetLimitFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _packetLimitController.text = widget.vm.packetCountLimit.toString();
    _packetLimitFocusNode.addListener(_syncPacketLimitIfUnfocused);
  }

  @override
  void dispose() {
    _packetLimitFocusNode.removeListener(_syncPacketLimitIfUnfocused);
    _packetLimitFocusNode.dispose();
    _packetLimitController.dispose();
    super.dispose();
  }

  void _syncPacketLimitIfUnfocused() {
    if (!mounted) return;
    final expectedLimit = widget.vm.packetCountLimit.toString();
    if (!_packetLimitFocusNode.hasFocus &&
        _packetLimitController.text != expectedLimit) {
      _packetLimitController.text = expectedLimit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    _syncPacketLimitIfUnfocused();

    return SectionCard(
      title: 'Traffic Filter & Capture Mode',
      icon: Icons.tune,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BPF Filter
          CaptureFilterInput(
            filter: vm.captureFilter,
            enabled: !vm.isCapturing,
            onChanged: (val) => vm.setCaptureFilter(val),
          ),
          const SizedBox(height: 16),

          // Mode Tabs
          Text(
            'Capture Mode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<CaptureMode>(
            segments: const [
              ButtonSegment(
                value: CaptureMode.manual,
                label: Text('Manual', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.touch_app, size: 16),
              ),
              ButtonSegment(
                value: CaptureMode.timed,
                label: Text('Timed', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.timer_outlined, size: 16),
              ),
              ButtonSegment(
                value: CaptureMode.ringBuffer,
                label: Text('Ring Buffer', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.loop, size: 16),
              ),
              ButtonSegment(
                value: CaptureMode.packetCount,
                label: Text('Limit', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.format_list_numbered, size: 16),
              ),
            ],
            selected: {vm.mode},
            onSelectionChanged: vm.isCapturing
                ? null
                : (selection) {
                    vm.setMode(selection.first);
                  },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppTheme.textMuted;
                }
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.textPrimary;
                }
                return AppTheme.textSecondary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.accentCyan.withValues(alpha: 0.2);
                }
                return AppTheme.surface;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Mode-specific parameter controls
          _buildModeParameters(vm),
        ],
      ),
    );
  }

  Widget _buildModeParameters(TSharkCaptureViewModel vm) {
    switch (vm.mode) {
      case CaptureMode.manual:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Continuous manual capture. Will record to PCAPNG until you click "Stop Capture".',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
        );

      case CaptureMode.timed:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto-stop Duration',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Hours: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        DropdownButton<int>(
                          value: vm.durationHours,
                          dropdownColor: AppTheme.surfaceElevated,
                          iconEnabledColor: AppTheme.textSecondary,
                          iconDisabledColor: AppTheme.textMuted,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                          items: List.generate(
                            25,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('$i h'),
                            ),
                          ),
                          onChanged: vm.isCapturing
                              ? null
                              : (val) => vm.setDurationHours(val ?? 0),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Minutes: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        DropdownButton<int>(
                          value: vm.durationMinutes,
                          dropdownColor: AppTheme.surfaceElevated,
                          iconEnabledColor: AppTheme.textSecondary,
                          iconDisabledColor: AppTheme.textMuted,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                          items: [1, 2, 5, 10, 15, 20, 30, 45, 60]
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m min'),
                                ),
                              )
                              .toList(),
                          onChanged: vm.isCapturing
                              ? null
                              : (val) => vm.setDurationMinutes(val ?? 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case CaptureMode.ringBuffer:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vm.ringRotateBySize
                          ? 'Rotate Every (MB)'
                          : 'Rotate Every (Minutes)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'By Size',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Switch(
                        value: vm.ringRotateBySize,
                        onChanged: vm.isCapturing
                            ? null
                            : (val) => vm.setRingRotateBySize(val),
                        activeThumbColor: AppTheme.accentCyan,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: vm.ringRotateBySize
                        ? DropdownButton<int>(
                            value: vm.ringRotateFilesizeMb,
                            isExpanded: true,
                            dropdownColor: AppTheme.surfaceElevated,
                            iconEnabledColor: AppTheme.textSecondary,
                            iconDisabledColor: AppTheme.textMuted,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                            ),
                            items: [10, 25, 50, 100, 250, 500, 1000]
                                .map(
                                  (mb) => DropdownMenuItem(
                                    value: mb,
                                    child: Text('$mb MB per file'),
                                  ),
                                )
                                .toList(),
                            onChanged: vm.isCapturing
                                ? null
                                : (val) =>
                                    vm.setRingRotateFilesizeMb(val ?? 100),
                          )
                        : DropdownButton<int>(
                            value: vm.ringRotateMinutes,
                            isExpanded: true,
                            dropdownColor: AppTheme.surfaceElevated,
                            iconEnabledColor: AppTheme.textSecondary,
                            iconDisabledColor: AppTheme.textMuted,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                            ),
                            items: [1, 5, 10, 15, 30, 60]
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text('$m minutes per file'),
                                  ),
                                )
                                .toList(),
                            onChanged: vm.isCapturing
                                ? null
                                : (val) => vm.setRingRotateMinutes(val ?? 10),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Keep: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        DropdownButton<int>(
                          value: vm.ringFilesCount,
                          dropdownColor: AppTheme.surfaceElevated,
                          iconEnabledColor: AppTheme.textSecondary,
                          iconDisabledColor: AppTheme.textMuted,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                          items: [2, 3, 5, 10, 20, 50]
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('$c files max'),
                                ),
                              )
                              .toList(),
                          onChanged: vm.isCapturing
                              ? null
                              : (val) => vm.setRingFilesCount(val ?? 5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case CaptureMode.packetCount:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stop after Packet Count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _packetLimitController,
                      focusNode: _packetLimitFocusNode,
                      enabled: !vm.isCapturing,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: '10000',
                        suffixText: 'packets',
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) vm.setPacketCountLimit(parsed);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}
