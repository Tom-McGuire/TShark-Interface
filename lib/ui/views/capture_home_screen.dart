import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/models/remote_host.dart';
import 'package:tshark_interface/services/system_service.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/ui/widgets/guided_tour_overlay.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

import 'dialogs/settings_dialog.dart';
import 'widgets/active_capture_banner.dart';
import 'widgets/capture_history_card.dart';
import 'widgets/capture_mode_selector_card.dart';
import 'widgets/capture_presets_bar.dart';
import 'widgets/command_preview_card.dart';
import 'widgets/interrupted_capture_banner.dart';
import 'widgets/live_packet_stream_card.dart';
import 'widgets/remote_hosts_tab.dart';
import 'widgets/section_card.dart';
import 'widgets/storage_and_recovery_card.dart';
import 'widgets/top_control_bar.dart';

class CaptureHomeScreen extends StatefulWidget {
  const CaptureHomeScreen({super.key});

  @override
  State<CaptureHomeScreen> createState() => _CaptureHomeScreenState();
}

class _CaptureHomeScreenState extends State<CaptureHomeScreen> {
  // Spotlight Tour Keys & State
  bool _isTourActive = false;
  final GlobalKey _zone2TargetInterfaceKey = GlobalKey();
  final GlobalKey _zone3StartStopKey = GlobalKey();
  final GlobalKey _presetsAndFiltersKey = GlobalKey();
  final GlobalKey _livePacketTableKey = GlobalKey();
  final GlobalKey _packetDissectionExportKey = GlobalKey();

  Future<void> _pickOutputFolder(TSharkCaptureViewModel vm) async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Capture Storage Directory',
      initialDirectory:
          vm.outputDirectory.isNotEmpty ? vm.outputDirectory : null,
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

