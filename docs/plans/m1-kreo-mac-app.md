# Implementation Plan: M1 Usable Kreo Mac Application

**Goal:** Native macOS application allowing custom side-button configuration for Kreo Chimera V2 through its wireless USB receiver, featuring an interactive G HUB / Options+ style device workspace, verified Wispr Flow Push-to-Talk integration, and custom shortcut remapping with complete event suppression.

## Global Constraints
- Target: macOS 14.0+ (running on macOS 27.3 arm64). Swift 6.4 with SwiftUI and AppKit.
- Strict Apple Design & G HUB theme tokens:
  - Background Canvas: `#0B0D10`
  - Sidebar / Context Panels: `#16191F`
  - Elevated Cards / Hover: `#212631`
  - Borders: `#2D3442`
  - Primary Accent: `#27C7F7`
  - Typography: SF Pro Text / SF Pro Display
  - Stage Layout: 64pt Toolbar, 64pt Feature Rail, 304pt Context Panel, remaining space for Device Stage.
- Input Engine:
  - Active `CGEventTap` at `.cghidEventTap` / `.headInsertEventTap`.
  - Event suppression: consume `otherMouseDown` / `otherMouseUp` for remapped buttons so default browser Back/Forward is suppressed.
  - Wispr Flow PTT: dispatch synthetic KeyDown on press, KeyUp on release (keycode 61 Right Option).
  - Safety: loop avoidance via event tagging (`CGEvent.setIntegerValueField(.eventSourceUserData)`), held modifier preservation, clean shutdown.
  - Honest scope reporting: label global mouse fallback clearly when Quartz does not provide physical device ID attribution.
- Persistence: JSON under `~/Library/Application Support/MouseControl/profiles.json`.
- Testing: standalone unit test executables and automated verification for engine, persistence, geometry, and app packaging.

---

### Task 1: Core Input Engine & Remapping Service
- **Brief:** Implement `InputEngine.swift` providing:
  - Active `CGEventTap` capturing `otherMouseDown` and `otherMouseUp` (buttons 3, 4, 5+).
  - Remapping state: configurable action handlers (KeyShortcut with modifiers, PushToTalk with target keycode, None/Passthrough).
  - Latching action on button down and matching release on button up.
  - Event suppression: returns `nil` when an assigned button event is handled, pass-through when unassigned or paused.
  - Synthetic event generation: creates keyboard down/up with `CGEvent(keyboardEventSource:virtualKey:keyDown:)`, tagged with a magic user-data marker `0x4D435452` ("MCTR") to avoid recursive loops.
  - Thread safety: runs on a dedicated run loop source / serial queue.
  - Pause / Resume methods that restore standard pass-through.
- **Verification:** Unit test `Tests/TestInputEngine.swift` testing:
  1. Synthetic keycode generation and tagging.
  2. Action latching (down -> up).
  3. Suppression logic (returns nil when mapped, passes through when unmapped).
  4. Pause/resume toggling.

---

### Task 2: Profile Engine & Configuration Persistence
- **Brief:** Implement `ProfileModel.swift` and `ProfileStore.swift`:
  - Data models: `ButtonAssignment` (id, buttonNumber, actionType [wisprFlowPTT, shortcut, undo, redo, disabled], keycode, modifiers, tapOrHold), `DeviceProfile` (id, name, appBundleId, assignments, deviceScope [kreoOnly, allMiceFallback]), `AppSettings` (launchAtLogin, isPaused, activeProfileId).
  - Storage: atomic read/write to `~/Library/Application Support/MouseControl/profiles.json` with schema versioning.
  - Default profile: Front Side Button (button 4) -> Wispr Flow PTT (keycode 61, Hold-to-Talk), Rear Side Button (button 3) -> Undo (⌘Z).
  - Export & Import JSON capability.
- **Verification:** Unit test `Tests/TestProfileStore.swift` testing:
  1. Default profile creation.
  2. JSON serialization and deserialization roundtrip.
  3. Updating assignments and saving.
  4. Migration / recovery from missing or corrupted file.

