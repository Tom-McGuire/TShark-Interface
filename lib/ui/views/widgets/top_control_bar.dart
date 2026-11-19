import 'package:material_ui/material_ui.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

/// Top studio toolbar housing branding, target/interface selectors, capture triggers,
/// remote host management, demo toggle, clear/export actions, and settings.
class TopControlBar extends StatelessWidget {
  const TopControlBar({
    super.key,
    required this.vm,
    required this.zone2TargetInterfaceKey,
    required this.zone3StartStopKey,
    required this.onOpenRemoteHosts,
    required this.onStartDemo,
    required this.onEndDemo,
    required this.onClearSettings,
    required this.onExportSelected,
    required this.onOpenSettings,
  });

  final TSharkCaptureViewModel vm;
  final GlobalKey zone2TargetInterfaceKey;
  final GlobalKey zone3StartStopKey;
  final VoidCallback onOpenRemoteHosts;
  final VoidCallback onStartDemo;
  final VoidCallback onEndDemo;
  final VoidCallback onClearSettings;
  final ValueChanged<String> onExportSelected;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'T-SHARK INTERFACE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Headless Packet Capture Studio',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // ==================== ZONE 2: INTERFACE & TARGET ====================
                        Row(
                          key: zone2TargetInterfaceKey,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Target Machine Selector (Local vs Remote Host)
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHigh,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  key: ValueKey(
                                    'top_target_${vm.selectedRemoteHost?.id ?? "local"}',
                                  ),
                                  value: vm.selectedRemoteHost?.id,
                                  isDense: true,
                                  dropdownColor: AppTheme.surfaceElevated,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textPrimary,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.computer,
                                            size: 14,
                                            color: AppTheme.textPrimary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Localhost (This PC)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
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
                                            Icon(
                                              Icons.dns_outlined,
                                              size: 14,
                                              color: AppTheme.accentCyan,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'SSH: ${host.name}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (rSession != null) ...[
                                              const SizedBox(width: 6),
                                              _buildStatusDot(
                                                color: rSession.isUnreachable
                                                    ? AppTheme.accentAmber
                                                    : AppTheme.accentEmerald,
                                                label: rSession.isUnreachable
                                                    ? 'Unreachable'
                                                    : 'Capturing',
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
                                      final match = vm.remoteHosts.where(
                                        (h) => h.id == hostId,
                                      );
                                      if (match.isNotEmpty) {
                                        await vm.selectTargetHost(match.first);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Network Interface Selector
                            Container(
                              height: 32,
                              constraints: const BoxConstraints(
                                minWidth: 140,
                                maxWidth: 210,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHigh,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
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
                                  dropdownColor: AppTheme.surfaceElevated,
                                  hint: Text(
                                    'Select Interface',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textPrimary,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  items: vm.interfaces.map((iface) {
                                    return DropdownMenuItem<CaptureInterface>(
                                      value: iface,
                                      child: Tooltip(
                                        message: iface.subtitle,
                                        child: Text(
                                          iface.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: vm.isCapturing
                                      ? null
                                      : (val) => vm.setSelectedInterface(val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: vm.isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                              tooltip: vm.isRemoteTarget
                                  ? 'Refresh Remote Network Interfaces over SSH'
                                  : 'Refresh Interfaces',
                              onPressed: vm.isCapturing
                                  ? null
                                  : () => vm.refreshInterfaces(),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // ==================== ZONE 3: PRIMARY ACTIONS ====================
                        KeyedSubtree(
                          key: zone3StartStopKey,
                          child: FilledButton.icon(
                            onPressed: (vm.isCapturing ||
                                    !vm.hasTShark ||
                                    vm.isLoading)
                                ? (vm.isCapturing ? () => vm.stopCapture() : null)
                                : () => vm.startCapture(),
                            style: FilledButton.styleFrom(
                              backgroundColor: vm.isCapturing
                                  ? const Color(0xFFEF4444) // Active Red
                                  : const Color(0xFF10B981), // Idle Emerald Green
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: Icon(
                              vm.isCapturing
                                  ? Icons.stop
                                  : (vm.isRemoteTarget
                                      ? Icons.cloud_upload_outlined
                                      : Icons.play_arrow),
                              size: 17,
                            ),
                            label: Text(
                              vm.isCapturing
                                  ? 'Stop Capture'
                                  : (vm.isRemoteTarget
                                      ? 'Start Remote Capture'
                                      : (vm.runDetached
                                          ? 'Start Headless'
                                          : 'Start Capture')),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
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
                        OutlinedButton.icon(
                          onPressed: onOpenRemoteHosts,
                          icon: const Icon(Icons.dns_outlined, size: 15),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Remote Hosts',
                                style: TextStyle(fontSize: 11),
                              ),
                              if (vm.remoteSessions.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Load Demo / Exit Demo Button
                        OutlinedButton.icon(
                          onPressed: vm.isCapturing
                              ? null
                              : () {
                                  if (vm.isDemoMode) {
                                    onEndDemo();
                                  } else {
                                    onStartDemo();
                                  }
                                },
                          icon: Icon(
                            vm.isDemoMode
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            size: 15,
                            color:
                                vm.isDemoMode ? const Color(0xFFF59E0B) : null,
                          ),
                          label: Text(
                            vm.isDemoMode ? 'Exit Demo' : 'Load Demo',
                            style: TextStyle(
                              fontSize: 11,
                              color: vm.isDemoMode
                                  ? const Color(0xFFF59E0B)
                                  : null,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: vm.isDemoMode
                                ? const BorderSide(color: Color(0xFFF59E0B))
                                : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // ==================== ZONE 5: CLEAR & EXPORT ====================
                        OutlinedButton.icon(
                          onPressed: vm.isCapturing ? null : onClearSettings,
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 15,
                          ),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Export Menu
                        PopupMenuButton<String>(
                          tooltip: 'Export & Actions',
                          onSelected: onExportSelected,
                          itemBuilder: (_) => [
                            const PopupMenuItem<String>(
                              value: 'open_folder',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open, size: 16),
                                  SizedBox(width: 10),
                                  Text(
                                    'Open Storage Folder',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'copy_cmd',
                              child: Row(
                                children: [
                                  Icon(Icons.terminal, size: 16),
                                  SizedBox(width: 10),
                                  Text(
                                    'Copy Command Line',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download,
                                  size: 15,
                                  color: AppTheme.textPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Export',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          tooltip: 'Engine & Output Settings',
                          onPressed: onOpenSettings,
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
}
