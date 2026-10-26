import 'package:flutter/material.dart';
import '../../../models/remote_host.dart';
import '../../../services/remote_ssh_service.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../view_models/tshark_capture_view_model.dart';

class RemoteHostDialog extends StatefulWidget {
  const RemoteHostDialog({
    super.key,
    required this.viewModel,
    this.existingHost,
  });

  final TSharkCaptureViewModel viewModel;
  final RemoteHost? existingHost;

  @override
  State<RemoteHostDialog> createState() => _RemoteHostDialogState();
}

class _RemoteHostDialogState extends State<RemoteHostDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _outputDirController;
  late final TextEditingController _customTSharkController;

  RemoteOsType _osType = RemoteOsType.auto;
  bool _useSudo = false;
  bool _obscurePassword = true;
  bool _isTesting = false;
  RemoteConnectionTestResult? _testResult;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final h = widget.existingHost;
    _nameController = TextEditingController(text: h?.name ?? '');
    _hostController = TextEditingController(text: h?.host ?? '');
    _portController = TextEditingController(text: (h?.port ?? 22).toString());
    _usernameController = TextEditingController(text: h?.username ?? 'root');
    _passwordController = TextEditingController(text: h?.password ?? '');
    _outputDirController = TextEditingController(
      text: h?.defaultOutputDirectory ?? '/tmp/tshark_captures',
    );
    _customTSharkController = TextEditingController(
      text: h?.customTSharkPath ?? '',
    );
    _osType = h?.osType ?? RemoteOsType.auto;
    _useSudo = h?.useSudo ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _outputDirController.dispose();
    _customTSharkController.dispose();
    super.dispose();
  }

  RemoteHost? _buildHost() {
    final name = _nameController.text.trim();
    final hostAddr = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final user = _usernameController.text.trim();

    if (name.isEmpty) {
      setState(() => _validationError = 'Please enter a friendly name for this machine.');
      return null;
    }
    if (hostAddr.isEmpty) {
      setState(() => _validationError = 'Please enter an IP address or hostname.');
      return null;
    }
    if (user.isEmpty) {
      setState(() => _validationError = 'Please enter an SSH username.');
      return null;
    }

    setState(() => _validationError = null);
    final customBin = _customTSharkController.text.trim();
    final outDir = _outputDirController.text.trim().isNotEmpty
        ? _outputDirController.text.trim()
        : (_osType == RemoteOsType.windows
            ? r'C:\Temp\TSharkCaptures'
            : '/tmp/tshark_captures');

    return RemoteHost(
      id: widget.existingHost?.id ??
          'host_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      host: hostAddr,
      port: port.clamp(1, 65535),
      username: user,
      password: _passwordController.text,
      customTSharkPath: customBin.isNotEmpty ? customBin : null,
      defaultOutputDirectory: outDir,
      useSudo: _useSudo,
      osType: _testResult?.detectedOs ?? _osType,
      detectedTSharkVersion:
          _testResult?.tsharkVersion ?? widget.existingHost?.detectedTSharkVersion,
      isReachable: _testResult?.success ?? widget.existingHost?.isReachable,
    );
  }

  Future<void> _testConnection() async {
    final draft = _buildHost();
    if (draft == null) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await widget.viewModel.testRemoteHostConnection(draft);
    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testResult = result;
      if (result.success && _osType == RemoteOsType.auto) {
        _osType = result.detectedOs;
        if (result.detectedOs == RemoteOsType.windows &&
            _outputDirController.text.trim() == '/tmp/tshark_captures') {
          _outputDirController.text = r'C:\Temp\TSharkCaptures';
        }
      }
    });
  }

  Future<void> _save() async {
    final host = _buildHost();
    if (host == null) return;
    await widget.viewModel.saveRemoteHost(host);
    if (!mounted) return;
    Navigator.of(context).pop(host);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingHost != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF161B24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      title: Row(
        children: [
          const Icon(Icons.dns_outlined, color: AppTheme.accentCyan, size: 22),
          const SizedBox(width: 10),
          Text(
            isEdit ? 'Edit Remote SSH Machine' : 'Add Remote SSH Machine',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_validationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accentRed.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.accentRed),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Friendly Name
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Machine Label / Name',
                  hintText: 'e.g. Branch Router, Core Sensor 01',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // IP Address & Port
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _hostController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'IP Address or Hostname',
                        hintText: '192.168.1.50',
                        prefixIcon: Icon(Icons.lan_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'SSH Port',
                        hintText: '22',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Username & Password
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'SSH Username',
                        hintText: 'root or admin',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'SSH Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // OS Type & Default Output Directory
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<RemoteOsType>(
                      initialValue: _osType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Remote OS',
                        prefixIcon: Icon(Icons.computer, size: 18),
                      ),
                      items: RemoteOsType.values.map((os) {
                        return DropdownMenuItem(
                          value: os,
                          child: Text(os.label, style: const TextStyle(fontSize: 12.5)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _osType = val;
                            if (val == RemoteOsType.windows &&
                                _outputDirController.text.trim() ==
                                    '/tmp/tshark_captures') {
                              _outputDirController.text = r'C:\Temp\TSharkCaptures';
                            } else if (val == RemoteOsType.linux &&
                                _outputDirController.text.trim() ==
                                    r'C:\Temp\TSharkCaptures') {
                              _outputDirController.text = '/tmp/tshark_captures';
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _outputDirController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Remote Capture Output Folder',
                        hintText: '/tmp/tshark_captures',
                        prefixIcon: Icon(Icons.folder_outlined, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Custom Remote TShark Path (Optional)
              TextField(
                controller: _customTSharkController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Custom Remote TShark Path (Optional)',
                  hintText: 'Leave blank to auto-detect (/usr/bin/tshark or Program Files)',
                  prefixIcon: Icon(Icons.terminal, size: 18),
                ),
              ),
              const SizedBox(height: 8),

              // Use sudo toggle (Linux)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Prefix TShark with "sudo -n" (Linux)',
                  style: TextStyle(fontSize: 12.5),
                ),
                subtitle: const Text(
                  'Enable if logging in as a non-root Linux user with passwordless sudo.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                value: _useSudo,
                onChanged: (val) => setState(() => _useSudo = val),
                activeThumbColor: AppTheme.accentCyan,
              ),

              const Divider(height: 20, color: AppTheme.borderColor),

              // Test Connection Bar
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt, size: 16),
                    label: Text(
                      _isTesting ? 'Connecting via SSH...' : 'Test SSH & Verify TShark',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentCyan,
                      side: const BorderSide(color: AppTheme.accentCyan),
                    ),
                  ),
                ],
              ),

              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_testResult!.success
                            ? AppTheme.accentEmerald
                            : AppTheme.accentRed)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_testResult!.success
                              ? AppTheme.accentEmerald
                              : AppTheme.accentRed)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _testResult!.success
                                ? Icons.check_circle
                                : Icons.error_outline,
                            size: 16,
                            color: _testResult!.success
                                ? AppTheme.accentEmerald
                                : AppTheme.accentRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!.success
                                  ? 'SSH Connected • ${_testResult!.detectedOs.label}'
                                  : 'Connection Test Failed',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _testResult!.success
                                    ? AppTheme.accentEmerald
                                    : AppTheme.accentRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_testResult!.success) ...[
                        Text(
                          'Engine: ${_testResult!.tsharkVersion ?? "TShark Ready"}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                        Text(
                          'Discovered Network Adapters: ${_testResult!.interfaces.length} (${_testResult!.interfaces.take(4).map((i) => i.displayName).join(", ")}${_testResult!.interfaces.length > 4 ? "..." : ""})',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ] else ...[
                        Text(
                          _testResult!.errorMessage ?? 'Unknown SSH error',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: Text(isEdit ? 'Save Changes' : 'Add Machine'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }
}