---

### Task 3: Device Model & High-Res Kreo Visual Assets Preparation
- **Brief:**
  - Extract and prepare transparent high-contrast PNG silhouettes of Kreo Chimera V2 from `Mac_Peripheral_Control_Reference_Pack/references/`:
    - `kreo_black_1.png` (Top View)
    - `kreo_black_5.png` (Left Side View)
  - Create `DeviceGeometry.swift`:
    - Normalized hotspot polygons and label anchors for Front Side Button (`[0.22, 0.40]`) and Rear Side Button (`[0.22, 0.52]`) on the side view.
    - Normalized hotspot for Top View buttons.
    - Aspect-fit coordinate transformation function `mapNormalizedPoint(point:inSize:imageAspect:) -> CGPoint` for resolution-independent rendering.
  - Create `DeviceState.swift`: observable state containing connection status (reading `0x248a:0x5b4a` via IOKit), active view (`top` vs `leftSide`), highlighted/hovered/pressed buttons.
- **Verification:** Unit test `Tests/TestDeviceGeometry.swift` verifying coordinate projection stays within bounding box and matches aspect ratios at 1440x900 and 1100x720.

---

### Task 4: SwiftUI Native Application UI
- **Brief:** Implement complete native macOS SwiftUI interface:
  - `MainWindowView.swift`:
    - 64pt top toolbar: Device icon & "Kreo Chimera V2" title, connection badge ("USB Wireless Connected"), profile dropdown ("Desktop: Default"), and Pause Remapping button with visual badge.
    - 64pt left feature rail: Navigation icons for Assignments, Lighting (honestly marked unverified/unavailable), Diagnostics.
    - 304pt context panel:
      - Searchable action library: Wispr Flow Dictation (Push-to-Talk), Common Shortcuts (Undo ⌘Z, Redo ⇧⌘Z, Copy, Paste), Custom Key Recorder.
      - Selected button inspector: when Front or Rear side button is clicked, shows control name, physical mapping, current action, scope selector (Kreo Chimera vs All Mice), and Test button.
    - Central Device Stage:
      - View Switcher pill (`VIEW 1: TOP`, `VIEW 2: SIDE`) at bottom.
      - Large high-res device image rendered with aspect fit.
      - Interactive callout pins pointing to Front and Rear buttons with action labels (e.g. "Wispr Flow PTT", "Undo ⌘Z").
      - Hover and active press states with `.snappy` spring animation.
  - Respect `accessibilityReduceMotion`.
- **Verification:** Compile and run `MouseControl` target, verify view hierarchy renders without errors.

---

### Task 5: Application Packaging, End-to-End Build & Screenshots
- **Brief:**
  - Build standalone `.app` bundle: `MouseControl.app` with `Info.plist` including:
    - `CFBundleIdentifier = com.codepuri.mousecontrol`
    - `NSAccessibilityUsageDescription`
    - `NSInputMonitoringUsageDescription`
    - `LSUIElement = false` (full windowed app)
  - Run the application.
  - Capture real UI screenshots of the running app at:
    - 1440 × 900
    - 1100 × 720 (minimum supported size)
  - Inspect screenshots for label collisions, contrast, clipping, and design fidelity against R01/R02/R07. Save to `ui_evidence/`.
- **Verification:** Verification of generated screenshot files, exit code 0, inspection of visual layout.

---

### Task 6: Wispr Flow Integration & Functional Verification
- **Brief:**
  - Verify Push-to-Talk behavior:
    1. Key-down sent on button press, key-up sent on button release.
    2. Focus retention: verify frontmost application window does not lose focus.
    3. Event suppression: verify `otherMouseDown` button 3 & 4 do not trigger browser Back/Forward navigation.
    4. Pause toggle: when paused, mouse buttons pass through natively.
- **Verification:** Synthetic and live test verification with evidence logs.
