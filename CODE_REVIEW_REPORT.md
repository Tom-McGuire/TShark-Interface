# T-Shark Interface — Comprehensive Code Review & Improvement Report

**Project Version:** `0.6.3-Beta`  
**Target SDK:** Dart `^3.13.5` / Flutter Desktop (Windows, Linux, macOS)  
**Review Date:** 2026-11-19  
**Baseline Status:** `flutter analyze` passes (0 issues); `flutter test` passes (87/87 tests).

---

## Executive Summary

**T-Shark Interface** is a well-structured, well-tested desktop GUI for headless local and remote SSH `tshark` packet captures. The codebase demonstrates strong attention to security (path sanitization, directory containment checks, extension whitelisting, pipe buffer draining, atomic JSON writes) and solid test coverage across models, services, view models, and widgets.

However, a deep technical audit identified **23 actionable items** across four categories:
1. **Problems & Bugs (11 items)** — Critical SQLite cross-process synchronization defect, CI native library failure risk, plaintext SSH password persistence, ring-buffer size misreporting, shell quoting edge cases, and UI state synchronization bugs.
2. **Unused & Dead Code (7 items)** — Unused dependencies (`material_ui`, `cupertino_icons`), orphaned persistence methods (`saveLastSelectedTargetId`, custom preset CRUD), unused model/theme getters, and a custom `typedef FutureOr<T> = dynamic` shadow.
3. **Architecture & Code Quality Improvements (5 items)** — Deduplicating formatting logic, decomposing the 1,800-line `CaptureHomeScreen` and 1,427-line `TSharkCaptureViewModel`, and improving remote capture history actions.

Each finding below is self-contained with exact file paths, line numbers, root cause analysis, and concrete implementation instructions so autonomous agents can execute fixes independently or in parallel.

---

## Part 1: Problems & Bugs

### [P-01] Critical: `SharedDeviceDatabase` Cross-Process Polling Always Returns `PRAGMA data_version = 1`
- **Severity:** High (Broken Feature)
- **File:** `lib/services/shared_device_database.dart` (lines 82–107)
- **Problem:**  
  `_ensurePolling()` runs a 1-second timer calling `_readDataVersion(path)`. Inside `_readDataVersion`, the code opens a brand-new SQLite connection (`db = sqlite3.open(path, mode: OpenMode.readOnly)`), executes `PRAGMA data_version;`, and immediately closes `db` in the `finally` block.  
  Per SQLite documentation, `PRAGMA data_version` is a **connection-local counter** that starts at `1` for every new connection and only increments on *that same connection* when another process modifies the database between transactions. Opening and closing a fresh `Database` handle every second guarantees `PRAGMA data_version` **always returns `1`**, meaning cross-process theme changes from other Network Suite applications are never detected. (In-process unit tests pass only because `setThemeMode()` manually calls `notifyChanged()` on line 183).
- **Agent Implementation Fix:**
  1. Either keep a single persistent read-only `Database? _watchDb` connection open while polling is active (closing it in `_stopPolling()` / `dispose()`), **or** check `PRAGMA user_version` / query the `updated_at` / `value` column from `suite_settings WHERE key = 'theme_mode'` (or check `File(path).lastModifiedSync()`) to detect changes across processes.
  2. Add a unit test in `test/widget_test.dart` where a separate `sqlite3.open(dbPath)` connection updates `suite_settings` externally without calling `db.setThemeMode()`, and verify `onDatabaseChanged` emits within the polling interval.

---

### [P-02] High: Plaintext SSH Passwords Persisted to Disk (`remote_hosts.json`) & No SSH Key Support
- **Severity:** High (Security)
- **Files:**
  - `lib/models/remote_host.dart` (lines 25, 40, 86, 107)
  - `lib/services/capture_storage_service.dart` (lines 357–406)
  - `lib/services/remote_ssh_service.dart` (lines 146–162)
- **Problem:**  
  `RemoteHost.toJson()` serializes `password` in cleartext to `remote_hosts.json` in the application support directory (`~/.local/share/...` or `%APPDATA%`), without restrictive file permissions (`chmod 0600`) or OS keyring encryption. Additionally, `RemoteSshService._connect` only supports password authentication (`onPasswordRequest: () => host.password`) and does not support SSH private key (`identities`) authentication.
