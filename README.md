# T-Shark Interface

A dedicated, lightweight Desktop GUI for headless **T-Shark (Wireshark)** packet capturing.

Designed to give network engineers, developers, and sysadmins full control over background captures without needing to memorize complicated command-line syntax.

---

## Key Features

- **Automatic Engine Detection & Path Validation**: Automatically discovers Wireshark's `tshark.exe` (or custom user-defined path) and validates binary integrity before querying version and available network interfaces.
- **Remote SSH Capture & Host Management**:
  - Save and manage remote SSH hosts (Linux/Unix and Windows OpenSSH) with connection testing, OS auto-detection, and live `tshark` status indicators.
  - Switch between **Local Machine** and any saved **Remote Host** directly in the *Capture Target & Interface* card, dynamically querying remote network adapters via `tshark -D` over SSH.
  - Launch detached remote captures (`nohup` on Linux, hidden background process on Windows) that continue running even if the local app closes or SSH disconnects.
  - Automatic session reconnection on startup (`remote_sessions.json`) with one-click **Clear / Forget Session** controls for hosts that were powered off or decommissioned.
- **Visual Interface Picker**: Choose physical or virtual network adapters (`Wi-Fi`, `Ethernet`, `NPF_Loopback`, `Tailscale`, `eth0`, `ens18`) with hardware names and indexes. Captures bind to persistent adapter device paths (e.g. `\Device\NPF_{GUID}`) so adapter index shifts across reboots or VPN connects never misroute captures.
- **One-Click Presets**:
  - *All Traffic*: Full capture with no filters.
  - *Exclude SSH & RDP*: Automatically drops port 22 and 3389 to prevent feedback loops when capturing on remote hosts.
  - *Web Traffic*: HTTP (80/8080) and HTTPS (443/8443).
  - *DNS Resolution*: Port 53 queries and answers.
  - *DHCP & BootP*: Ports 67 & 68 lease and IP allocation.
  - *ICMP / Ping*: Ping requests, replies, and network diagnostics.
  - *Headers Only (96B)*: Truncates payload using Snaplen (`-s 96`) to reduce capture size by up to 90% on high-bandwidth links.
  - *24/7 Rolling Ring Buffer*: Continuous rolling PCAP rotation with max file limits.
- **Berkeley Packet Filter (BPF) Syntax Assistant**: Interactive BPF filter builder with cheatsheet examples.
- **Multiple Capture Modes**:
  - *Manual Stop*: Runs continuously until stopped.
  - *Timed Duration*: Auto-stops after specified hours/minutes.
  - *Rolling Ring Buffer*: Rotates files by time (minutes) or by size (MB), preserving the latest *N* files.
  - *Packet Count*: Auto-stops after capturing *N* packets.
- **Reboot & Crash Recovery**:
  - Automatically detects interrupted sessions if the host was restarted or powered off.
  - Configurable policy: **Prompt to Resume**, **Auto-Restore (Unattended / Headless)**, or **No Recovery**.
- **Live Command-Line Studio**:
  - Shows the exact `tshark` command in real-time as options are configured.
  - Toggle between **PowerShell** (with `& ` call operator) and **CMD / Bash** syntax.
  - Detached (headless background) execution switch.
- **Active Capture Session Manager**:
  - Glowing live status bar with PID indicator.
  - Real-time elapsed stopwatch.
  - Dynamic capture file size monitor (including rolling ring-buffer folders).
  - Graceful termination: signals process tree to flush packet buffers before clean termination.
  - Real-time stderr and error diagnostics.
- **Recent Capture Vault**:
  - History of previous capture files with size and timestamp.
  - One-click "Open in Explorer" and "Open in Wireshark" (with extension whitelist verification).

---

## Security & Reliability Design

- **Privilege Principle**: Running as standard user is recommended. Modern Npcap installations allow non-elevated users in the `npcap` group or standard users to capture packets without requiring Administrator elevation.
- **Cloud-Leak Prevention**: By default, captures are saved to local app data (`%LOCALAPPDATA%\TSharkCaptures`) rather than the user's Documents folder to prevent sensitive network traffic from automatically syncing to cloud drives (OneDrive, Dropbox, etc.).
- **Path Sanitization**: Capture file prefixes are strictly sanitized to prevent directory traversal and NTFS alternate data stream manipulation.
- **Pipe Stall Prevention**: All capture sessions run in quiet mode (`-q`) with asynchronous stdout/stderr stream draining, preventing process deadlock on high-throughput packet streams.

---

## Getting Started

### Prerequisites

- [Wireshark](https://www.wireshark.org/) (includes `tshark` and `Npcap`).
- [Flutter SDK](https://flutter.dev/) (3.13+ / 3.47+).

### Running in Development

```bash
flutter pub get
flutter run -d windows
```

### Running Tests

```bash
flutter test
```

### Building for Release

```powershell
flutter build windows --release
```

The compiled standalone application is generated under `build\windows\x64\runner\Release\`. A portable distribution archive is available in `dist\TShark-Interface-Windows-x64.zip`.