  Future<void> _openRemoteHostsDialog(
    BuildContext context,
    TSharkCaptureViewModel vm,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 950,
              maxHeight: 700,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        color: AppTheme.accentCyan,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Remote SSH Hosts Management',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: RemoteHostsTab(
                      viewModel: vm,
                      onSelectHostForCapture: (RemoteHost host) async {
                        Navigator.of(dialogCtx).pop();
                        await vm.selectTargetHost(host);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void startDemoWalkthrough(TSharkCaptureViewModel vm) {
    vm.loadDemoWalkthroughData();
    setState(() {
      _isTourActive = true;
    });
  }

  void endDemoWalkthrough(TSharkCaptureViewModel vm) {
    setState(() {
      _isTourActive = false;
    });
    vm.clearCapture();
  }

  List<GuidedTourStep> _buildTourSteps(TSharkCaptureViewModel vm) {
    return [
      GuidedTourStep(
        targetKey: _zone2TargetInterfaceKey,
        title: 'Zone 2: Interface, Target & Remote Capture',
        description:
            'Choose the local TShark capture interface, switch between Localhost and remote SSH capture hosts, or refresh network adapters.',
      ),
      GuidedTourStep(
        targetKey: _zone3StartStopKey,
        title: 'Zone 3: Start / Stop Live Capture',
        description:
            'Launch the underlying tshark capture engine with real-time packet streaming or headless ring-buffer recording.',
      ),
      GuidedTourStep(
        targetKey: _presetsAndFiltersKey,
        title: 'Capture Presets & Display Filters',
        description:
            'Apply one-click diagnostic filter presets (e.g., Exclude SSH/RDP, Web Traffic, DNS & DHCP) or enter custom BPF capture filters.',
      ),
      GuidedTourStep(
        targetKey: _livePacketTableKey,
        title: 'Live Packet Stream Table',
        description:
            'Inspect live captured frames as they arrive in real time, including source/destination IPs, protocol badges, frame sizes, and summary info.',
        onStepEnter: () {
          if (vm.demoPackets.isNotEmpty) {
            vm.selectDemoPacket(vm.demoPackets.first);
          }
        },
      ),
      GuidedTourStep(
        targetKey: _packetDissectionExportKey,
        title: 'Packet Dissection & PCAP Export',
        description:
            'View detailed protocol frame layers for the selected packet, preview the exact TShark CLI invocation, copy commands, or open saved captures in Wireshark.',
      ),
    ];
  }

  void _clearCaptureSettings(TSharkCaptureViewModel vm) {
    vm.clearCapture();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Capture filters and limits cleared to defaults.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleExportSelection(String value, TSharkCaptureViewModel vm) {
    if (value == 'open_folder') {
      vm.openActiveDirectory();
    } else if (value == 'copy_cmd') {
      SystemService.copyToClipboard(vm.previewCommandLine);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command line copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TSharkCaptureViewModel>();

    return GuidedTourOverlay(
      isActive: _isTourActive,
      steps: _buildTourSteps(vm),
      onFinish: () => endDemoWalkthrough(vm),
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              TopControlBar(
                vm: vm,
                zone2TargetInterfaceKey: _zone2TargetInterfaceKey,
                zone3StartStopKey: _zone3StartStopKey,
                onOpenRemoteHosts: () => _openRemoteHostsDialog(context, vm),
                onStartDemo: () => startDemoWalkthrough(vm),
                onEndDemo: () => endDemoWalkthrough(vm),
                onClearSettings: () => _clearCaptureSettings(vm),
                onExportSelected: (val) => _handleExportSelection(val, vm),
                onOpenSettings: () => _openSettings(context, vm),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCaptureStudioBody(context, vm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureStudioBody(
    BuildContext context,
    TSharkCaptureViewModel vm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Unreachable Remote Sessions Warning Banner (with Retry & Clear/Forget buttons)
        ...vm.unreachableRemoteSessions.map((session) {
          final hostId = session.remoteHostId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildUnreachableRemoteBanner(session, hostId, vm),
          );
        }),

        // Interrupted Capture Banner (if local machine rebooted or unexpected shutdown)
        if (vm.interruptedSession != null) ...[
          InterruptedCaptureBanner(
            session: vm.interruptedSession!,
            onResume: () => vm.resumeInterruptedCapture(),
            onLoadSettings: () => vm.loadInterruptedSettings(),
            onDismiss: () => vm.dismissInterruptedSession(),
          ),
          const SizedBox(height: 18),
        ],

        // Active Capture Banner (if running on selected target machine)
        if (vm.isCapturing && vm.activeSession != null) ...[
          ActiveCaptureBanner(
            session: vm.activeSession!,
            elapsed: vm.elapsed,
            fileSizeBytes: vm.currentCaptureSizeBytes,
            isStopping: vm.isLoading,
            onStop: () => vm.stopCapture(),
            onClearRemoteSession: vm.activeSession!.isRemote &&
                    vm.activeSession!.remoteHostId != null
                ? () => vm.clearRemoteSession(vm.activeSession!.remoteHostId!)
                : null,
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
        KeyedSubtree(
          key: _presetsAndFiltersKey,
          child: CapturePresetsBar(
            presets: vm.presets,
            activePresetId: vm.activePresetId,
            onSelectPreset: (CapturePreset preset) => vm.applyPreset(preset),
          ),
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
    );
  }

  Widget _buildUnreachableRemoteBanner(
    ActiveCaptureSession session,
    String? hostId,
    TSharkCaptureViewModel vm,
  ) {
    final isPolling = hostId != null && vm.isPollingRemote(hostId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.accentAmber.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.accentAmber,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stored Remote Session Unreachable: ${session.remoteHostName ?? "Remote Host"} (PID ${session.pid})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentAmber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.unreachableReason ??
                      'Host did not respond over SSH. If the machine was turned off, you can clear this session from local memory.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          if (hostId != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: isPolling
                  ? null
                  : () => vm.refreshRemoteSessionStatus(hostId),
              icon: isPolling
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 15),
              label: const Text('Retry SSH'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppTheme.accentAmber,
                side: BorderSide(color: AppTheme.accentAmber),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => vm.clearRemoteSession(hostId),
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('Clear Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
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

  Widget _buildConfigurationColumn(
    BuildContext context,
    TSharkCaptureViewModel vm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaptureModeSelectorCard(vm: vm),
        const SizedBox(height: 16),
        StorageAndRecoveryCard(
          vm: vm,
          onPickOutputFolder: () => _pickOutputFolder(vm),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context, TSharkCaptureViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Command Line Preview Card
        CommandPreviewCard(
          commandLine: vm.previewCommandLine,
          runDetached: vm.isRemoteTarget ? true : vm.runDetached,
          isRemoteTarget: vm.isRemoteTarget,
          onDetachedChanged: (vm.isRemoteTarget || vm.isCapturing)
              ? null
              : (val) => vm.setRunDetached(val),
        ),
        const SizedBox(height: 16),

        // Live Packet Stream Table (Step 4 target)
        KeyedSubtree(
          key: _livePacketTableKey,
          child: LivePacketStreamCard(
            packets: vm.demoPackets,
            selectedPacket: vm.selectedDemoPacket,
            onSelectPacket: vm.selectDemoPacket,
          ),
        ),
        const SizedBox(height: 16),

        // Packet Dissection & Recent Capture Vault (Step 5 target)
        KeyedSubtree(
          key: _packetDissectionExportKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.selectedDemoPacket != null) ...[
                PacketDissectionCard(packet: vm.selectedDemoPacket!),
                const SizedBox(height: 16),
              ],
              SectionCard(
                title: 'Recent Capture Vault',
                icon: Icons.history,
                trailing: vm.history.isNotEmpty && !vm.isRemoteTarget
                    ? TextButton.icon(
                        onPressed: () => vm.openActiveDirectory(),
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text(
                          'Open Storage Folder',
                          style: TextStyle(fontSize: 11),
                        ),
                      )
                    : null,
                child: CaptureHistoryCard(
                  history: vm.history,
                  onOpenFolder: (item) => vm.openHistoryItemFolder(item),
                  onOpenWireshark: (item) => vm.openHistoryItemInWireshark(item),
                  onRemove: (item) => vm.removeHistoryItem(item),
                  onCopyPath: (item) {
                    SystemService.copyToClipboard(item.filePath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied remote path: ${item.filePath}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onLoadDemo:
                      vm.isCapturing ? null : () => startDemoWalkthrough(vm),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