- **Agent Implementation Fix:**
  1. Store SSH passwords using OS credential storage (e.g. `flutter_secure_storage`) or, if keeping JSON storage for portability, strip passwords from disk unless explicitly opted in and enforce `0600` file permissions on POSIX systems when writing `remote_hosts.json`.
  2. Add an optional `privateKeyPath` field to `RemoteHost` and load `SSHKeyPair.fromPem(...)` in `RemoteSshService._connect()` so users can authenticate via SSH keys instead of storing plaintext passwords.

---

### [P-03] High: Dependencies `material_ui: any`, `sqlite3_flutter_libs: ^0.6.0+eol`, and Missing `libsqlite3-dev` in CI
- **Severity:** High (Build Reliability & Dependency Hygiene)
- **Files:**
  - `pubspec.yaml` (lines 22–25)
  - `.github/workflows/ci.yml` (lines 20–23)
  - `lib/**/*.dart` (13 files importing `package:material_ui/material_ui.dart`)
- **Problem:**
  1. **Shady / Redundant `material_ui: any` dependency:** Every UI file imports `package:material_ui/material_ui.dart` instead of Flutter's official `package:flutter/material.dart`. On pub.dev, `material_ui` is an unmaintained third-party wrapper package specified with an unconstrained `any` version constraint.
  2. **Deprecated `sqlite3_flutter_libs: ^0.6.0+eol`:** The `+eol` version suffix indicates the package has reached End-of-Life (modern `sqlite3` v3.x uses Dart Native Assets / build hooks directly).
  3. **Missing `libsqlite3-dev` in `.github/workflows/ci.yml`:** `.github/workflows/release.yml` installs `libsqlite3-dev` on Ubuntu (line 45), but `.github/workflows/ci.yml` (line 23) omits `libsqlite3-dev`. When `SharedDeviceDatabase` opens an on-disk SQLite database via FFI during `test/widget_test.dart`, missing `libsqlite3.so` on a clean runner can cause FFI load failures.
- **Agent Implementation Fix:**
  1. Replace all 13 occurrences of `import 'package:material_ui/material_ui.dart';` across `lib/` and `test/` with `import 'package:flutter/material.dart';`.
  2. Remove `material_ui: any` and `cupertino_icons: ^1.0.8` (also unused) from `pubspec.yaml`.
  3. Evaluate removing `sqlite3_flutter_libs: ^0.6.0+eol` if `sqlite3` native assets cover desktop builds, or migrate as recommended by `sqlite3` 3.x docs.
  4. Add `libsqlite3-dev` to the `apt-get install` step in `.github/workflows/ci.yml`.

---

### [P-04] Medium: Local Ring-Buffer Capture Size Only Reports Latest Single File Size Instead of Total Ring Buffer Size
- **Severity:** Medium (Functional Bug)
- **File:** `lib/view_models/tshark_capture_view_model.dart` (lines 784–791, 1222–1232, 1333–1345)
- **Problem:**  
  During an active local `CaptureMode.ringBuffer` session (and upon stopping/recovering one), `TSharkCaptureViewModel` calls `_tsharkService.findLatestPcapFile(outputDirectory)` and then passes **only that single latest file path** to `_tsharkService.getCaptureSizeBytes(latest)`.  
  Ironically, `TSharkService.getCaptureSizeBytes(String filePathOrDir)` (lines 551–562 of `lib/services/tshark_service.dart`) already has dedicated logic to sum all `.pcap`, `.pcapng`, and `.cap` files when passed a **directory**! Because the ViewModel passes `latest` (a single file) instead of `outputDirectory`, the live size counter in `ActiveCaptureBanner` drops back to `0 KB` every time TShark rotates to a new ring buffer file, and `CaptureHistoryItem.fileSizeBytes` only records the size of the final rotated chunk rather than the capture session. (Note: Remote Linux/Windows sessions in `RemoteSshService` measure `session.outputDirectory` for ring buffers).
