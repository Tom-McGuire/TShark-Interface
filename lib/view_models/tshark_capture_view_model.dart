import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/active_capture_session.dart';
import '../models/capture_config.dart';
import '../models/capture_history_item.dart';
import '../models/capture_interface.dart';
import '../models/capture_preset.dart';
import '../services/capture_storage_service.dart';
import '../services/system_service.dart';
import '../services/tshark_service.dart';

class TSharkCaptureViewModel extends ChangeNotifier {
  TSharkCaptureViewModel({
    TSharkService? tsharkService,
    CaptureStorageService? storageService,
  })  : _tsharkService = tsharkService ?? TSharkService(),
        _storageService = storageService ?? CaptureStorageService() {
    init();
  }

  final TSharkService _tsharkService;
  final CaptureStorageService _storageService;

  // Engine state
  String? _tsharkPath;
  String? get tsharkPath => _tsharkPath;
  bool get hasTShark => _tsharkPath != null && _tsharkPath!.isNotEmpty;

  String? _tsharkVersion;
  String? get tsharkVersion => _tsharkVersion;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  // Interfaces
  List<CaptureInterface> _interfaces = [];
  List<CaptureInterface> get interfaces => _interfaces;

  CaptureInterface? _selectedInterface;
  CaptureInterface? get selectedInterface => _selectedInterface;

  // Presets
  List<CapturePreset> _presets = [];
  List<CapturePreset> get presets => _presets;

  String? _activePresetId = 'all_traffic';
  String? get activePresetId => _activePresetId;

  // Recovery policy & interrupted session
  RecoveryPolicy _recoveryPolicy = RecoveryPolicy.prompt;
  RecoveryPolicy get recoveryPolicy => _recoveryPolicy;

  ActiveCaptureSession? _interruptedSession;
  ActiveCaptureSession? get interruptedSession => _interruptedSession;

  // Config fields
  CaptureMode _mode = CaptureMode.manual;
  CaptureMode get mode => _mode;

  int _durationMinutes = 10;
  int get durationMinutes => _durationMinutes;

  int _durationHours = 0;
  int get durationHours => _durationHours;

  int _packetCountLimit = 10000;
  int get packetCountLimit => _packetCountLimit;

  int _ringRotateMinutes = 10;
  int get ringRotateMinutes => _ringRotateMinutes;

  int _ringRotateFilesizeMb = 100;
  int get ringRotateFilesizeMb => _ringRotateFilesizeMb;

  int _ringFilesCount = 5;
  int get ringFilesCount => _ringFilesCount;

  bool _ringRotateBySize = false;
  bool get ringRotateBySize => _ringRotateBySize;

  String _captureFilter = '';
  String get captureFilter => _captureFilter;

  int _snaplen = 0; // 0 = Full packet
  int get snaplen => _snaplen;

  bool _promiscuous = true;
  bool get promiscuous => _promiscuous;

  String _outputDirectory = '';
  String get outputDirectory => _outputDirectory;

  String _filePrefix = 'capture';
  String get filePrefix => _filePrefix;

  bool _createSubfolder = true;
  bool get createSubfolder => _createSubfolder;

  bool _runDetached = false;
  bool get runDetached => _runDetached;

  // Active session
  ActiveCaptureSession? _activeSession;
  ActiveCaptureSession? get activeSession => _activeSession;
  bool get isCapturing => _activeSession != null;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  int _currentCaptureSizeBytes = 0;
  int get currentCaptureSizeBytes => _currentCaptureSizeBytes;

  Timer? _tickerTimer;
  Process? _activeProcess;

  // History
  List<CaptureHistoryItem> _history = [];
  List<CaptureHistoryItem> get history => _history;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final customPath = await _storageService.loadCustomTSharkPath();
      if (customPath != null && customPath.isNotEmpty) {
        _tsharkPath = customPath;
      } else {
        _tsharkPath = await _tsharkService.findTSharkPath();
      }

      if (_tsharkPath != null) {
        _tsharkVersion = await _tsharkService.getVersion(_tsharkPath!);
        _interfaces = await _tsharkService.getInterfaces(_tsharkPath!);
      }

      // Load default output directory
      _outputDirectory = (await _storageService.loadDefaultOutputDirectory()) ?? '';

