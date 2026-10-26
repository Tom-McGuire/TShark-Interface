import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/active_capture_session.dart';
import '../models/capture_config.dart';
import '../models/capture_history_item.dart';
import '../models/capture_interface.dart';
import '../models/capture_preset.dart';
import '../models/remote_host.dart';
import '../services/capture_storage_service.dart';
import '../services/remote_ssh_service.dart';
import '../services/system_service.dart';
import '../services/tshark_service.dart';

class TSharkCaptureViewModel extends ChangeNotifier {
  TSharkCaptureViewModel({
    TSharkService? tsharkService,
    CaptureStorageService? storageService,
    RemoteSshService? remoteSshService,
  })  : _tsharkService = tsharkService ?? TSharkService(),
        _storageService = storageService ?? CaptureStorageService(),
        _remoteSshService =
            remoteSshService ?? RemoteSshService(tsharkService: tsharkService) {
    init();
  }

  final TSharkService _tsharkService;
  final CaptureStorageService _storageService;
  final RemoteSshService _remoteSshService;

  // Engine state (Local)
  String? _tsharkPath;
  String? get tsharkPath => _tsharkPath;
  bool get hasTShark =>
      isRemoteTarget || (_tsharkPath != null && _tsharkPath!.isNotEmpty);
  bool get hasLocalTShark => _tsharkPath != null && _tsharkPath!.isNotEmpty;

  String? _tsharkVersion;
  String? get tsharkVersion => _tsharkVersion;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  // Remote Hosts & Target Selection
  List<RemoteHost> _remoteHosts = [];
  List<RemoteHost> get remoteHosts => _remoteHosts;

  RemoteHost? _selectedRemoteHost;
  RemoteHost? get selectedRemoteHost => _selectedRemoteHost;
  bool get isRemoteTarget => _selectedRemoteHost != null;

  // Interfaces (for currently selected target: Local or Remote)
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

  String _localOutputDirectory = '';
  String _outputDirectory = '';
  String get outputDirectory => _outputDirectory;

  String _filePrefix = 'capture';
  String get filePrefix => _filePrefix;

  bool _createSubfolder = true;
  bool get createSubfolder => _createSubfolder;

  bool _runDetached = false;
  bool get runDetached => _runDetached;

  // Active sessions (Local + Multi-Remote)
  ActiveCaptureSession? _localActiveSession;
  ActiveCaptureSession? get localActiveSession => _localActiveSession;

  final Map<String, ActiveCaptureSession> _remoteSessions = {};
  Map<String, ActiveCaptureSession> get remoteSessions =>
      Map.unmodifiable(_remoteSessions);

  final Set<String> _pollingRemoteHostIds = {};
  final Set<String> _stoppingRemoteHostIds = {};

  bool isStoppingRemote(String hostId) => _stoppingRemoteHostIds.contains(hostId);
  bool isPollingRemote(String hostId) => _pollingRemoteHostIds.contains(hostId);

  List<ActiveCaptureSession> get unreachableRemoteSessions =>
      _remoteSessions.values.where((s) => s.isUnreachable).toList();

  int get totalActiveCapturesCount =>
      (_localActiveSession != null ? 1 : 0) +
      _remoteSessions.values.where((s) => !s.isUnreachable).length;

  /// Returns the active session for the currently selected Target Machine (Local or Remote).
  ActiveCaptureSession? get activeSession {
    if (isRemoteTarget) {
      return _remoteSessions[_selectedRemoteHost!.id];
    }
    return _localActiveSession;
  }

  bool get isCapturing {
    final s = activeSession;
    return s != null && !s.isUnreachable;
  }

  Duration _elapsed = Duration.zero;
  Duration get elapsed => activeSession?.elapsed ?? _elapsed;

  int _currentCaptureSizeBytes = 0;
  int get currentCaptureSizeBytes {
    if (isRemoteTarget) {
      return activeSession?.lastKnownSizeBytes ?? 0;
    }
    return _currentCaptureSizeBytes;
  }

  Timer? _tickerTimer;
  Process? _activeProcess;
  bool _isStopping = false;

