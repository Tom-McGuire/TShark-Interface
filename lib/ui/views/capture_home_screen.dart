import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';
import 'dialogs/settings_dialog.dart';
import 'widgets/active_capture_banner.dart';
import 'widgets/capture_filter_input.dart';
import 'widgets/capture_history_card.dart';
import 'widgets/capture_presets_bar.dart';
import 'widgets/command_preview_card.dart';

class CaptureHomeScreen extends StatefulWidget {
  const CaptureHomeScreen({super.key});

  @override
  State<CaptureHomeScreen> createState() => _CaptureHomeScreenState();
}

class _CaptureHomeScreenState extends State<CaptureHomeScreen> {
  final _filePrefixController = TextEditingController();
  final _packetLimitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final vm = context.read<TSharkCaptureViewModel>();
    _filePrefixController.text = vm.filePrefix;
    _packetLimitController.text = vm.packetCountLimit.toString();
  }

  @override
  void dispose() {
    _filePrefixController.dispose();
    _packetLimitController.dispose();
    super.dispose();
  }

  Future<void> _pickOutputFolder(TSharkCaptureViewModel vm) async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Capture Storage Directory',
      initialDirectory: vm.outputDirectory.isNotEmpty ? vm.outputDirectory : null,
    );
    if (selected != null && selected.isNotEmpty) {
      vm.setOutputDirectory(selected);
    }
  }

  void _openSettings(BuildContext context, TSharkCaptureViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(viewModel: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TSharkCaptureViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF13171F),
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.waves, color: AppTheme.accentCyan, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'T-Shark Interface',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Headless Packet Capture Studio',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Engine Status Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: vm.hasTShark
                  ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                  : AppTheme.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: vm.hasTShark
                    ? AppTheme.accentEmerald.withValues(alpha: 0.4)
                    : AppTheme.accentAmber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  vm.hasTShark ? Icons.check_circle : Icons.warning_amber,
                  size: 14,
                  color: vm.hasTShark ? AppTheme.accentEmerald : AppTheme.accentAmber,
                ),
                const SizedBox(width: 6),
                Text(
                  vm.hasTShark ? 'Engine Ready' : 'TShark Not Found',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: vm.hasTShark ? AppTheme.accentEmerald : AppTheme.accentAmber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Engine & Output Settings',
            onPressed: () => _openSettings(context, vm),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.borderColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Capture Banner (if running)
              if (vm.isCapturing && vm.activeSession != null) ...[
                ActiveCaptureBanner(
                  session: vm.activeSession!,
                  elapsed: vm.elapsed,
                  fileSizeBytes: vm.currentCaptureSizeBytes,
                  isStopping: vm.isLoading,
                  onStop: () => vm.stopCapture(),
                ),
                const SizedBox(height: 18),
              ],

              // Notice / Error Banners
              if (vm.errorMessage != null) ...[
                _buildAlertBanner(
                  message: vm.errorMessage!,
                  color: AppTheme.accentRed,
                  icon: Icons.error_outline,
                  onDismiss: () => vm.clearError(),
                ),
                const SizedBox(height: 16),
              ],
              if (vm.statusMessage != null) ...[
                _buildAlertBanner(
                  message: vm.statusMessage!,
                  color: AppTheme.accentEmerald,
                  icon: Icons.check_circle_outline,
                  onDismiss: () => vm.clearStatus(),
                ),
                const SizedBox(height: 16),
              ],

              // Quick Presets Bar
              CapturePresetsBar(
                presets: vm.presets,
                activePresetId: vm.activePresetId,
                onSelectPreset: (CapturePreset preset) {
                  vm.applyPreset(preset);
                  _packetLimitController.text = vm.packetCountLimit.toString();
                },
              ),
              const SizedBox(height: 18),

              // Two Columns Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Configuration Controls
                      Expanded(
                        flex: isWide ? 6 : 1,
                        child: _buildConfigurationColumn(context, vm),
                      ),
                      if (isWide) const SizedBox(width: 20),
                      // Right Column: Preview, Actions & History
                      if (isWide)
                        Expanded(
                          flex: 5,
                          child: _buildRightColumn(context, vm),
                        ),
                    ],
                  );
                },
              ),

              // If screen is narrow, show right column underneath
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildRightColumn(context, vm),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertBanner({
    required String message,
    required Color color,
    required IconData icon,
    required VoidCallback onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: color,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationColumn(BuildContext context, TSharkCaptureViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card: Capture Target
        _buildSectionCard(
          title: 'Capture Target & Interface',
          icon: Icons.settings_ethernet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<CaptureInterface>(
                      initialValue: vm.selectedInterface,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Network Interface',
                        prefixIcon: Icon(Icons.router_outlined, size: 18),
                      ),
                      items: vm.interfaces.map((iface) {
                        return DropdownMenuItem<CaptureInterface>(
                          value: iface,
                          child: Text(
                            iface.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: vm.isCapturing ? null : (val) => vm.setSelectedInterface(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: vm.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Refresh Network Interfaces',
                    onPressed: vm.isCapturing ? null : () => vm.refreshInterfaces(),
                  ),
                ],
              ),
              if (vm.selectedInterface?.friendlyName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Physical/Device: ${vm.selectedInterface!.name}',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card: Filter & Mode
        _buildSectionCard(
          title: 'Traffic Filter & Capture Mode',
          icon: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BPF Filter
              CaptureFilterInput(
                filter: vm.captureFilter,
                onChanged: (val) => vm.setCaptureFilter(val),
              ),
              const SizedBox(height: 16),

              // Mode Tabs
              const Text(
                'Capture Mode',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
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
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.accentCyan.withValues(alpha: 0.2);
                    }
                    return const Color(0xFF161B24);
                  }),
                ),
              ),
              const SizedBox(height: 14),

              // Mode-specific parameter controls
              _buildModeParameters(vm),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card: Advanced Tuning & Storage
        _buildSectionCard(
          title: 'Packet Slicing & Storage Destination',
          icon: Icons.folder_zip_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Snaplen / Payload Slicing
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Packet Slice (Snaplen)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Truncates payload to reduce PCAP file size.',
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<int>(
                    value: vm.snaplen,
                    dropdownColor: const Color(0xFF1F242C),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Full Packets (Default)')),
                      DropdownMenuItem(value: 64, child: Text('64 Bytes (L2-L3 Only)')),
                      DropdownMenuItem(value: 96, child: Text('96 Bytes (Headers Only)')),
                      DropdownMenuItem(value: 128, child: Text('128 Bytes (Headers+TOS)')),
                      DropdownMenuItem(value: 256, child: Text('256 Bytes')),
                    ],
                    onChanged: vm.isCapturing ? null : (val) => vm.setSnaplen(val ?? 0),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Promiscuous Mode
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Promiscuous Mode', style: TextStyle(fontSize: 12.5)),
                subtitle: const Text(
                  'Captures all network packets seen on the segment, not just packets addressed to this host.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                value: vm.promiscuous,
                onChanged: vm.isCapturing ? null : (val) => vm.setPromiscuous(val),
                activeThumbColor: AppTheme.accentCyan,
              ),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Output Storage Directory
              const Text(
                'Destination Storage Folder',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13171F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        vm.outputDirectory.isNotEmpty ? vm.outputDirectory : 'No directory chosen',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isCapturing ? null : () => _pickOutputFolder(vm),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Change'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentCyan,
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // File Prefix & Subfolder Checkbox
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _filePrefixController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'File Prefix',
                        hintText: 'capture',
                      ),
                      onChanged: (val) => vm.setFilePrefix(val),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Timestamp Subfolder', style: TextStyle(fontSize: 12)),
                      value: vm.createSubfolder,
                      onChanged: vm.isCapturing ? null : (val) => vm.setCreateSubfolder(val ?? true),
                      activeColor: AppTheme.accentCyan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeParameters(TSharkCaptureViewModel vm) {
    switch (vm.mode) {
      case CaptureMode.manual:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF13171F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Continuous manual capture. Will record to PCAPNG until you click "Stop Capture".',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
              ),
            ],
          ),
        );

      case CaptureMode.timed:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF13171F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto-stop Duration',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text('Hours: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        DropdownButton<int>(
                          value: vm.durationHours,
                          dropdownColor: const Color(0xFF1F242C),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          items: List.generate(25, (i) => DropdownMenuItem(value: i, child: Text('$i h'))),
                          onChanged: vm.isCapturing ? null : (val) => vm.setDurationHours(val ?? 0),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Text('Minutes: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        DropdownButton<int>(
                          value: vm.durationMinutes,
                          dropdownColor: const Color(0xFF1F242C),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          items: [1, 2, 5, 10, 15, 20, 30, 45, 60]
                              .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                              .toList(),
                          onChanged: vm.isCapturing ? null : (val) => vm.setDurationMinutes(val ?? 10),
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
            color: const Color(0xFF13171F),
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
                      vm.ringRotateBySize ? 'Rotate Every (MB)' : 'Rotate Every (Minutes)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('By Size', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      Switch(
                        value: vm.ringRotateBySize,
                        onChanged: vm.isCapturing ? null : (val) => vm.setRingRotateBySize(val),
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
                            dropdownColor: const Color(0xFF1F242C),
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            items: [10, 25, 50, 100, 250, 500, 1000]
                                .map((mb) => DropdownMenuItem(value: mb, child: Text('$mb MB per file')))
                                .toList(),
                            onChanged: vm.isCapturing ? null : (val) => vm.setRingRotateFilesizeMb(val ?? 100),
                          )
                        : DropdownButton<int>(
                            value: vm.ringRotateMinutes,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1F242C),
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            items: [1, 5, 10, 15, 30, 60]
                                .map((m) => DropdownMenuItem(value: m, child: Text('$m minutes per file')))
                                .toList(),
                            onChanged: vm.isCapturing ? null : (val) => vm.setRingRotateMinutes(val ?? 10),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        const Text('Keep: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        DropdownButton<int>(
                          value: vm.ringFilesCount,
                          dropdownColor: const Color(0xFF1F242C),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          items: [2, 3, 5, 10, 20, 50]
                              .map((c) => DropdownMenuItem(value: c, child: Text('$c files max')))
                              .toList(),
                          onChanged: vm.isCapturing ? null : (val) => vm.setRingFilesCount(val ?? 5),
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
            color: const Color(0xFF13171F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stop after Packet Count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _packetLimitController,
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

  Widget _buildRightColumn(BuildContext context, TSharkCaptureViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Button: Start Capture
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: (vm.isCapturing || !vm.hasTShark || vm.isLoading)
                    ? null
                    : () => vm.startCapture(),
                icon: const Icon(Icons.play_arrow, size: 22),
                label: Text(
                  vm.isCapturing
                      ? 'Capture Already Active'
                      : (vm.runDetached ? 'Start Headless Capture' : 'Start Capture'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (!vm.hasTShark) ...[
                const SizedBox(height: 8),
                const Text(
                  'Wireshark / TShark executable is required to start captures.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.accentAmber),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Command Line Preview Card
        CommandPreviewCard(
          commandLine: vm.previewCommandLine,
          runDetached: vm.runDetached,
          onDetachedChanged: (val) => vm.setRunDetached(val),
        ),
        const SizedBox(height: 16),

        // Capture Vault / History Card
        _buildSectionCard(
          title: 'Recent Capture Vault',
          icon: Icons.history,
          trailing: vm.history.isNotEmpty
              ? TextButton.icon(
                  onPressed: () => vm.openActiveDirectory(),
                  icon: const Icon(Icons.folder_open, size: 14),
                  label: const Text('Open Storage Folder', style: TextStyle(fontSize: 11)),
                )
              : null,
          child: CaptureHistoryCard(
            history: vm.history,
            onOpenFolder: (item) => vm.openHistoryItemFolder(item),
            onOpenWireshark: (item) => vm.openHistoryItemInWireshark(item),
            onRemove: (item) => vm.removeHistoryItem(item),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.accentCyan),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: child,
          ),
        ],
      ),
    );
  }
}