- **Agent Implementation Fix:**
  1. In `TSharkCaptureViewModel` (lines 791, 1232, and 1333–1345), when `mode == CaptureMode.ringBuffer`, pass `session.outputDirectory` to `_tsharkService.getCaptureSizeBytes(...)` so the total size of all retained ring-buffer files is reported, while still using `findLatestPcapFile` for `recordedFilePath` in `CaptureHistoryItem.filePath` so "Open in Wireshark" opens the latest capture file.

---

### [P-05] Medium: Local `stopCapture` Sends `SIGTERM` (`-15`) Instead of `SIGINT` (`-2`), and Double-Kills Process
- **Severity:** Medium (Reliability / PCAP Integrity)
- **Files:**
  - `lib/services/tshark_service.dart` (lines 522–533)
  - `lib/view_models/tshark_capture_view_model.dart` (lines 1110–1120, 1214–1219)
- **Problem:**
  1. In `RemoteSshService.stopRemoteCapture` (line 473), the code rightly notes: *"Send SIGINT (-2) first so dumpcap flushes its packet buffer and closes PCAPNG cleanly"*. However, in local `TSharkService.stopCapture` (line 523), it immediately sends `kill -15` (`SIGTERM`) instead of `SIGINT` (`-2`), and if `tshark` spawned a child `dumpcap` process, killing only `pid` without signaling the process group or child may leave `dumpcap` unflushed.
  2. When the user clicks "Stop Capture", `_isStopping` is set to `true`, `_tsharkService.stopCapture(session.pid)` kills the process, and before `stopCapture` finishes, `process.exitCode.then((code) => onProcessExit(code))` (registered at `startCapture` line 1110) fires with a non-zero signal exit code (e.g., `143` for SIGTERM / `130` for SIGINT / `-1` on Windows `taskkill`). Because `onProcessExit` only checks `if (exitCode != 0)` without checking `if (!_isStopping)`, stopping a capture manually can flash a spurious error banner: `"TShark capture process exited unexpectedly (exit code 143)"`.
  3. Line 1217 calls `_activeProcess!.kill()` *after* `await _tsharkService.stopCapture(session.pid)` has already terminated the PID.
- **Agent Implementation Fix:**
  1. In `TSharkCaptureViewModel.startCapture` (line 1111), guard `onProcessExit` with `if (!_isStopping && exitCode != 0)`.
  2. In `TSharkService.stopCapture` on Unix, send `SIGINT` (`-2`) first, wait briefly, then fall back to `SIGTERM` (`-15`) and `SIGKILL` (`-9`).

---

### [P-06] Medium: `CommandPreviewCard` PowerShell Toggle Desynchronized from `TSharkService.buildDisplayCommandLine`
- **Severity:** Medium (UI / CLI Output Bug)
- **Files:**
  - `lib/services/tshark_service.dart` (lines 355–373)
  - `lib/ui/views/widgets/command_preview_card.dart` (lines 23–31)
- **Problem:**
  1. On Windows, `TSharkService.buildDisplayCommandLine` defaults to `forPowerShell = true` and prepends `'& '` when `tsharkPath.contains(' ')` (e.g., `& "C:\Program Files\Wireshark\tshark.exe" ...`).
  2. `CommandPreviewCard` receives that string as `widget.commandLine` and has a toggle between `PowerShell` (`_usePowerShell = true`) and `CMD / Bash` (`_usePowerShell = false`).
  3. Look at `_CommandPreviewCardState._displayCommand` (lines 25–31):
     ```dart
     String get _displayCommand {
       final raw = widget.commandLine.trim();
       if (_usePowerShell && raw.startsWith('"')) {
         return '& $raw';
       }
       return raw;
     }
     ```
     - **On Windows:** `raw` *already* starts with `'& "'` (from `buildDisplayCommandLine`). When the user switches the toggle to **CMD / Bash** (`_usePowerShell = false`), `_displayCommand` returns `raw` unchanged — which still has `& ` at the beginning! `& "C:\Program Files\..."` is invalid syntax in `cmd.exe` and Bash.
     - **For Remote SSH targets:** `widget.commandLine` is `ssh user@host "..."`. The `PowerShell` vs `CMD / Bash` toggle in `CommandPreviewCard` is still rendered even though it is a no-op for `ssh` commands, and the `Detached (Headless)` switch in `CommandPreviewCard` (line 91) remains interactive when `isRemoteTarget == true` even though remote captures are always detached (`runDetached: vm.isRemoteTarget ? true : vm.runDetached`).