      // Match last interface
      final lastIdx = await _storageService.loadLastInterfaceIndex();
      if (lastIdx != null && _interfaces.isNotEmpty) {
        final match = _interfaces.where((i) => i.index == lastIdx);
        _selectedInterface = match.isNotEmpty ? match.first : _interfaces.first;
      } else if (_interfaces.isNotEmpty) {
        // Prefer Wi-Fi or Ethernet if available
        final preferred = _interfaces.firstWhere(
          (i) =>
              (i.friendlyName?.toLowerCase().contains('wi-fi') ?? false) ||
              (i.friendlyName?.toLowerCase().contains('ethernet') ?? false),
          orElse: () => _interfaces.first,
        );
        _selectedInterface = preferred;
      }

      // Load presets & history
      _presets = [...CapturePreset.builtInPresets, ...await _storageService.loadCustomPresets()];
      _history = await _storageService.loadHistory();
      _recoveryPolicy = await _storageService.loadDefaultRecoveryPolicy();

      // Check if session was already running in background
      await checkExistingSession();
    } catch (e) {
      _errorMessage = 'Init failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshInterfaces() async {
    if (_tsharkPath == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _interfaces = await _tsharkService.getInterfaces(_tsharkPath!);
      if (_interfaces.isNotEmpty && _selectedInterface == null) {
        _selectedInterface = _interfaces.first;
      }
    } catch (e) {
      _errorMessage = 'Failed to refresh interfaces: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setCustomTSharkPath(String path) async {
    final clean = path.trim();
    if (clean.isNotEmpty && !File(clean).existsSync()) {
      _errorMessage = 'Executable not found at: $clean';
      notifyListeners();
      return;
    }

    _tsharkPath = clean.isEmpty ? await _tsharkService.findTSharkPath() : clean;
    await _storageService.saveCustomTSharkPath(clean);

    if (_tsharkPath != null) {
      _tsharkVersion = await _tsharkService.getVersion(_tsharkPath!);
      await refreshInterfaces();
    } else {
      _tsharkVersion = null;
      _interfaces = [];
    }
    notifyListeners();
  }

  Future<void> checkExistingSession() async {
    final session = await _storageService.loadActiveSession();
    if (session == null) return;

    final isAlive = await _tsharkService.isProcessAlive(session.pid);
    if (isAlive) {
      _activeSession = session;
      _statusMessage = 'Reconnected to background capture (PID ${session.pid}).';
      _startSessionTicker();
    } else {
      // Process is dead: system rebooted, crashed, or terminated unexpectedly.
      // 1. Record interrupted capture in history if target file was created
      try {
        final size = await _tsharkService.getCaptureSizeBytes(session.targetFilePath);
        if (size > 0) {
          final historyItem = CaptureHistoryItem(
            filePath: session.targetFilePath,
            fileName: p.basename(session.targetFilePath),
            timestamp: session.startedAt,
            fileSizeBytes: size,
            interfaceName: session.interfaceName,
            filter: session.filter,
          );
          await _storageService.addHistoryItem(historyItem);
          _history = await _storageService.loadHistory();
        }
      } catch (_) {}

      // 2. Clear previous active session file
      await _storageService.clearActiveSession();
      _activeSession = null;

      // 3. Handle recovery policy
      if (session.recoveryPolicy.isAuto) {
        if (session.config != null) {
          applyConfig(session.config!);
          _statusMessage =
              'Auto-restored capture after system reboot on ${session.config!.interface.displayName}.';
          // Start fresh capture automatically
          unawaited(startCapture());
        }
      } else if (session.recoveryPolicy.isPrompt) {
        _interruptedSession = session;
      }
    }
    notifyListeners();
  }

  // Configuration setters
  void setSelectedInterface(CaptureInterface? iface) {
    _selectedInterface = iface;
    if (iface != null) {
      _storageService.saveLastInterfaceIndex(iface.index);
    }
    notifyListeners();
  }

  void setMode(CaptureMode val) {
    _mode = val;
    notifyListeners();
  }

  void setDurationMinutes(int minutes) {
    _durationMinutes = minutes.clamp(1, 1440);
    notifyListeners();
  }

  void setDurationHours(int hours) {
    _durationHours = hours.clamp(0, 168);
    notifyListeners();
  }

  void setPacketCountLimit(int count) {
    _packetCountLimit = count.clamp(10, 10000000);
    notifyListeners();
  }

  void setRingRotateMinutes(int minutes) {
    _ringRotateMinutes = minutes.clamp(1, 1440);
    notifyListeners();
  }

  void setRingRotateFilesizeMb(int mb) {
    _ringRotateFilesizeMb = mb.clamp(1, 10240);
    notifyListeners();
  }

  void setRingFilesCount(int count) {
    _ringFilesCount = count.clamp(2, 500);
    notifyListeners();
  }

  void setRingRotateBySize(bool bySize) {
    _ringRotateBySize = bySize;
    notifyListeners();
  }

  void setCaptureFilter(String filter) {
    _captureFilter = filter;
    _activePresetId = null; // Custom edit
    notifyListeners();
  }

  void setSnaplen(int len) {
    _snaplen = len.clamp(0, 65535);
    notifyListeners();
  }

  void setPromiscuous(bool val) {
    _promiscuous = val;
    notifyListeners();
  }

  void setRecoveryPolicy(RecoveryPolicy val) {
    _recoveryPolicy = val;
    notifyListeners();
  }

  Future<void> setDefaultRecoveryPolicy(RecoveryPolicy val) async {
    _recoveryPolicy = val;
    await _storageService.saveDefaultRecoveryPolicy(val);
    notifyListeners();
  }

  void applyConfig(CaptureConfig config) {
    final match = _interfaces.where((i) => i.index == config.interface.index);
    if (match.isNotEmpty) {
      _selectedInterface = match.first;
    } else {
      _selectedInterface = config.interface;
    }

    _outputDirectory = config.outputDirectory;
    _filePrefix = config.filePrefix;
    _createSubfolder = config.createSubfolder;
    _mode = config.mode;
    _durationMinutes = config.durationMinutes;
    _durationHours = config.durationHours;
    _ringRotateMinutes = config.ringRotateMinutes;
    _ringRotateFilesizeMb = config.ringRotateFilesizeMb;
    _ringFilesCount = config.ringFilesCount;
    _ringRotateBySize = config.ringRotateBySize;
    _packetCountLimit = config.packetCountLimit;
    _captureFilter = config.captureFilter;
    _snaplen = config.snaplen;
    _promiscuous = config.promiscuous;
    _recoveryPolicy = config.recoveryPolicy;
    _activePresetId = null;
    notifyListeners();
  }

  Future<void> resumeInterruptedCapture() async {
    if (_interruptedSession == null) return;
    final session = _interruptedSession!;
    _interruptedSession = null;
    if (session.config != null) {
      applyConfig(session.config!);
    }
    notifyListeners();
    await startCapture();
  }

  void loadInterruptedSettings() {
    if (_interruptedSession == null) return;
    final session = _interruptedSession!;
    _interruptedSession = null;
    if (session.config != null) {
      applyConfig(session.config!);
      _statusMessage = 'Loaded settings from previous interrupted session.';
    }
    notifyListeners();
  }

  void dismissInterruptedSession() {
    _interruptedSession = null;
    notifyListeners();
  }

  void setOutputDirectory(String dir) {
    _outputDirectory = dir;
    _storageService.saveDefaultOutputDirectory(dir);
    notifyListeners();
  }

  void setFilePrefix(String prefix) {
    _filePrefix = prefix.trim();
    notifyListeners();
  }

  void setCreateSubfolder(bool val) {
    _createSubfolder = val;
    notifyListeners();
  }

  void setRunDetached(bool val) {
    _runDetached = val;
    notifyListeners();
  }

  void applyPreset(CapturePreset preset) {
    _activePresetId = preset.id;
    _captureFilter = preset.filter;
    _mode = preset.mode;
    _snaplen = preset.snaplen;
    _ringFilesCount = preset.ringFilesCount;
    _ringRotateMinutes = preset.ringRotateMinutes;
    _ringRotateFilesizeMb = preset.ringRotateFilesizeMb;
    _ringRotateBySize = preset.ringRotateBySize;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearStatus() {
    _statusMessage = null;
    notifyListeners();
  }

  CaptureConfig get currentConfig {
    return CaptureConfig(
      interface: _selectedInterface ??
          const CaptureInterface(index: '1', name: 'Default Interface'),
      outputDirectory: _outputDirectory,
      filePrefix: _filePrefix.isNotEmpty ? _filePrefix : 'capture',
      createSubfolder: _createSubfolder,
      mode: _mode,
      durationMinutes: _durationMinutes,
      durationHours: _durationHours,
      ringRotateMinutes: _ringRotateMinutes,
      ringRotateFilesizeMb: _ringRotateFilesizeMb,
      ringFilesCount: _ringFilesCount,
      ringRotateBySize: _ringRotateBySize,
      packetCountLimit: _packetCountLimit,
      captureFilter: _captureFilter,
      snaplen: _snaplen,
      promiscuous: _promiscuous,
      recoveryPolicy: _recoveryPolicy,
    );
  }

  String get previewCommandLine {
    if (_tsharkPath == null || _selectedInterface == null) {
      return '# Select a capture interface to preview the command';
    }

    final dummyFilename = '${_filePrefix.isNotEmpty ? _filePrefix : 'capture'}_YYYYMMDD_HHMMSS.pcapng';
    final previewOutPath = _createSubfolder
        ? p.join(_outputDirectory, 'Capture_YYYYMMDD_HHMMSS', dummyFilename)
        : p.join(_outputDirectory, dummyFilename);

    return _tsharkService.buildDisplayCommandLine(
      tsharkPath: _tsharkPath!,
      config: currentConfig,
      fullOutputPath: previewOutPath,
    );
  }

  Future<bool> startCapture() async {
    if (!hasTShark) {
      _errorMessage = 'TShark executable was not detected on this system.';
      notifyListeners();
      return false;
    }

    if (_selectedInterface == null) {
      _errorMessage = 'Please choose a network interface to capture.';
      notifyListeners();
      return false;
    }

    if (_outputDirectory.isEmpty) {
      _errorMessage = 'Please select a destination storage directory.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final config = currentConfig;
      final result = await _tsharkService.startCapture(
        tsharkPath: _tsharkPath!,
        config: config,
        detached: _runDetached,
      );

      _activeProcess = result.process;

      _activeSession = ActiveCaptureSession(
        pid: result.pid,
        startedAt: DateTime.now(),
        outputDirectory: result.targetDirectory,
        targetFilePath: result.targetFilePath,
        mode: config.mode,
        interfaceName: config.interface.displayName,
        commandLine: result.commandLine,
        filter: config.captureFilter,
        snaplen: config.snaplen,
        isDetached: _runDetached,
        config: config,
        recoveryPolicy: config.recoveryPolicy,
      );

      await _storageService.saveActiveSession(_activeSession!);
      _startSessionTicker();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to launch TShark: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (_activeSession == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final session = _activeSession!;
      await _tsharkService.stopCapture(session.pid);

      if (_activeProcess != null) {
        _activeProcess!.kill();
        _activeProcess = null;
      }

      // Add to history if target file was generated
      final size = await _tsharkService.getCaptureSizeBytes(session.targetFilePath);
      final historyItem = CaptureHistoryItem(
        filePath: session.targetFilePath,
        fileName: p.basename(session.targetFilePath),
        timestamp: session.startedAt,
        fileSizeBytes: size,
        interfaceName: session.interfaceName,
        filter: session.filter,
      );
      await _storageService.addHistoryItem(historyItem);
      _history = await _storageService.loadHistory();

      await _storageService.clearActiveSession();
      _activeSession = null;
      _stopSessionTicker();
      _statusMessage = 'Capture saved successfully.';
    } catch (e) {
      _errorMessage = 'Error stopping capture: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startSessionTicker() {
    _stopSessionTicker();
    _elapsed = _activeSession?.elapsed ?? Duration.zero;

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_activeSession == null) {
        timer.cancel();
        return;
      }

      _elapsed = _activeSession!.elapsed;

      // Every 3 seconds, poll capture file size and verify process
      if (timer.tick % 3 == 0) {
        _currentCaptureSizeBytes =
            await _tsharkService.getCaptureSizeBytes(_activeSession!.targetFilePath);

        // Check if process finished automatically (e.g. timed or packet count reached)
        final alive = await _tsharkService.isProcessAlive(_activeSession!.pid);
        if (!alive) {
          await stopCapture();
          return;
        }
      }
      notifyListeners();
    });
  }

  void _stopSessionTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _elapsed = Duration.zero;
    _currentCaptureSizeBytes = 0;
  }

  Future<void> openActiveDirectory() async {
    final path = _activeSession?.outputDirectory ?? _outputDirectory;
    if (path.isNotEmpty) {
      await SystemService.openFolder(path);
    }
  }

  Future<void> openHistoryItemFolder(CaptureHistoryItem item) async {
    final parent = p.dirname(item.filePath);
    await SystemService.openFolder(parent);
  }

  Future<void> openHistoryItemInWireshark(CaptureHistoryItem item) async {
    await SystemService.openInWireshark(item.filePath);
  }

  Future<void> removeHistoryItem(CaptureHistoryItem item) async {
    await _storageService.removeHistoryItem(item.filePath);
    _history = await _storageService.loadHistory();
    notifyListeners();
  }

  String formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String formatBytes(int bytes) {
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
  void dispose() {
    _stopSessionTicker();
    super.dispose();
  }
}
