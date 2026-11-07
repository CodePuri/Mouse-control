# Product Requirements Document (PRD): Mac Peripheral Control

**Goal:** Native macOS application allowing custom side-button configuration for Kreo Chimera V2 (and future peripherals), with verified Wispr Flow Push-to-Talk and keyboard shortcut remapping.

## Milestones Overview

- [x] **M0: Establish the Facts (Corrected)**
  - OS version (macOS 27.3 arm64), Swift 6.4.2, Xcode 26.6 available.
  - Connected USB receiver discovery (`0x248a:0x5b4a`, `K Chimera`).
  - Vendor interface `0xFF01` treated as unverified purpose until protocol evidence is proven.
  - Wispr Flow inspection (`config.json`: keycode 61 Right Option candidate for PTT emulation).
  - Explicit bounded 30s calibration capture (`Tools/calibrate_buttons`) with IOKit device matching and honest global event stream labeling. No incidental typed text recorded.
  - Permissions model: CLI probe accessibility verified, but full .app bundle requires independent Info.plist declarations and runtime permission state verification.
- [-] **M1: Usable Kreo Mac Application (Implementation available; physical acceptance pending)**
  - Native SwiftUI Mac App (`MouseControl.app`) matching G HUB / Options+ reference design.
  - Interactive device stage with Kreo Chimera V2 high-res assets (Top and Left Side views).
  - Selectable hotspots for Front Side Button and Rear Side Button with live press indicators.
  - Configurable actions: Wispr Flow Push-to-Talk (Hold to speak, release to transcribe), Undo (⌘Z), Redo (⇧⌘Z), Custom Shortcuts.
  - Active CGEventTap background service with event suppression (no duplicate browser back/forward).
  - Application scope & Device scope selection.
  - Persistence under `~/Library/Application Support/MouseControl/profiles.json`.
  - Live Pause / Resume remapping toggle.
- [ ] **M2: G HUB Style Experience & Automatic Product Image Discovery (Future)**
- [ ] **M3: Expanded Device Matrix & Verified Hardware Protocols (Future)**
- [ ] **M4: DMG Distribution & Product Site (Future)**
- [ ] **M5: Windows Support (Future)**
