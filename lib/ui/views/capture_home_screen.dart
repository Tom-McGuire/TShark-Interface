import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/models/demo_packet.dart';
import 'package:tshark_interface/models/remote_host.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/ui/widgets/guided_tour_overlay.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';
import 'dialogs/settings_dialog.dart';
import 'widgets/active_capture_banner.dart';
import 'widgets/capture_filter_input.dart';
import 'widgets/capture_history_card.dart';
import 'widgets/capture_presets_bar.dart';
import 'widgets/command_preview_card.dart';
import 'widgets/interrupted_capture_banner.dart';
import 'widgets/remote_hosts_tab.dart';

class CaptureHomeScreen extends StatefulWidget {
  const CaptureHomeScreen({super.key});

  @override
  State<CaptureHomeScreen> createState() => _CaptureHomeScreenState();
}

class _CaptureHomeScreenState extends State<CaptureHomeScreen> {
  final _filePrefixController = TextEditingController();
  final _packetLimitController = TextEditingController();
  final _remoteOutputDirController = TextEditingController();

  // Spotlight Tour Keys & State
  bool _isTourActive = false;
  final GlobalKey _zone2TargetInterfaceKey = GlobalKey();
  final GlobalKey _zone3StartStopKey = GlobalKey();
  final GlobalKey _presetsAndFiltersKey = GlobalKey();
  final GlobalKey _livePacketTableKey = GlobalKey();
  final GlobalKey _packetDissectionExportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final vm = context.read<TSharkCaptureViewModel>();
    _filePrefixController.text = vm.filePrefix;
    _packetLimitController.text = vm.packetCountLimit.toString();
    _remoteOutputDirController.text = vm.outputDirectory;
  }

  @override
  void dispose() {
    _filePrefixController.dispose();
    _packetLimitController.dispose();
    _remoteOutputDirController.dispose();
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

  Future<void> _openRemoteHostsDialog(
    BuildContext context,
    TSharkCaptureViewModel vm,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF13171F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2C2C2C)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 950,
              maxHeight: 700,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161B24),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dns_outlined, color: AppTheme.accentCyan, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Remote SSH Hosts Management',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
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
                        _remoteOutputDirController.text = vm.outputDirectory;
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
    _packetLimitController.text = vm.packetCountLimit.toString();
    setState(() {
      _isTourActive = true;
    });
  }

  void endDemoWalkthrough(TSharkCaptureViewModel vm) {
    setState(() {
      _isTourActive = false;
    });
    vm.clearCapture();
    _packetLimitController.text = vm.packetCountLimit.toString();
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
            'View detailed protocol frame layers for the selected packet, preview the exact TShark CLI invocation, and export captures to .pcapng or CSV.',
      ),
    ];
  }

  void _clearCaptureSettings(TSharkCaptureViewModel vm) {
    vm.clearCapture();
    _packetLimitController.text = vm.packetCountLimit.toString();
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
      Clipboard.setData(ClipboardData(text: vm.previewCommandLine));
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
        backgroundColor: const Color(0xFF0F141C),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopControlBar(context, vm),
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

  Widget _buildTopControlBar(BuildContext context, TSharkCaptureViewModel vm) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Cluster: Zone 1 (Branding), Zone 2 (Interface & Target), Zone 3 (Primary Actions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================== ZONE 1: BRANDING ====================
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'T-SHARK INTERFACE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Headless Packet Capture Studio',
                              style: TextStyle(fontSize: 10, color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // ==================== ZONE 2: INTERFACE & TARGET ====================
                        Row(
                          key: _zone2TargetInterfaceKey,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Target Machine Selector (Local vs Remote Host)
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B24),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF2C2C2C)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  key: ValueKey('top_target_${vm.selectedRemoteHost?.id ?? "local"}'),
                                  value: vm.selectedRemoteHost?.id,
                                  isDense: true,
                                  dropdownColor: const Color(0xFF161B24),
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                  icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.computer, size: 14, color: Colors.white70),
                                          const SizedBox(width: 6),
                                          const Text('Localhost (This PC)', style: TextStyle(fontSize: 11)),
                                          if (vm.localActiveSession != null) ...[
                                            const SizedBox(width: 6),
                                            _buildStatusDot(
                                              color: AppTheme.accentEmerald,
                                              label: 'Capturing',
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    ...vm.remoteHosts.map((host) {
                                      final rSession = vm.remoteSessions[host.id];
                                      return DropdownMenuItem<String?>(
                                        value: host.id,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.dns_outlined, size: 14, color: AppTheme.accentCyan),
                                            const SizedBox(width: 6),
                                            Text(
                                              'SSH: ${host.name}',
                                              style: const TextStyle(fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (rSession != null) ...[
                                              const SizedBox(width: 6),
                                              _buildStatusDot(
                                                color: rSession.isUnreachable
                                                    ? AppTheme.accentAmber
                                                    : AppTheme.accentEmerald,
                                                label: rSession.isUnreachable ? 'Unreachable' : 'Capturing',
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (String? hostId) async {
                                    if (hostId == null) {
                                      await vm.selectTargetHost(null);
                                    } else {
                                      final match = vm.remoteHosts.where((h) => h.id == hostId);
                                      if (match.isNotEmpty) {
                                        await vm.selectTargetHost(match.first);
                                      }
                                    }
                                    _remoteOutputDirController.text = vm.outputDirectory;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Network Interface Selector
                            Container(
                              height: 32,
                              constraints: const BoxConstraints(minWidth: 140, maxWidth: 210),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B24),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF2C2C2C)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<CaptureInterface>(
                                  key: ValueKey(
                                    'top_iface_${vm.selectedRemoteHost?.id ?? "local"}_${vm.selectedInterface?.name ?? "none"}',
                                  ),
                                  value: vm.interfaces.contains(vm.selectedInterface)
                                      ? vm.selectedInterface
                                      : null,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF161B24),
                                  hint: const Text(
                                    'Select Interface',
                                    style: TextStyle(fontSize: 11, color: Colors.white54),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                  icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
                                  items: vm.interfaces.map((iface) {
                                    return DropdownMenuItem<CaptureInterface>(
                                      value: iface,
                                      child: Text(
                                        iface.displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: vm.isCapturing ? null : (val) => vm.setSelectedInterface(val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: vm.isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                              tooltip: vm.isRemoteTarget
                                  ? 'Refresh Remote Network Interfaces over SSH'
                                  : 'Refresh Interfaces',
                              onPressed: vm.isCapturing ? null : () => vm.refreshInterfaces(),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // ==================== ZONE 3: PRIMARY ACTIONS ====================
                        KeyedSubtree(
                          key: _zone3StartStopKey,
                          child: FilledButton.icon(
                            onPressed: (vm.isCapturing || !vm.hasTShark || vm.isLoading)
                                ? (vm.isCapturing ? () => vm.stopCapture() : null)
                                : () => vm.startCapture(),
                            style: FilledButton.styleFrom(
                              backgroundColor: vm.isCapturing
                                  ? const Color(0xFFEF4444) // Active Red
                                  : const Color(0xFF10B981), // Idle Emerald Green (from ARP Scout)
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: Icon(
                              vm.isCapturing
                                  ? Icons.stop
                                  : (vm.isRemoteTarget ? Icons.cloud_upload_outlined : Icons.play_arrow),
                              size: 17,
                            ),
                            label: Text(
                              vm.isCapturing
                                  ? 'Stop Capture'
                                  : (vm.isRemoteTarget
                                      ? 'Start Remote Capture'
                                      : (vm.runDetached ? 'Start Headless' : 'Start Capture')),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Right Cluster: Zone 4 (Ecosystem & Demo), Zone 5 (Clear & Export)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================== ZONE 4: ECOSYSTEM & DEMO ====================
                        // Remote Hosts Manager Button
                        OutlinedButton.icon(
                          onPressed: () => _openRemoteHostsDialog(context, vm),
                          icon: const Icon(Icons.dns_outlined, size: 15),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Remote Hosts', style: TextStyle(fontSize: 11)),
                              if (vm.remoteSessions.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: vm.unreachableRemoteSessions.isNotEmpty
                                        ? AppTheme.accentAmber
                                        : AppTheme.accentEmerald,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    vm.remoteSessions.length.toString(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Load Demo / Exit Demo Button
                        OutlinedButton.icon(
                          onPressed: vm.isCapturing
                              ? null
                              : () {
                                  if (vm.isDemoMode) {
                                    endDemoWalkthrough(vm);
                                  } else {
                                    startDemoWalkthrough(vm);
                                  }
                                },
                          icon: Icon(
                            vm.isDemoMode
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            size: 15,
                            color: vm.isDemoMode ? const Color(0xFFF59E0B) : null,
                          ),
                          label: Text(
                            vm.isDemoMode ? 'Exit Demo' : 'Load Demo',
                            style: TextStyle(
                              fontSize: 11,
                              color: vm.isDemoMode ? const Color(0xFFF59E0B) : null,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: vm.isDemoMode
                                ? const BorderSide(color: Color(0xFFF59E0B))
                                : null,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // ==================== ZONE 5: CLEAR & EXPORT ====================
                        OutlinedButton.icon(
                          onPressed: vm.isCapturing ? null : () => _clearCaptureSettings(vm),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                          label: const Text('Clear', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Export Menu
                        PopupMenuButton<String>(
                          tooltip: 'Export & Actions',
                          onSelected: (val) => _handleExportSelection(val, vm),
                          itemBuilder: (_) => [
                            const PopupMenuItem<String>(
                              value: 'open_folder',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open, size: 16),
                                  SizedBox(width: 10),
                                  Text('Open Storage Folder', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'copy_cmd',
                              child: Row(
                                children: [
                                  Icon(Icons.terminal, size: 16),
                                  SizedBox(width: 10),
                                  Text('Copy Command Line', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF2C2C2C)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download, size: 15, color: Colors.white70),
                                SizedBox(width: 6),
                                Text('Export', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          tooltip: 'Engine & Output Settings',
                          onPressed: () => _openSettings(context, vm),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
            onSelectPreset: (CapturePreset preset) {
              vm.applyPreset(preset);
              _packetLimitController.text = vm.packetCountLimit.toString();
            },
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
          const Icon(
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
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentAmber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.unreachableReason ??
                      'Host did not respond over SSH. If the machine was turned off, you can clear this session from local memory.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
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
                side: const BorderSide(color: AppTheme.accentAmber),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Full Packets (Default)'),
                      ),
                      DropdownMenuItem(
                        value: 64,
                        child: Text('64 Bytes (L2-L3 Only)'),
                      ),
                      DropdownMenuItem(
                        value: 96,
                        child: Text('96 Bytes (Headers Only)'),
                      ),
                      DropdownMenuItem(
                        value: 128,
                        child: Text('128 Bytes (Headers+TOS)'),
                      ),
                      DropdownMenuItem(
                        value: 256,
                        child: Text('256 Bytes'),
                      ),
                    ],
                    onChanged: vm.isCapturing
                        ? null
                        : (val) => vm.setSnaplen(val ?? 0),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Promiscuous Mode
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Promiscuous Mode',
                  style: TextStyle(fontSize: 12.5),
                ),
                subtitle: const Text(
                  'Captures all network packets seen on the segment, not just packets addressed to this host.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                value: vm.promiscuous,
                onChanged: vm.isCapturing
                    ? null
                    : (val) => vm.setPromiscuous(val),
                activeThumbColor: AppTheme.accentCyan,
              ),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Output Storage Directory (Local Folder Picker vs Remote Path Input)
              Text(
                vm.isRemoteTarget
                    ? 'Remote Destination Folder (on ${vm.selectedRemoteHost!.name})'
                    : 'Destination Storage Folder',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (vm.isRemoteTarget)
                TextField(
                  controller: _remoteOutputDirController,
                  enabled: !vm.isCapturing,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    hintText: '/tmp/tshark_captures',
                    prefixIcon: Icon(Icons.folder_outlined, size: 18),
                  ),
                  onChanged: (val) => vm.setOutputDirectory(val),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13171F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(
                          vm.outputDirectory.isNotEmpty
                              ? vm.outputDirectory
                              : 'No directory chosen',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: vm.isCapturing
                          ? null
                          : () => _pickOutputFolder(vm),
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
                      title: const Text(
                        'Timestamp Subfolder',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: vm.createSubfolder,
                      onChanged: vm.isCapturing
                          ? null
                          : (val) => vm.setCreateSubfolder(val ?? true),
                      activeColor: AppTheme.accentCyan,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Reboot & Crash Recovery Policy
              const Text(
                'Reboot & Crash Recovery Policy',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              const Text(
                'Action to take if the system restarts or shuts down while capturing.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RecoveryPolicy>(
                initialValue: vm.recoveryPolicy,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.settings_backup_restore, size: 18),
                ),
                items: RecoveryPolicy.values.map((policy) {
                  return DropdownMenuItem<RecoveryPolicy>(
                    value: policy,
                    child: Text(
                      '${policy.label} — ${policy.description}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: vm.isCapturing
                    ? null
                    : (val) {
                        if (val != null) vm.setRecoveryPolicy(val);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDot({required Color color, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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
                        const Text(
                          'Hours: ',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        DropdownButton<int>(
                          value: vm.durationHours,
                          dropdownColor: const Color(0xFF1F242C),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          items: List.generate(
                            25,
                            (i) => DropdownMenuItem(value: i, child: Text('$i h')),
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
                        const Text(
                          'Minutes: ',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        DropdownButton<int>(
                          value: vm.durationMinutes,
                          dropdownColor: const Color(0xFF1F242C),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
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
                      vm.ringRotateBySize
                          ? 'Rotate Every (MB)'
                          : 'Rotate Every (Minutes)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'By Size',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
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
                            dropdownColor: const Color(0xFF1F242C),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
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
                            dropdownColor: const Color(0xFF1F242C),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
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
                        const Text(
                          'Keep: ',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        DropdownButton<int>(
                          value: vm.ringFilesCount,
                          dropdownColor: const Color(0xFF1F242C),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
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
        // Live Command Line Preview Card
        CommandPreviewCard(
          commandLine: vm.previewCommandLine,
          runDetached: vm.isRemoteTarget ? true : vm.runDetached,
          onDetachedChanged: (val) => vm.setRunDetached(val),
        ),
        const SizedBox(height: 16),

        // Live Packet Stream Table (Step 4 target)
        KeyedSubtree(
          key: _livePacketTableKey,
          child: _buildLivePacketStreamCard(vm),
        ),
        const SizedBox(height: 16),

        // Packet Dissection & Recent Capture Vault (Step 5 target)
        KeyedSubtree(
          key: _packetDissectionExportKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.selectedDemoPacket != null) ...[
                _buildPacketDissectionCard(vm.selectedDemoPacket!),
                const SizedBox(height: 16),
              ],
              _buildSectionCard(
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
                  onLoadDemo: vm.isCapturing ? null : () => startDemoWalkthrough(vm),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivePacketStreamCard(TSharkCaptureViewModel vm) {
    return _buildSectionCard(
      title: 'Live Packet Stream',
      icon: Icons.view_list_outlined,
      trailing: vm.demoPackets.isNotEmpty
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
                '${vm.demoPackets.length} Packets',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentEmerald,
                ),
              ),
            )
          : null,
      child: vm.demoPackets.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF13171F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Center(
                child: Text(
                  'No live packets in stream. Start a capture or click "Load Demo" to preview decoded frames.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.white38),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: const Color(0xFF13171F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vm.demoPackets.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppTheme.borderColor),
                itemBuilder: (context, index) {
                  final pkt = vm.demoPackets[index];
                  final isSelected = vm.selectedDemoPacket?.number == pkt.number;
                  return InkWell(
                    onTap: () => vm.selectDemoPacket(pkt),
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
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 11,
                                color: Colors.white54,
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
                              color: AppTheme.accentCyan.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pkt.protocol,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
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
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pkt.info,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
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

  Widget _buildPacketDissectionCard(DemoPacket packet) {
    return _buildSectionCard(
      title: 'Packet Dissection (Frame #${packet.number} • ${packet.protocol})',
      icon: Icons.account_tree_outlined,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF13171F),
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
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      layer,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        color: Colors.white70,
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
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
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
