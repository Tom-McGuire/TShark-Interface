import 'package:material_ui/material_ui.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';

class CaptureFilterInput extends StatefulWidget {
  const CaptureFilterInput({
    super.key,
    required this.filter,
    required this.onChanged,
    this.enabled = true,
  });

  final String filter;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<CaptureFilterInput> createState() => _CaptureFilterInputState();
}

class _CaptureFilterInputState extends State<CaptureFilterInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filter);
  }

  @override
  void didUpdateWidget(covariant CaptureFilterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != _controller.text) {
      _controller.text = widget.filter;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSyntaxGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.accentCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'Berkeley Packet Filter (BPF) Syntax Guide',
              style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TShark uses BPF (libpcap/WinPcap/Npcap) capture filter syntax. Packets matching the expression will be recorded:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 14),
                _buildExample('port 53', 'Captures all DNS requests & replies (UDP/TCP)'),
                _buildExample('host 192.168.1.50', 'Captures all traffic to or from a specific IP'),
                _buildExample('src 10.0.0.1 and dst port 80', 'Specific source IP going to web server'),
                _buildExample('net 192.168.1.0/24', 'Traffic from/to an entire local subnet'),
                _buildExample('not port 22 and not port 3389', 'Excludes SSH and Windows Remote Desktop'),
                _buildExample('tcp[tcpflags] & (tcp-syn|tcp-fin) != 0', 'TCP connection handshakes/teardowns'),
                _buildExample('icmp or icmp6', 'Captures ICMP ping / diagnostic traffic'),
                _buildExample('broadcast or multicast', 'Captures network discovery & broadcast packets'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.accentCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildExample(String syntax, String explanation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: widget.enabled
            ? () {
                widget.onChanged(syntax);
                Navigator.of(context).pop();
              }
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      syntax,
                      style: AppTheme.monoTextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentCyan,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      explanation,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.enabled)
                Icon(Icons.touch_app, size: 16, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_alt_outlined, size: 16, color: AppTheme.accentCyan),
            const SizedBox(width: 6),
            Text(
              'Capture Filter (BPF)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _showSyntaxGuide(context),
              child: Icon(Icons.help_outline, size: 15, color: AppTheme.textSecondary),
            ),
            const Spacer(),
            if (widget.filter.isNotEmpty && widget.enabled)
              TextButton(
                onPressed: () => widget.onChanged(''),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  'Clear Filter',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          style: AppTheme.monoTextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. not port 22 and not port 3389 or host 192.168.1.1',
            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textMuted),
            suffixIcon: IconButton(
              icon: Icon(Icons.menu_book, size: 18, color: AppTheme.accentCyan),
              tooltip: 'Browse Common Filters & Syntax',
              onPressed: () => _showSyntaxGuide(context),
            ),
          ),
        ),
      ],
    );
  }
}