- **Agent Implementation Fix:**
  1. Have `TSharkService.buildDisplayCommandLine` default to `forPowerShell: false` (or strip leading `& ` in `CommandPreviewCard` when `!_usePowerShell` and add `& ` when `_usePowerShell && raw.startsWith('"')`).
  2. Disable the `Detached (Headless)` switch in `CommandPreviewCard` when `vm.isRemoteTarget` (pass `onDetachedChanged: vm.isRemoteTarget || vm.isCapturing ? null : (val) => vm.setRunDetached(val)`).

---

### [P-07] Medium: `buildDisplayCommandLine` & `buildRemoteDisplayCommandLine` Shell Quoting Flaws
- **Severity:** Medium (CLI Preview Bug)
- **Files:**
  - `lib/services/tshark_service.dart` (lines 362–367)
  - `lib/services/remote_ssh_service.dart` (lines 123–144, 242, 259, 304)
- **Problem:**
  1. In `TSharkService.buildDisplayCommandLine` (line 363), arguments are only quoted if they contain `' '`, `'\\'`, or `'"'`. BPF capture filters and Linux interface names frequently contain parentheses, pipes, ampersands, or semicolons without spaces — e.g., `tcp[tcpflags]&(tcp-syn|tcp-fin)!=0` — which will be interpreted by Bash/PowerShell/CMD as shell operators if unquoted.
  2. In `RemoteSshService.buildRemoteDisplayCommandLine` (line 135–143), the outer SSH command is wrapped in double quotes (`ssh user@host "$sudoPrefix$tsharkBin $formattedArgs"`), while `tsharkBin` (such as `C:\Program Files\Wireshark\tshark.exe`) is **not quoted at all** inside the remote command string, and `formattedArgs` are only single-quoted if they contain spaces, `(`, `)`, or `\`. If a BPF filter contains `"` or `$`, it breaks the outer double-quoted SSH command.
  3. In `RemoteSshService.testConnection` and `getRemoteInterfaces` (lines 242, 259, 304), Windows execution runs `'"$tsharkBin" -v'` and `'"$tsharkBin" -D'`. If the default OpenSSH shell on Windows is PowerShell (common on Windows Server), starting a command with a double-quoted path `"C:\Program Files\Wireshark\tshark.exe" -D` without the `&` call operator fails with a parser error in PowerShell!
- **Agent Implementation Fix:**
  1. Always quote the `-f <filter>` argument and `-w <path>` argument in `buildDisplayCommandLine` and `buildRemoteDisplayCommandLine`.
  2. In `RemoteSshService.testConnection` and `getRemoteInterfaces`, when `os == RemoteOsType.windows`, invoke `tshark` via `powershell -NoProfile -NonInteractive -Command "& ${escapePowerShellArg(tsharkBin)} -v"` (and `-D`) just like `buildWindowsStartCommand` does, so it works regardless of whether the Windows OpenSSH default shell is `cmd.exe` or `powershell.exe`.

---

