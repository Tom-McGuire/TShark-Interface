import 'package:material_ui/material_ui.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';
import 'package:tshark_interface/ui/views/widgets/section_card.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

/// Configuration card for packet slicing (snaplen), promiscuous mode,
/// capture storage path/file prefix, and reboot/crash recovery policy.
class StorageAndRecoveryCard extends StatefulWidget {
  const StorageAndRecoveryCard({
    super.key,
    required this.vm,
    required this.onPickOutputFolder,
  });

  final TSharkCaptureViewModel vm;
  final VoidCallback onPickOutputFolder;

  @override
  State<StorageAndRecoveryCard> createState() => _StorageAndRecoveryCardState();
}

class _StorageAndRecoveryCardState extends State<StorageAndRecoveryCard> {
  final _filePrefixController = TextEditingController();
  final _filePrefixFocusNode = FocusNode();
  final _remoteOutputDirController = TextEditingController();
  final _remoteOutputDirFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filePrefixController.text = widget.vm.filePrefix;
    _remoteOutputDirController.text = widget.vm.outputDirectory;
    _filePrefixFocusNode.addListener(_syncControllersIfUnfocused);
    _remoteOutputDirFocusNode.addListener(_syncControllersIfUnfocused);
  }

  @override
  void dispose() {
    _filePrefixFocusNode.removeListener(_syncControllersIfUnfocused);
    _remoteOutputDirFocusNode.removeListener(_syncControllersIfUnfocused);
    _filePrefixFocusNode.dispose();
    _remoteOutputDirFocusNode.dispose();
    _filePrefixController.dispose();
    _remoteOutputDirController.dispose();
    super.dispose();
  }

  void _syncControllersIfUnfocused() {
    if (!mounted) return;
    final vm = widget.vm;
    if (!_filePrefixFocusNode.hasFocus &&
        _filePrefixController.text != vm.filePrefix) {
      _filePrefixController.text = vm.filePrefix;
    }
    if (!_remoteOutputDirFocusNode.hasFocus &&
        _remoteOutputDirController.text != vm.outputDirectory) {
      _remoteOutputDirController.text = vm.outputDirectory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    _syncControllersIfUnfocused();

    return SectionCard(
      title: 'Packet Slicing & Storage Destination',
      icon: Icons.folder_zip_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Snaplen / Payload Slicing
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Packet Slice (Snaplen)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Truncates payload to reduce PCAP file size.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButton<int>(
                value: vm.snaplen,
                dropdownColor: AppTheme.surfaceElevated,
                iconEnabledColor: AppTheme.textSecondary,
                iconDisabledColor: AppTheme.textMuted,
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('Full Packets (Default)'),
                  ),
                  DropdownMenuItem(
                    value: 64,
                    child: Text('64 Bytes (L2-L3 Only)'),
                  ),
                  DropdownMenuItem(
                    value: 96,
                    child: Text('96 Bytes (Headers Only)'),
                  ),
                  DropdownMenuItem(
                    value: 128,
                    child: Text('128 Bytes (Headers+TOS)'),
                  ),
                  DropdownMenuItem(
                    value: 256,
                    child: Text('256 Bytes'),
                  ),
                ],
                onChanged:
                    vm.isCapturing ? null : (val) => vm.setSnaplen(val ?? 0),
              ),
            ],
          ),
          Divider(height: 24, color: AppTheme.borderColor),

          // Promiscuous Mode
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Promiscuous Mode',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Captures all network packets seen on the segment, not just packets addressed to this host.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            value: vm.promiscuous,
            onChanged:
                vm.isCapturing ? null : (val) => vm.setPromiscuous(val),
            activeThumbColor: AppTheme.accentCyan,
          ),
          Divider(height: 24, color: AppTheme.borderColor),

          // Output Storage Directory (Local Folder Picker vs Remote Path Input)
          Text(
            vm.isRemoteTarget
                ? 'Remote Destination Folder (on ${vm.selectedRemoteHost!.name})'
                : 'Destination Storage Folder',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (vm.isRemoteTarget)
            TextField(
              controller: _remoteOutputDirController,
              focusNode: _remoteOutputDirFocusNode,
              enabled: !vm.isCapturing,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: '/tmp/tshark_captures',
                prefixIcon: Icon(Icons.folder_outlined, size: 18),
              ),
              onChanged: (val) => vm.setOutputDirectory(val),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      vm.outputDirectory.isNotEmpty
                          ? vm.outputDirectory
                          : 'No directory chosen',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: vm.isCapturing ? null : widget.onPickOutputFolder,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Change'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentCyan,
                    side: BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // File Prefix & Subfolder Checkbox
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filePrefixController,
                  focusNode: _filePrefixFocusNode,
                  enabled: !vm.isCapturing,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'File Prefix',
                    hintText: 'capture',
                  ),
                  onChanged: (val) => vm.setFilePrefix(val),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Timestamp Subfolder',
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                  value: vm.createSubfolder,
                  onChanged: vm.isCapturing
                      ? null
                      : (val) => vm.setCreateSubfolder(val ?? true),
                  activeColor: AppTheme.accentCyan,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: AppTheme.borderColor),

          // Reboot & Crash Recovery Policy
          Text(
            'Reboot & Crash Recovery Policy',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Action to take if the system restarts or shuts down while capturing.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<RecoveryPolicy>(
            key: ValueKey(vm.recoveryPolicy),
            initialValue: vm.recoveryPolicy,
            isExpanded: true,
            dropdownColor: AppTheme.surfaceElevated,
            iconEnabledColor: AppTheme.textSecondary,
            iconDisabledColor: AppTheme.textMuted,
            style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.settings_backup_restore, size: 18),
            ),
            items: RecoveryPolicy.values.map((policy) {
              return DropdownMenuItem<RecoveryPolicy>(
                value: policy,
                child: Text(
                  '${policy.label} — ${policy.description}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                ),
              );
            }).toList(),
            onChanged: vm.isCapturing
                ? null
                : (val) {
                    if (val != null) vm.setRecoveryPolicy(val);
                  },
          ),
        ],
      ),
    );
  }
}
