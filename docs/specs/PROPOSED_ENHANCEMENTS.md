# TShark Interface — Proposed Enhancements & Suite Integrations

---

## Issue 1: Direct Capture Handoff to Packet Inspector & Socket Scout

### Summary
Add one-click handoff actions in the **Recent Capture Vault** to open saved `.pcap` / `.pcapng` files directly in **Packet Inspector** or **Socket Scout**, matching the existing "Open in Wireshark" workflow.

### Motivation
`TShark-Interface` excels at headless local and detached remote SSH captures, while `Packet-Inspector` and `Socket-Scout` both support offline `.pcap`/`.pcapng` ingestion. Adding direct launch actions closes the loop between capturing traffic and analyzing timing anomalies or Layer 2 switch discovery frames without manually browsing `%LOCALAPPDATA%\TSharkCaptures`.

### Proposed Implementation
- Add **"Open in Packet Inspector"** and **"Inspect L2 in Socket Scout"** buttons/context menu items to entries in the Recent Capture Vault.
- Resolve installed executable paths via `%LOCALAPPDATA%\NetworkSuite\installed_apps.json` (or configurable path fallback).
- Pass the sanitized capture file path via CLI argument (e.g., `--open-pcap <path>`) or local IPC socket if an instance is already running.
- Maintain the existing extension whitelist verification (`.pcap`, `.pcapng`, `.cap`) prior to process launch.

### Acceptance Criteria
- [ ] Recent Capture Vault displays actions to open captures in Packet Inspector and Socket Scout when installed.
- [ ] Clicking the action launches the target application and immediately loads the selected capture file.
- [ ] Graceful error toast/banner displayed if the target application binary cannot be found.
