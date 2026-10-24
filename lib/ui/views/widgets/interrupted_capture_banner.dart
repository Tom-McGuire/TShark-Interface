import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';

class InterruptedCaptureBanner extends StatelessWidget {
  const InterruptedCaptureBanner({
    super.key,
    required this.session,
    required this.onResume,
    required this.onLoadSettings,
    required this.onDismiss,
  });

  final ActiveCaptureSession session;
  final VoidCallback onResume;
  final VoidCallback onLoadSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedStart = dateFormat.format(session.startedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF261D12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_off,
                  color: AppTheme.accentAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'INTERRUPTED CAPTURE DETECTED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '(System Reboot or Sudden Shutdown)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A previous capture was active when the system stopped at $formattedStart.',
                      style: const TextStyle(fontSize: 12.5, color: Colors.white),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                tooltip: 'Dismiss Notice',
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Configuration Summary Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildInfoBadge('Interface', session.interfaceName, Icons.router_outlined),
              _buildInfoBadge('Mode', session.mode.label, Icons.tune),
              if (session.filter.isNotEmpty)
                _buildInfoBadge('Filter', session.filter, Icons.filter_alt_outlined),
              if (session.snaplen > 0)
                _buildInfoBadge('Snaplen', '${session.snaplen} B', Icons.content_cut),
            ],
          ),
          const SizedBox(height: 14),
          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Resume Capture Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onLoadSettings,
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('Load Settings (Review First)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.accentCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Discard', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.accentAmber),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