### [P-08] Medium: Text Controllers in `CaptureHomeScreen` Desynchronize on Recovery / Preset / Config Changes
- **Severity:** Medium (UI State Bug)
- **File:** `lib/ui/views/capture_home_screen.dart` (lines 31–50, 201–210, 659–664, 1122–1130)
- **Problem:**  
  `_CaptureHomeScreenState` initializes `_filePrefixController`, `_packetLimitController`, and `_remoteOutputDirController` once in `initState()` (lines 47–49). However:
  1. When `vm.init()` finishes asynchronously after `initState()`, `vm.outputDirectory` is populated from `CaptureStorageService.loadDefaultOutputDirectory()`, and `vm.checkExistingSession()` may auto-apply an interrupted session's `CaptureConfig` (`applyConfig`). None of the three `TextEditingController`s in `CaptureHomeScreen` are updated when `vm` notifies listeners!
  2. When the user clicks **"Load Settings (Review First)"** or **"Resume Capture Now"** on `InterruptedCaptureBanner` (lines 661–662), `vm.loadInterruptedSettings()` updates `vm.filePrefix`, `vm.packetCountLimit`, and `vm.outputDirectory`, but `_filePrefixController`, `_packetLimitController`, and `_remoteOutputDirController` keep displaying their old values.
  3. When the user clicks **"Clear"** (`_clearCaptureSettings`, line 201), `vm.clearCapture()` does not reset `_filePrefix` (or if it should, `_filePrefixController` is not synced).
  4. When the user changes **Default Output Directory** in `SettingsDialog` (line 59 of `settings_dialog.dart`), `_remoteOutputDirController.text` is not updated.
  5. `_filePrefixController` TextField (line 1122) and `_packetLimitController` TextField (line 1496) and `CaptureFilterInput` TextField (`lib/ui/views/widgets/capture_filter_input.dart` line 178) do **not** set `enabled: !vm.isCapturing`, allowing the user to type into them while a capture is actively running!
- **Agent Implementation Fix:**
  1. Sync `_filePrefixController`, `_packetLimitController`, and `_remoteOutputDirController` with `vm.filePrefix`, `vm.packetCountLimit.toString()`, and `vm.outputDirectory` inside `build()` whenever the controller's text differs and its field does not currently have focus (follow the pattern used in `CaptureFilterInput.didUpdateWidget`).
  2. Pass `enabled: !vm.isCapturing` to `_filePrefixController` TextField, `_packetLimitController` TextField, and `CaptureFilterInput`.

---

### [P-09] Medium: Remote Capture History Items Offer Broken Local Explorer / Wireshark Actions & Flatten Ring Buffers
- **Severity:** Medium (UX / Logic Bug)
- **Files:**
  - `lib/view_models/tshark_capture_view_model.dart` (lines 696–707, 1283–1292, 1389–1396)
  - `lib/ui/views/widgets/capture_history_card.dart` (lines 91–110)
  - `lib/services/remote_ssh_service.dart` (lines 425–432)
- **Problem:**
  1. When a remote capture finishes (`refreshRemoteSessionStatus` line 697 or `stopRemoteCapture` line 1283), a `CaptureHistoryItem` is added to the shared `_history` list with `filePath: session.targetFilePath` (which is a path *on the remote host*, e.g. `/tmp/tshark_captures/Capture_.../capture_....pcapng`).
  2. In `CaptureHistoryCard`, every history item renders **"Open in Explorer"** (`Icons.folder_open`) and **"Open in Wireshark"** (`Icons.launch`). Clicking "Open in Explorer" on a remote history item calls `SystemService.openFolder(p.dirname(item.filePath))`, which **creates a local folder with the remote path name on the user's PC** (`dir.createSync(recursive: true)` in `SystemService.openFolder` line 21!) and opens an empty local folder! Clicking "Open in Wireshark" silently fails because the file does not exist locally.
  3. On Windows remote hosts (`RemoteSshService.checkRemoteSessionStatus`, lines 425–432), the PowerShell size check always sums *all* files in `session.outputDirectory`:
     ```powershell
     (Get-ChildItem $psDir -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
     ```
     If `config.createSubfolder` is `false` (user unchecked "Timestamp Subfolder" in Manual mode), `session.outputDirectory` is the root `/tmp/tshark_captures` or `C:\Temp\TSharkCaptures` folder, so it sums the size of **all historical captures ever taken in that directory** rather than `session.targetFilePath`! (Linux checks `if [ -f $escapedPath ]` first at line 409, avoiding this when not in ringBuffer mode, though in ringBuffer mode `pathToMeasure` is `session.outputDirectory`).
