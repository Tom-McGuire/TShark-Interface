import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  @override
  void initState() {
    super.initState();
    _tsharkPathController = TextEditingController(text: widget.viewModel.tsharkPath ?? '');
    _defaultDirController = TextEditingController(text: widget.viewModel.outputDirectory);
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
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      title: const Row(
        children: [
          Icon(Icons.settings, color: AppTheme.accentCyan, size: 20),
          SizedBox(width: 8),
          Text('Capture Engine Settings', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TShark Executable Path
              const Text(
                'TShark Executable Location',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Leave blank to automatically detect Wireshark installation in default system paths.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tsharkPathController,
                      style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                      decoration: const InputDecoration(
                        hintText: r'C:\Program Files\Wireshark\tshark.exe',
                        hintStyle: TextStyle(fontSize: 11, color: Colors.white30),
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
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Default Output Directory
              const Text(
                'Default Output Directory',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Where capture PCAP files and subdirectories are saved by default.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _defaultDirController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: r'C:\Users\username\Documents\TSharkCaptures',
                        hintStyle: TextStyle(fontSize: 11, color: Colors.white30),
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
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Detected Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F141C),
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
                            style: const TextStyle(fontSize: 11, color: Colors.white60),
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save Settings'),
        ),
      ],
    );
  }
}
