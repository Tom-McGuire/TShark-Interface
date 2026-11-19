import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.viewModel});

  final TSharkCaptureViewModel viewModel;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _tsharkPathController;
  late TextEditingController _defaultDirController;
  late RecoveryPolicy _defaultPolicy;

  @override
  void initState() {
    super.initState();
    _tsharkPathController = TextEditingController(text: widget.viewModel.tsharkPath ?? '');
    _defaultDirController = TextEditingController(text: widget.viewModel.outputDirectory);
    _defaultPolicy = widget.viewModel.recoveryPolicy;
  }

  @override
  void dispose() {
    _tsharkPathController.dispose();
    _defaultDirController.dispose();
    super.dispose();
  }

  Future<void> _pickTSharkExe() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Select tshark executable',
      type: FileType.custom,
      allowedExtensions: ['exe', ''],
    );
    if (files.isNotEmpty && files.first.path != null) {
      _tsharkPathController.text = files.first.path!;
    }
  }

  Future<void> _pickDefaultFolder() async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Default Capture Storage Folder',
    );
    if (result != null) {
      _defaultDirController.text = result;
    }
  }

  void _save() async {
    await widget.viewModel.setCustomTSharkPath(_tsharkPathController.text.trim());
    if (_defaultDirController.text.trim().isNotEmpty) {
      widget.viewModel.setOutputDirectory(_defaultDirController.text.trim());
    }
    await widget.viewModel.setDefaultRecoveryPolicy(_defaultPolicy);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      title: Row(
        children: [
          Icon(Icons.settings, color: AppTheme.accentCyan, size: 20),
          const SizedBox(width: 8),
          Text(
            'Capture Engine Settings',
            style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TShark Executable Path
              Text(
                'TShark Executable Location',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Leave blank to automatically detect Wireshark installation in default system paths.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tsharkPathController,
                      style: AppTheme.monoTextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: r'C:\Program Files\Wireshark\tshark.exe',
                        hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickTSharkExe,
                    icon: const Icon(Icons.file_open, size: 14),
                    label: const Text('Browse'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentCyan,
                      side: BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Default Output Directory
              Text(
                'Default Output Directory',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Where capture PCAP files and subdirectories are saved by default.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _defaultDirController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: r'C:\Users\username\Documents\TSharkCaptures',
                        hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDefaultFolder,
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: const Text('Browse'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentCyan,
                      side: BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Default Recovery Policy
              Text(
                'Default Reboot & Crash Recovery Policy',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Initial policy assigned when configuring new packet captures.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RecoveryPolicy>(
                initialValue: _defaultPolicy,
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
                onChanged: (val) {
                  if (val != null) setState(() => _defaultPolicy = val);
                },
              ),
              const SizedBox(height: 12),

              // Unattended Setup Tip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.accentCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip for Unattended Machines: Set policy to "Auto-Restart on Boot", then place a shortcut to T-Shark Interface in your Windows Startup folder (press Win+R and type "shell:startup").',
                        style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Detected Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.viewModel.hasTShark ? Icons.check_circle : Icons.warning_amber,
                      color: widget.viewModel.hasTShark
                          ? AppTheme.accentEmerald
                          : AppTheme.accentAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.viewModel.hasTShark
                                ? 'Engine Detected'
                                : 'TShark Not Found',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.viewModel.hasTShark
                                  ? AppTheme.accentEmerald
                                  : AppTheme.accentAmber,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.viewModel.tsharkVersion ?? 'Please ensure Wireshark/TShark is installed.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: AppTheme.isDark ? Colors.black : Colors.white,
          ),
          child: const Text('Save Settings'),
        ),
      ],
    );
  }
}