- **Agent Implementation Fix:**
  1. Add `final bool isRemote;` (and optional `final String? remoteHostId;`) to `CaptureHistoryItem` (persisted in `toJson`/`fromJson`, defaulting to `false`).
  2. In `CaptureHistoryCard`, if `item.isRemote` is `true`, hide or replace "Open in Explorer" / "Open in Wireshark" with a "Copy Remote Path" button (or an SFTP download action).
  3. In `SystemService.openFolder`, do **not** auto-create arbitrary directories if they don't exist (`dir.createSync`), or only create the default local capture directory when explicitly requested.
  4. In `RemoteSshService.checkRemoteSessionStatus` (Windows branch, line 425), check `session.targetFilePath` when `session.mode != CaptureMode.ringBuffer` (matching the Linux branch).

---

### [P-10] Low: `DropdownButtonFormField` `initialValue` Does Not React to State Changes
- **Severity:** Low (UI Bug)
- **File:** `lib/ui/views/capture_home_screen.dart` (line 1169)
- **Problem:**  
  In `CaptureHomeScreen`, the **Reboot & Crash Recovery Policy** dropdown uses `DropdownButtonFormField<RecoveryPolicy>(initialValue: vm.recoveryPolicy, ...)`. In Flutter's `FormField`, `initialValue` is only read once when the `FormFieldState` is first created. If `vm.recoveryPolicy` changes later (e.g., when `vm.init()` finishes loading the saved default recovery policy from disk, when the user changes the default policy in `SettingsDialog`, or when `applyConfig` loads an interrupted session), the `DropdownButtonFormField` continues showing the old value!
- **Agent Implementation Fix:**
  - Add a `key: ValueKey(vm.recoveryPolicy)` to `DropdownButtonFormField<RecoveryPolicy>` on line 1168 (or use `DropdownButton<RecoveryPolicy>(value: vm.recoveryPolicy, ...)` wrapped in an `InputDecorator`).

---

### [P-11] Low: Hardcoded Windows Fonts (`Segoe UI`, `Consolas`) Without Cross-Platform Fallbacks
- **Severity:** Low (Cross-Platform Visuals)
- **Files:**
  - `lib/ui/theme/app_theme.dart` (line 125: `fontFamily: 'Segoe UI'`)
  - `lib/ui/views/capture_home_screen.dart`, `lib/ui/views/widgets/active_capture_banner.dart`, `lib/ui/views/widgets/command_preview_card.dart`, `lib/ui/views/widgets/capture_filter_input.dart`, `lib/ui/widgets/guided_tour_overlay.dart`, `lib/ui/views/dialogs/settings_dialog.dart` (`fontFamily: 'Consolas'`)
- **Problem:**  
  The app targets Windows, Linux, and macOS (per `.github/workflows/release.yml`). Neither `Segoe UI` nor `Consolas` is bundled in `pubspec.yaml` or installed by default on Linux or macOS, causing Flutter to fall back to generic default fonts (often non-monospace for `Consolas` on some Linux distributions if not mapped via `fontFamilyFallback`).
- **Agent Implementation Fix:**
  - Define reusable `AppTheme.monoFontFamily` / `fontFamilyFallback: const ['Consolas', 'Menlo', 'Monaco', 'Liberation Mono', 'monospace']` in `AppTheme`, and omit hardcoded `'Segoe UI'` on non-Windows platforms (or provide `fontFamilyFallback`).

---

## Part 2: Unused & Dead Code

Agents can safely remove or wire up the following dead code and orphaned methods:

