import 'package:flutter/material.dart';
import 'package:tshark_interface/services/system_service.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';

class CommandPreviewCard extends StatefulWidget {
  const CommandPreviewCard({
    super.key,
    required this.commandLine,
    required this.runDetached,
    required this.onDetachedChanged,
  });

  final String commandLine;
  final bool runDetached;
  final ValueChanged<bool> onDetachedChanged;

  @override
  State<CommandPreviewCard> createState() => _CommandPreviewCardState();
}

class _CommandPreviewCardState extends State<CommandPreviewCard> {
  bool _copied = false;
  bool _usePowerShell = true;

  String get _displayCommand {
    final raw = widget.commandLine.trim();
    if (_usePowerShell && raw.startsWith('"')) {
      return '& $raw';
    }
    return raw;
  }

  void _copy() async {
    await SystemService.copyToClipboard(_displayCommand);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161B24),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Generated TShark CLI Command',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Headless background toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Detached (Headless)',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: widget.runDetached,
                        onChanged: widget.onDetachedChanged,
                        activeThumbColor: AppTheme.accentCyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Sub-bar for Shell Format Selector and Copy Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF121720),
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                // Shell Format Toggle
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F141C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _usePowerShell = true),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _usePowerShell ? AppTheme.accentCyan.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PowerShell',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: _usePowerShell ? FontWeight.bold : FontWeight.normal,
                              color: _usePowerShell ? AppTheme.accentCyan : Colors.white60,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _usePowerShell = false),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: !_usePowerShell ? AppTheme.accentCyan.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CMD / Bash',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: !_usePowerShell ? FontWeight.bold : FontWeight.normal,
                              color: !_usePowerShell ? AppTheme.accentCyan : Colors.white60,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Copy Button
                OutlinedButton.icon(
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: 14,
                    color: _copied ? AppTheme.accentEmerald : AppTheme.accentCyan,
                  ),
                  label: Text(
                    _copied ? 'Copied!' : 'Copy CLI',
                    style: TextStyle(
                      fontSize: 11,
                      color: _copied ? AppTheme.accentEmerald : Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    side: BorderSide(
                      color: _copied ? AppTheme.accentEmerald : AppTheme.borderColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code Box
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              _displayCommand,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12.5,
                color: Color(0xFF7DD3FC),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
