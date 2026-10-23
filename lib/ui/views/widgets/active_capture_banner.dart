import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/services/system_service.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';

class ActiveCaptureBanner extends StatefulWidget {
  const ActiveCaptureBanner({
    super.key,
    required this.session,
    required this.elapsed,
    required this.fileSizeBytes,
    required this.isStopping,
    required this.onStop,
  });

  final ActiveCaptureSession session;
  final Duration elapsed;
  final int fileSizeBytes;
  final bool isStopping;
  final VoidCallback onStop;

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

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF261214),
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
                    const Text(
                      'CAPTURE RUNNING',
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
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PID ${widget.session.pid}',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.session.mode.label,
                        style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatDuration(widget.elapsed),
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.storage, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      _formatBytes(widget.fileSizeBytes),
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        p.basename(widget.session.targetFilePath),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
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
              OutlinedButton.icon(
                onPressed: () => SystemService.openFolder(widget.session.outputDirectory),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Open Folder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              const SizedBox(width: 10),
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