| ID | File & Lines | Symbol / Code | Findings & Recommended Action |
| :--- | :--- | :--- | :--- |
| **U-01** | `lib/core/theme/app_theme.dart` (line 1) | Entire file (`export 'package:tshark_interface/ui/theme/app_theme.dart';`) | **Zero references** anywhere in `lib/` or `test/`. Delete `lib/core/theme/app_theme.dart` and the empty `lib/core/` directory. |
| **U-02** | `lib/services/capture_storage_service.dart` (lines 327–354) | `saveCustomPreset(CapturePreset)` & `deleteCustomPreset(String)` | `loadCustomPresets()` is called in `TSharkCaptureViewModel.init()`, but `saveCustomPreset` and `deleteCustomPreset` are **never called anywhere** in `lib/` or `test/`, and there is no UI to save or delete custom presets. Either add a "Save Current Filter/Mode as Preset" button in `CapturePresetsBar` to complete the feature, or remove the dead methods. |
| **U-03** | `lib/services/capture_storage_service.dart` (lines 458–469) & `lib/view_models/tshark_capture_view_model.dart` (line 533) | `loadLastSelectedTargetId()` & `saveLastSelectedTargetId(String?)` | `selectTargetHost()` saves `lastSelectedTargetId` to `preferences.json` on line 533, but `loadLastSelectedTargetId()` is **never called anywhere** (not even in `init()`). Either call `loadLastSelectedTargetId()` in `init()` to restore the last selected remote host (or deliberately keep local default and remove both methods). |
| **U-04** | `lib/view_models/tshark_capture_view_model.dart` (lines 149–151) | `int get totalActiveCapturesCount` | Defined on the ViewModel, **never read** in `lib/` or `test/`. Remove or display in the top bar / window title. |
| **U-05** | `lib/ui/theme/app_theme.dart` (lines 48–49, 52–53, 62) | `AppTheme.info`, `AppTheme.darkBackground`, `AppTheme.cardColor`, `AppTheme.currentTheme` | Four static getters in `AppTheme` that have **zero references** in `lib/` or `test/`. Remove them to keep `AppTheme` clean. |
| **U-06** | `lib/ui/widgets/guided_tour_overlay.dart` (line 20) | `typedef FutureOr<T> = dynamic;` | Defines a custom `FutureOr<T>` typedef aliasing `dynamic` instead of importing `dart:async` (which provides the real `FutureOr<T>`). Replace line 20 with `import 'dart:async';`. |
| **U-07** | `lib/models/capture_interface.dart` (lines 39–44), `lib/models/launch_adapter_config.dart` (line 17), `lib/models/capture_config.dart` (line 63) | `CaptureInterface.subtitle`, `LaunchAdapterConfig.hasOverride`, `RecoveryPolicy.isNone` | Only referenced in unit tests (`test/models_test.dart`, `test/launch_adapter_config_test.dart`), never used in production `lib/` code. (`CaptureInterface.subtitle` can be usefully shown in the interface dropdown tooltip or subtitle; `hasOverride` is a duplicate alias of `hasAdapterOverride`). |

---

## Part 3: Architecture & Code Quality Improvements

### [I-01] Deduplicate Byte & Duration Formatting Utilities
- **Files:**
  - `lib/view_models/tshark_capture_view_model.dart` (`formatDuration`, `formatBytes` — lines 1404–1420)
  - `lib/ui/views/widgets/active_capture_banner.dart` (`_formatDuration`, `_formatBytes` — lines 48–64)
  - `lib/models/capture_history_item.dart` (`formattedSize` — lines 18–27)
- **Improvement:**  
   identical byte-size formatting (`B`, `KB`, `MB`, `GB`) is copy-pasted in **3 different files**, and `HH:MM:SS` duration formatting is duplicated in **2 files**. Extract a tiny static utility class `lib/utils/format_utils.dart` (`FormatUtils.formatBytes(int)` and `FormatUtils.formatDuration(Duration)`) and delegate all three sites to it.

---

### [I-02] Decompose `CaptureHomeScreen` (1,800 Lines) into Focused Sub-Widgets
- **File:** `lib/ui/views/capture_home_screen.dart` (1,800 lines)
- **Improvement:**  
  `CaptureHomeScreen` currently contains the top control bar, unreachable remote session banners, mode parameter cards, packet slicing & storage card, live packet stream table, and packet dissection viewer all in a single 1,800-line widget class.  
  Extract into dedicated widget files under `lib/ui/views/widgets/`:
  1. `top_control_bar.dart` (`_buildTopControlBar`, `_buildStatusDot`)
  2. `capture_mode_selector_card.dart` (`_buildModeParameters` and Traffic Filter & Capture Mode section)
  3. `storage_and_recovery_card.dart` (Packet Slicing, Promiscuous Mode, Output Folder, File Prefix, Recovery Policy)
  4. `live_packet_stream_card.dart` (`_buildLivePacketStreamCard` and `_buildPacketDissectionCard`)

---

