# T-Shark Interface

A dedicated, lightweight Desktop GUI for headless **T-Shark (Wireshark)** packet capturing.

Designed to give network engineers, developers, and sysadmins full control over background captures without needing to memorize complicated command-line syntax.

---

## Features

- **Automatic Engine Detection**: Automatically discovers Wireshark's `tshark.exe` (or custom user-defined path) and queries version and available network interfaces.
- **Visual Interface Picker**: Choose physical or virtual network adapters (`Wi-Fi`, `Ethernet`, `NPF_Loopback`, `Tailscale`) with hardware names and indexes.
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
- **Live Command-Line Studio**:
  - Shows the exact `tshark` command in real-time as options are configured.
  - One-click copy button to paste into remote SSH terminal or scripts.
  - Detached (headless background) execution switch.
- **Active Capture Session Manager**:
  - Glowing live status bar with PID indicator.
  - Real-time elapsed stopwatch.
  - Dynamic capture file size monitor.
  - Safe clean-tree termination (`taskkill /T /F` on Windows to kill both `tshark` and `dumpcap`).
  - Session recovery: If the app is closed while a background capture is active, reopening the app reconnects to the running PID.
- **Recent Capture Vault**:
  - History of previous capture files with size and timestamp.
  - One-click "Open in Explorer" and "Open in Wireshark".

---

## Getting Started

### Prerequisites

- [Wireshark](https://www.wireshark.org/) installed (comes with `tshark`).
- [Flutter SDK](https://flutter.dev/) (3.13+ / 3.47+).

### Running the App

```bash
flutter pub get
flutter run -d windows
```

### Running Tests

```bash
flutter test
```