  // History
  List<CaptureHistoryItem> _history = [];
  List<CaptureHistoryItem> get history => _history;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final customPath = await _storageService.loadCustomTSharkPath();
      if (customPath != null &&
          customPath.isNotEmpty &&
          TSharkService.isValidTSharkExecutable(customPath)) {
        _tsharkPath = customPath;
      } else {
        _tsharkPath = await _tsharkService.findTSharkPath();
      }

      if (_tsharkPath != null) {
        _tsharkVersion = await _tsharkService.getVersion(_tsharkPath!);
        _interfaces = await _tsharkService.getInterfaces(_tsharkPath!);
      }

      // Load default local output directory
      _localOutputDirectory =
          (await _storageService.loadDefaultOutputDirectory()) ?? '';
      _outputDirectory = _localOutputDirectory;

      // Match last local interface by device name first (stable across reboots), then index
      await _selectPreferredLocalInterface();

      // Load presets, history, and remote hosts
      _presets = [
        ...CapturePreset.builtInPresets,
        ...await _storageService.loadCustomPresets(),
      ];
      _history = await _storageService.loadHistory();
      _recoveryPolicy = await _storageService.loadDefaultRecoveryPolicy();
      _remoteHosts = await _storageService.loadRemoteHosts();

      // Check if local session was already running in background
      await checkExistingSession();