### [I-03] Decompose `TSharkCaptureViewModel` (1,427 Lines) & Move Hardcoded Demo Packets
- **File:** `lib/view_models/tshark_capture_view_model.dart` (1,427 lines)
- **Improvement:**
  1. Lines 211–290 of `TSharkCaptureViewModel` embed 80 lines of static demo packet literals (`_demoPackets = const [...]`). Move `DemoPacket.samplePackets` into `lib/models/demo_packet.dart` so the ViewModel stays focused on state management.
  2. Extract CLI adapter matching logic (`matchLaunchAdapter`, `_matchByIp`, `_matchByName`, lines 358–468) into `LaunchAdapterConfig` or a dedicated `AdapterMatcher` helper class in `lib/services/`.

---

### [I-04] Fix Misleading Copy in `CaptureHistoryCard` & Tour Step 5 Description
- **Files:**
  - `lib/ui/views/widgets/capture_history_card.dart` (line 38)
  - `lib/ui/views/capture_home_screen.dart` (lines 194–196)
- **Improvement:**
  1. `CaptureHistoryCard` empty state says `'No captures recorded in this session yet'`, even though history is persisted across sessions in `history.json` (up to 50 items), and `CaptureHistoryCard` truncates display to only 5 items (`history.length > 5 ? 5 : history.length`, line 70) without any "Show All" button or scroll view. Allow scrolling all stored history items (or up to 50 with a `ConstrainedBox(maxHeight: 280)`) and update the empty state text to `'No captures recorded yet'`.
  2. Guided Tour Step 5 (`capture_home_screen.dart` line 196) states: *"and export captures to .pcapng or CSV"*, whereas the Export menu only has **"Open Storage Folder"** and **"Copy Command Line"**. Either add a CSV export of the packet table / history or update the tour text to match actual functionality.

---

### [I-05] Persist Last Selected Remote Host or Remove Dead Storage Call
- **Files:**
  - `lib/view_models/tshark_capture_view_model.dart` (lines 340–346, 533)
  - `lib/services/capture_storage_service.dart` (lines 458–469)
- **Improvement:**  
  When `initialAdapterConfig` is not provided via CLI flags, `TSharkCaptureViewModel.init()` can optionally check `_storageService.loadLastSelectedTargetId()` or, if starting on `Localhost` by default is intentional, remove `saveLastSelectedTargetId` / `loadLastSelectedTargetId` so `preferences.json` isn't written on every target switch for no reason.

---

## Suggested Implementation Order for Agents

1. **Wave 1 — Dependencies, Dead Code & Quick Fixes (Low Risk):**
   - Execute **[P-03]** (replace `package:material_ui/material_ui.dart` with `package:flutter/material.dart`, remove `material_ui` and `cupertino_icons`, add `libsqlite3-dev` to `.github/workflows/ci.yml`).
   - Execute **[U-01]** through **[U-07]** and **[I-01]** (delete `lib/core/theme/app_theme.dart`, fix `typedef FutureOr` in `guided_tour_overlay.dart`, remove unused getters/methods, centralize `FormatUtils`).
2. **Wave 2 — Core Service & Logic Bug Fixes:**
   - Execute **[P-01]** (fix `SharedDeviceDatabase` `PRAGMA data_version` cross-process polling).
   - Execute **[P-04]** & **[P-05]** (fix ring-buffer total directory size calculation, guard `onProcessExit` with `!_isStopping`, use `SIGINT` before `SIGTERM` in local `stopCapture`).
   - Execute **[P-06]** & **[P-07]** (fix `CommandPreviewCard` PowerShell vs CMD/Bash toggle and remote PowerShell invocation/quoting).
3. **Wave 3 — UI State Sync, Remote History UX & Refactoring:**
   - Execute **[P-08]**, **[P-09]**, **[P-10]**, **[P-11]** (controller synchronization, disable inputs while capturing, remote history item handling, `DropdownButtonFormField` key, font fallbacks).
   - Execute **[I-02]**, **[I-03]**, **[I-04]** (modularize `CaptureHomeScreen` and `TSharkCaptureViewModel`, make history list scrollable beyond 5 items).
   - Execute **[P-02]** (harden SSH credential storage and/or add SSH key authentication).
