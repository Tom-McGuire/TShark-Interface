import 'package:flutter/material.dart';
import '../../../models/active_capture_session.dart';
import '../../../models/remote_host.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../view_models/tshark_capture_view_model.dart';
import '../dialogs/remote_host_dialog.dart';

class RemoteHostsTab extends StatefulWidget {
  const RemoteHostsTab({
    super.key,
    required this.viewModel,
    required this.onSelectHostForCapture,
  });

  final TSharkCaptureViewModel viewModel;
  final ValueChanged<RemoteHost> onSelectHostForCapture;

  @override
  State<RemoteHostsTab> createState() => _RemoteHostsTabState();
}

class _RemoteHostsTabState extends State<RemoteHostsTab> {
  final Set<String> _testingHostIds = {};

  void _openAddEditDialog([RemoteHost? host]) {
    showDialog(
      context: context,
      builder: (_) => RemoteHostDialog(
        viewModel: widget.viewModel,
        existingHost: host,
      ),
    );
  }

  Future<void> _testHost(RemoteHost host) async {
    setState(() => _testingHostIds.add(host.id));
    final res = await widget.viewModel.testRemoteHostConnection(host);
    if (!mounted) return;
    setState(() => _testingHostIds.remove(host.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            res.success ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
        content: Text(
          res.success
              ? 'Connected to ${host.name}: ${res.tsharkVersion ?? "TShark ready"} (${res.interfaces.length} adapters)'
              : 'Failed to connect to ${host.name}: ${res.errorMessage}',
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final hosts = vm.remoteHosts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Action Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.dns_outlined,
                  color: AppTheme.accentCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remote SSH Machines',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Configure remote Linux or Windows SSH hosts, inspect live TShark status, or clear offline sessions.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (vm.remoteSessions.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => vm.refreshAllRemoteSessions(),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Refresh All Statuses'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              ElevatedButton.icon(
                onPressed: () => _openAddEditDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Remote Machine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (hosts.isEmpty)
          _buildEmptyState()
        else
          ...hosts.map((host) {
            final session = vm.remoteSessions[host.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildHostCard(host, session, vm),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lan_outlined,
            size: 46,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Remote SSH Machines Saved',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a remote Linux or Windows machine with SSH access to discover its network interfaces and run headless TShark captures remotely.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.white54),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openAddEditDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Your First Remote Machine'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostCard(
    RemoteHost host,
    ActiveCaptureSession? session,
    TSharkCaptureViewModel vm,
  ) {
    final isTesting = _testingHostIds.contains(host.id);
    final isPolling = vm.isPollingRemote(host.id);
    final isStopping = vm.isStoppingRemote(host.id);
    final isCapturing = session != null && !session.isUnreachable;
    final isUnreachable = session != null && session.isUnreachable;

    Color borderColor = AppTheme.borderColor;
    if (isCapturing) {
      borderColor = AppTheme.accentEmerald.withValues(alpha: 0.5);
    } else if (isUnreachable) {
      borderColor = AppTheme.accentAmber.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Host Info & Management Actions
          Row(
            children: [
              Icon(
                host.osType == RemoteOsType.windows
                    ? Icons.desktop_windows_outlined
                    : Icons.terminal_outlined,
                color: isCapturing
                    ? AppTheme.accentEmerald
                    : (isUnreachable ? AppTheme.accentAmber : AppTheme.accentCyan),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          host.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildBadge(
                          label: host.osType.label,
                          color: Colors.white54,
                        ),
                        if (host.detectedTSharkVersion != null) ...[
                          const SizedBox(width: 8),
                          _buildBadge(
                            label: host.detectedTSharkVersion!,
                            color: AppTheme.accentCyan,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${host.username}@${host.host}:${host.port}  •  Default Output: ${host.defaultOutputDirectory}${host.useSudo ? "  •  sudo enabled" : ""}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              // Test SSH Button
              OutlinedButton.icon(
                onPressed: isTesting ? null : () => _testHost(host),
                icon: isTesting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt, size: 15),
                label: Text(isTesting ? 'Testing...' : 'Test SSH'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit Machine',
                onPressed: () => _openAddEditDialog(host),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppTheme.accentRed,
                ),
                tooltip: 'Delete Machine',
                onPressed: () => vm.deleteRemoteHost(host.id),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Section: Active Capture vs Unreachable Session vs Idle
          if (isCapturing)
            _buildActiveSessionBox(host, session, vm, isPolling, isStopping)
          else if (isUnreachable)
            _buildUnreachableSessionBox(host, session, vm, isPolling)
          else
            _buildIdleBox(host),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBox(
    RemoteHost host,
    ActiveCaptureSession session,
    TSharkCaptureViewModel vm,
    bool isPolling,
    bool isStopping,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentEmerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.accentEmerald.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.radio_button_checked,
            color: AppTheme.accentEmerald,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'REMOTE CAPTURE RUNNING',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentEmerald,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PID ${session.pid}  •  Interface: ${session.interfaceName}',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Elapsed: ${vm.formatDuration(session.elapsed)}  •  Size: ${vm.formatBytes(session.lastKnownSizeBytes)}  •  Remote File: ${session.targetFilePath}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: isPolling
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            tooltip: 'Poll Remote Status Now',
            onPressed: isPolling
                ? null
                : () => vm.refreshRemoteSessionStatus(host.id),
          ),
          TextButton.icon(
            onPressed: () => vm.clearRemoteSession(host.id),
            icon: const Icon(Icons.cleaning_services_outlined, size: 15),
            label: const Text('Forget Local Record'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              textStyle: const TextStyle(fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: isStopping ? null : () => vm.stopRemoteCapture(host.id),
            icon: const Icon(Icons.stop_circle_outlined, size: 16),
            label: Text(isStopping ? 'Stopping...' : 'Stop Capture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreachableSessionBox(
    RemoteHost host,
    ActiveCaptureSession session,
    TSharkCaptureViewModel vm,
    bool isPolling,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.accentAmber.withValues(alpha: 0.4),
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
                  'STORED REMOTE SESSION (PID ${session.pid}) — HOST UNREACHABLE',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentAmber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.unreachableReason ??
                      'Could not connect via SSH to check if PID ${session.pid} on ${session.interfaceName} is still running.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  'Remote File: ${session.targetFilePath}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: isPolling
                ? null
                : () => vm.refreshRemoteSessionStatus(host.id),
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
            onPressed: () => vm.clearRemoteSession(host.id),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text('Clear Session from Memory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentAmber,
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleBox(RemoteHost host) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF11151C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Status: Idle — No active TShark capture tracked on this machine.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => widget.onSelectHostForCapture(host),
            icon: const Icon(Icons.radar, size: 15),
            label: const Text('Select for Capture'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppTheme.accentCyan,
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