      // Check any stored ongoing remote sessions over SSH
      unawaited(checkExistingRemoteSessions());
    } catch (e) {
      _errorMessage = 'Init failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _selectPreferredLocalInterface() async {
    _selectedInterface = null;
    final lastName = await _storageService.loadLastInterfaceName();
    final lastIdx = await _storageService.loadLastInterfaceIndex();
    if (lastName != null && _interfaces.isNotEmpty) {
      final match = _interfaces.where((i) => i.name == lastName);
      if (match.isNotEmpty) {
        _selectedInterface = match.first;
      }
    }
    if (_selectedInterface == null && lastIdx != null && _interfaces.isNotEmpty) {
      final match = _interfaces.where((i) => i.index == lastIdx);
      if (match.isNotEmpty) {
        _selectedInterface = match.first;
      }
    }
    if (_selectedInterface == null && _interfaces.isNotEmpty) {
      final preferred = _interfaces.firstWhere(
        (i) =>
            (i.friendlyName?.toLowerCase().contains('wi-fi') ?? false) ||
            (i.friendlyName?.toLowerCase().contains('ethernet') ?? false) ||
            i.name.toLowerCase().startsWith('eth') ||
            i.name.toLowerCase().startsWith('en'),
        orElse: () => _interfaces.first,
      );
      _selectedInterface = preferred;
    }
  }

  /// Switches the target machine between Local Machine (`null`) and a saved [RemoteHost].
  Future<void> selectTargetHost(RemoteHost? host) async {
    if (_selectedRemoteHost == host) return;
    _selectedRemoteHost = host;
    _errorMessage = null;
    _selectedInterface = null;
    _interfaces = [];

    await _storageService.saveLastSelectedTargetId(host?.id);

    if (host == null) {
      _outputDirectory = _localOutputDirectory;
      notifyListeners();
      await refreshInterfaces();
    } else {
      _outputDirectory = host.defaultOutputDirectory;
      notifyListeners();
      await refreshInterfaces();
    }
  }

  Future<void> refreshInterfaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isRemoteTarget) {
        final host = _selectedRemoteHost!;
        _interfaces = await _remoteSshService.getRemoteInterfaces(host);
        if (_interfaces.isNotEmpty) {
          // Prefer eth0 / ens / wlan / Ethernet over loopback
          _selectedInterface = _interfaces.firstWhere(
            (i) =>
                !i.name.toLowerCase().contains('loopback') &&
                i.name.toLowerCase() != 'lo' &&
                !i.name.toLowerCase().contains('etwdump'),
            orElse: () => _interfaces.first,
          );
        }
      } else {
        if (_tsharkPath == null) {
          _interfaces = [];
          return;
        }
        _interfaces = await _tsharkService.getInterfaces(_tsharkPath!);
        if (_interfaces.isNotEmpty && _selectedInterface == null) {
          await _selectPreferredLocalInterface();
        }
      }
    } catch (e) {
      _errorMessage = isRemoteTarget
          ? 'Failed to query interfaces on ${_selectedRemoteHost!.name}: $e'
          : 'Failed to refresh interfaces: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remote Host CRUD & Testing
  Future<RemoteConnectionTestResult> testRemoteHostConnection(
    RemoteHost host,
  ) async {
    final result = await _remoteSshService.testConnection(host);
    // If host already exists in saved list, update its cached reachability and OS
    final idx = _remoteHosts.indexWhere((h) => h.id == host.id);
    if (idx >= 0) {
      final updated = _remoteHosts[idx].copyWith(
        osType: _remoteHosts[idx].osType == RemoteOsType.auto
            ? result.detectedOs
            : _remoteHosts[idx].osType,
        detectedTSharkVersion: result.tsharkVersion,
        isReachable: result.success,
      );
      _remoteHosts[idx] = updated;
      await _storageService.saveRemoteHost(updated);
      if (_selectedRemoteHost?.id == updated.id) {
        _selectedRemoteHost = updated;
      }
      notifyListeners();
    }
    return result;
  }

  Future<void> saveRemoteHost(RemoteHost host) async {
    await _storageService.saveRemoteHost(host);
    _remoteHosts = await _storageService.loadRemoteHosts();
    if (_selectedRemoteHost?.id == host.id) {
      _selectedRemoteHost = host;
    }
    notifyListeners();
  }

  Future<void> deleteRemoteHost(String id) async {
    if (_selectedRemoteHost?.id == id) {
      await selectTargetHost(null);
    }
    _remoteSessions.remove(id);
    await _storageService.removeRemoteSession(id);
    await _storageService.deleteRemoteHost(id);
    _remoteHosts = await _storageService.loadRemoteHosts();
    notifyListeners();
  }

  /// Checks all stored remote sessions on app startup and reconnects or flags unreachable hosts.
  Future<void> checkExistingRemoteSessions() async {
    final stored = await _storageService.loadRemoteSessions();
    if (stored.isEmpty) return;

    for (final session in stored) {
      if (session.remoteHostId != null) {
        _remoteSessions[session.remoteHostId!] = session;
      }
    }
    _ensureTickerRunning();
    notifyListeners();

    // Query each remote session concurrently
    await Future.wait(
      stored
          .where((s) => s.remoteHostId != null)
          .map((s) => refreshRemoteSessionStatus(s.remoteHostId!, isStartupCheck: true)),
    );
  }

  /// Polls a single remote host over SSH to update its active session status.
  Future<void> refreshRemoteSessionStatus(
    String hostId, {
    bool isStartupCheck = false,
  }) async {
    if (_pollingRemoteHostIds.contains(hostId)) return;
    final session = _remoteSessions[hostId];
    if (session == null) return;

    final hostMatch = _remoteHosts.where((h) => h.id == hostId);
    if (hostMatch.isEmpty) {
      // Host profile was deleted; clean up orphaned session
      await clearRemoteSession(hostId);
      return;
    }
    final host = hostMatch.first;

    _pollingRemoteHostIds.add(hostId);
    notifyListeners();

    try {
      final check = await _remoteSshService.checkRemoteSessionStatus(host, session);
      if (!check.isReachable) {
        // Host is offline / unreachable: flag it so user can Retry or Clear/Forget
        final updated = session.copyWith(
          isUnreachable: true,
          unreachableReason:
              'Host ${host.host} is unreachable (may be powered off or disconnected).',
        );
        _remoteSessions[hostId] = updated;
      } else if (check.isAlive) {
        // Remote capture is still actively running!
        final updated = session.copyWith(
          isUnreachable: false,
          unreachableReason: null,
          lastKnownSizeBytes: check.sizeBytes,
        );
        _remoteSessions[hostId] = updated;
        await _storageService.saveRemoteSession(updated);
        if (isStartupCheck) {
          _statusMessage =
              'Reconnected to ongoing remote capture on ${host.name} (PID ${session.pid}).';
        }
      } else {
        // SSH succeeded, and PID is no longer running -> Capture finished!
        if (check.sizeBytes > 0) {
          final historyItem = CaptureHistoryItem(
            filePath: session.targetFilePath,
            fileName: p.basename(session.targetFilePath),
            timestamp: session.startedAt,
            fileSizeBytes: check.sizeBytes,
            interfaceName: '[${host.name}] ${session.interfaceName}',
            filter: session.filter,
          );
          await _storageService.addHistoryItem(historyItem);
          _history = await _storageService.loadHistory();
        }
        _remoteSessions.remove(hostId);
        await _storageService.removeRemoteSession(hostId);
        _statusMessage = 'Remote capture on ${host.name} finished.';
      }
    } finally {
      _pollingRemoteHostIds.remove(hostId);
      _ensureTickerRunning();
      notifyListeners();
    }
  }

  /// Refreshes status for all saved remote hosts that have a tracked session.
  Future<void> refreshAllRemoteSessions() async {
    final ids = _remoteSessions.keys.toList();
    await Future.wait(ids.map((id) => refreshRemoteSessionStatus(id)));
  }

  /// Clears a stored remote session from local memory without needing SSH connectivity.
  Future<void> clearRemoteSession(String hostId) async {
    final removed = _remoteSessions.remove(hostId);
    await _storageService.removeRemoteSession(hostId);
    if (removed != null) {
      _statusMessage =
          'Cleared stored session for ${removed.remoteHostName ?? "remote host"} from local memory.';
    }
    _ensureTickerRunning();
    notifyListeners();
  }

  Future<void> setCustomTSharkPath(String path) async {
    final clean = path.trim();
    if (clean.isNotEmpty) {
      if (!File(clean).existsSync()) {
        _errorMessage = 'Executable not found at: $clean';
        notifyListeners();
        return;
      }
      if (!TSharkService.isValidTSharkExecutable(clean)) {
        _errorMessage =
            'Selected file is not a valid TShark executable (must be named tshark or tshark.exe).';
        notifyListeners();
        return;
      }
    }

    _tsharkPath = clean.isEmpty ? await _tsharkService.findTSharkPath() : clean;
    await _storageService.saveCustomTSharkPath(clean);

    if (_tsharkPath != null) {
      _tsharkVersion = await _tsharkService.getVersion(_tsharkPath!);
      if (!isRemoteTarget) {
        await refreshInterfaces();
      }
    } else {
      _tsharkVersion = null;
      if (!isRemoteTarget) {
        _interfaces = [];
      }
    }
    notifyListeners();
  }

  Future<void> checkExistingSession() async {
    final session = await _storageService.loadActiveSession();
    if (session == null) return;

    final isAlive = await _tsharkService.isProcessAlive(session.pid);
    if (isAlive) {
      _localActiveSession = session;
      _statusMessage = 'Reconnected to background capture (PID ${session.pid}).';
      _ensureTickerRunning();
    } else {
      // Process is dead: system rebooted, crashed, or terminated unexpectedly.
      // 1. Record interrupted capture in history if target file was created
      try {
        String recordedFilePath = session.targetFilePath;
        if (session.mode == CaptureMode.ringBuffer) {
          final latest =
              await _tsharkService.findLatestPcapFile(session.outputDirectory);
          if (latest != null) {
            recordedFilePath = latest;
          }
        }
        final size = await _tsharkService.getCaptureSizeBytes(recordedFilePath);
        if (size > 0 || File(recordedFilePath).existsSync()) {
          final historyItem = CaptureHistoryItem(
            filePath: recordedFilePath,
            fileName: p.basename(recordedFilePath),
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
      _localActiveSession = null;

      // 3. Handle recovery policy
      if (session.recoveryPolicy.isAuto) {
        if (session.config != null) {
          applyConfig(session.config!);
          _statusMessage =
              'Auto-restored capture after system reboot on ${session.config!.interface.displayName}.';
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
    if (iface != null && !isRemoteTarget) {
      _storageService.saveLastInterfaceName(iface.name);
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
    final matchName = _interfaces.where((i) => i.name == config.interface.name);
    if (matchName.isNotEmpty) {
      _selectedInterface = matchName.first;
    } else {
      final matchIdx =
          _interfaces.where((i) => i.index == config.interface.index);
      if (matchIdx.isNotEmpty) {
        _selectedInterface = matchIdx.first;
      } else {
        _selectedInterface = config.interface;
      }
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
    if (!isRemoteTarget) {
      _localOutputDirectory = dir;
      _storageService.saveDefaultOutputDirectory(dir);
    }
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
    if (_selectedInterface == null) {
      return '# Select a capture interface to preview the command';
    }

    final dummyFilename =
        '${_filePrefix.isNotEmpty ? _filePrefix : 'capture'}_YYYYMMDD_HHMMSS.pcapng';

    if (isRemoteTarget) {
      final host = _selectedRemoteHost!;
      final baseDir = _outputDirectory.isNotEmpty
          ? _outputDirectory
          : host.defaultOutputDirectory;
      final subDir = _createSubfolder
          ? RemoteSshService.joinRemotePath(
              host.osType,
              baseDir,
              'Capture_YYYYMMDD_HHMMSS',
            )
          : baseDir;
      final remoteOutPath = RemoteSshService.joinRemotePath(
        host.osType,
        subDir,
        dummyFilename,
      );
      return _remoteSshService.buildRemoteDisplayCommandLine(
        host: host,
        config: currentConfig,
        fullRemoteOutputPath: remoteOutPath,
      );
    }

    if (_tsharkPath == null) {
      return '# TShark executable not detected on local machine';
    }

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
    if (_selectedInterface == null) {
      _errorMessage = 'Please choose a network interface to capture.';
      notifyListeners();
      return false;
    }

    if (_outputDirectory.isEmpty) {
      _errorMessage = 'Please specify a destination storage directory.';
      notifyListeners();
      return false;
    }

    if (isRemoteTarget) {
      return _startRemoteCapture(_selectedRemoteHost!);
    }

    if (!hasLocalTShark) {
      _errorMessage = 'TShark executable was not detected on this system.';
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
        onProcessExit: (exitCode) {
          if (exitCode != 0) {
            final recent = _tsharkService.recentStderr;
            final errDetails = recent.isNotEmpty
                ? ': ${recent.last}'
                : ' (exit code $exitCode)';
            _errorMessage =
                'TShark capture process exited unexpectedly$errDetails';
            notifyListeners();
          }
        },
      );

      _activeProcess = result.process;

      _localActiveSession = ActiveCaptureSession(
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

      await _storageService.saveActiveSession(_localActiveSession!);
      _ensureTickerRunning();

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

  Future<bool> _startRemoteCapture(RemoteHost host) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final config = currentConfig;
      final result = await _remoteSshService.startRemoteCapture(
        host: host,
        config: config,
      );

      final session = ActiveCaptureSession(
        pid: result.pid,
        startedAt: DateTime.now(),
        outputDirectory: result.targetDirectory,
        targetFilePath: result.targetFilePath,
        mode: config.mode,
        interfaceName: config.interface.displayName,
        commandLine: result.commandLine,
        filter: config.captureFilter,
        snaplen: config.snaplen,
        isDetached: true,
        config: config,
        recoveryPolicy: config.recoveryPolicy,
        isRemote: true,
        remoteHostId: host.id,
        remoteHostName: host.displayLabel,
      );

      _remoteSessions[host.id] = session;
      await _storageService.saveRemoteSession(session);
      _ensureTickerRunning();

      _statusMessage =
          'Started remote capture on ${host.name} (PID ${result.pid}).';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start remote capture on ${host.name}: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (isRemoteTarget && _selectedRemoteHost != null) {
      await stopRemoteCapture(_selectedRemoteHost!.id);
      return;
    }

    if (_isStopping || _localActiveSession == null) return;
    _isStopping = true;
    _isLoading = true;
    notifyListeners();

    try {
      final session = _localActiveSession!;
      await _tsharkService.stopCapture(session.pid);

      if (_activeProcess != null) {
        _activeProcess!.kill();
        _activeProcess = null;
      }

      // In ring-buffer mode, resolve the actual created file
      String recordedFilePath = session.targetFilePath;
      if (session.mode == CaptureMode.ringBuffer) {
        final latest =
            await _tsharkService.findLatestPcapFile(session.outputDirectory);
        if (latest != null) {
          recordedFilePath = latest;
        }
      }

      // Add to history if target file was generated
      final size = await _tsharkService.getCaptureSizeBytes(recordedFilePath);
      if (size > 0 || File(recordedFilePath).existsSync()) {
        final historyItem = CaptureHistoryItem(
          filePath: recordedFilePath,
          fileName: p.basename(recordedFilePath),
          timestamp: session.startedAt,
          fileSizeBytes: size,
          interfaceName: session.interfaceName,
          filter: session.filter,
        );
        await _storageService.addHistoryItem(historyItem);
        _history = await _storageService.loadHistory();
      }

      await _storageService.clearActiveSession();
      _localActiveSession = null;
      _currentCaptureSizeBytes = 0;
      _ensureTickerRunning();
      _statusMessage = 'Capture saved successfully.';
    } catch (e) {
      _errorMessage = 'Error stopping capture: $e';
    } finally {
      _isLoading = false;
      _isStopping = false;
      notifyListeners();
    }
  }

  Future<void> stopRemoteCapture(String hostId) async {
    if (_stoppingRemoteHostIds.contains(hostId)) return;
    final session = _remoteSessions[hostId];
    if (session == null) return;

    final hostMatch = _remoteHosts.where((h) => h.id == hostId);
    if (hostMatch.isEmpty) {
      await clearRemoteSession(hostId);
      return;
    }
    final host = hostMatch.first;

    _stoppingRemoteHostIds.add(hostId);
    if (_selectedRemoteHost?.id == hostId) {
      _isLoading = true;
    }
    notifyListeners();

    try {
      await _remoteSshService.stopRemoteCapture(host, session.pid);
      final check = await _remoteSshService.checkRemoteSessionStatus(host, session);
      final finalSize = check.sizeBytes > 0 ? check.sizeBytes : session.lastKnownSizeBytes;

      final historyItem = CaptureHistoryItem(
        filePath: session.targetFilePath,
        fileName: p.basename(session.targetFilePath),
        timestamp: session.startedAt,
        fileSizeBytes: finalSize,
        interfaceName: '[${host.name}] ${session.interfaceName}',
        filter: session.filter,
      );
      await _storageService.addHistoryItem(historyItem);
      _history = await _storageService.loadHistory();

      _remoteSessions.remove(hostId);
      await _storageService.removeRemoteSession(hostId);
      _ensureTickerRunning();
      _statusMessage =
          'Remote capture stopped on ${host.name} (saved to ${session.targetFilePath}).';
    } catch (e) {
      _errorMessage = 'Error stopping remote capture on ${host.name}: $e';
    } finally {
      _stoppingRemoteHostIds.remove(hostId);
      if (_selectedRemoteHost?.id == hostId) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  void _ensureTickerRunning() {
    final hasAnyActive =
        _localActiveSession != null || _remoteSessions.isNotEmpty;
    if (!hasAnyActive) {
      _stopSessionTicker();
      return;
    }
    if (_tickerTimer != null && _tickerTimer!.isActive) {
      return;
    }

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_localActiveSession == null && _remoteSessions.isEmpty) {
        _stopSessionTicker();
        return;
      }

      if (_localActiveSession != null) {
        _elapsed = _localActiveSession!.elapsed;
      }

      // Every 3 seconds, poll local capture file size and verify process
      if (_localActiveSession != null && timer.tick % 3 == 0) {
        if (_localActiveSession!.mode == CaptureMode.ringBuffer) {
          final latest = await _tsharkService.findLatestPcapFile(
            _localActiveSession!.outputDirectory,
          );
          if (latest != null) {
            _currentCaptureSizeBytes =
                await _tsharkService.getCaptureSizeBytes(latest);
          } else {
            _currentCaptureSizeBytes = await _tsharkService.getCaptureSizeBytes(
              _localActiveSession!.targetFilePath,
            );
          }
        } else {
          _currentCaptureSizeBytes = await _tsharkService.getCaptureSizeBytes(
            _localActiveSession!.targetFilePath,
          );
        }

        final alive =
            await _tsharkService.isProcessAlive(_localActiveSession!.pid);
        if (!alive) {
          await stopCapture();
          return;
        }
      }

      // Every 5 seconds, poll active (reachable) remote sessions over SSH
      if (_remoteSessions.isNotEmpty && timer.tick % 5 == 0) {
        final activeHostIds = _remoteSessions.entries
            .where((e) => !e.value.isUnreachable)
            .map((e) => e.key)
            .toList();
        for (final hostId in activeHostIds) {
          unawaited(refreshRemoteSessionStatus(hostId));
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
    if (isRemoteTarget) return;
    final path = _localActiveSession?.outputDirectory ?? _outputDirectory;
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
