import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/services/system_service.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/utils/format_utils.dart';

class ActiveCaptureBanner extends StatefulWidget {
  const ActiveCaptureBanner({
    super.key,
    required this.session,
    required this.elapsed,
    required this.fileSizeBytes,
    required this.isStopping,
    required this.onStop,
    this.onClearRemoteSession,
  });

  final ActiveCaptureSession session;
  final Duration elapsed;
  final int fileSizeBytes;
  final bool isStopping;
  final VoidCallback onStop;
  final VoidCallback? onClearRemoteSession;

  @override
  State<ActiveCaptureBanner> createState() => _ActiveCaptureBannerState();
}

class _ActiveCaptureBannerState extends State<ActiveCaptureBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.isDark
            ? const Color(0xFF261214)
            : AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Pulsing record indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentRed.withValues(alpha: 0.4 + 0.6 * _pulseController.value),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentRed.withValues(alpha: 0.6 * _pulseController.value),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 14),

          // Details column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.session.isRemote
                          ? 'REMOTE CAPTURE RUNNING (${widget.session.remoteHostName ?? "SSH"})'
                          : 'CAPTURE RUNNING (LOCAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppTheme.accentRed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PID ${widget.session.pid}',
                        style: TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.session.mode.label,
                        style: TextStyle(fontSize: 11, color: AppTheme.accentCyan),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      FormatUtils.formatDuration(widget.elapsed),
                      style: AppTheme.monoTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.storage, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      FormatUtils.formatBytes(widget.fileSizeBytes),
                      style: AppTheme.monoTextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        p.basename(widget.session.targetFilePath),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.session.isRemote) ...[
                OutlinedButton.icon(
                  onPressed: () => SystemService.openFolder(widget.session.outputDirectory),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Open Folder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.border),
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (widget.onClearRemoteSession != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.onClearRemoteSession,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 15),
                  label: const Text('Forget Local Record'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.border),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              ElevatedButton.icon(
                onPressed: widget.isStopping ? null : widget.onStop,
                icon: widget.isStopping
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.stop, size: 18),
                label: Text(widget.isStopping ? 'Stopping...' : 'Stop Capture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
