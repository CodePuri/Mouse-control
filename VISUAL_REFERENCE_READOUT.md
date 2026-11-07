# Visual Reference Readout: Kreo Chimera V2 & Multi-Device Mac Configurator

**Authoritative references evaluated:** `Mac_Peripheral_Control_Reference_Pack` (R01–R18), user uploads (`media_1794050798035_d4c5f92d.png`, `media_1794050820775_78ab4eb4.jpg`, `media_1794050830989_5a3d51ef.jpg`).

---

## 1. Reference Mapping & Design Synthesis

| Reference ID | Source Title / Image | Key Visual Elements | Concrete Implementation Decision |
|---|---|---|---|
| **R01 / User Upload 2** | G HUB on Mac: Mouse Assignments | 304pt left action panel (Commands, Keys, Actions, Macros, System); large centered mouse on dark canvas; anchored pointer pins leading to callout labels; profile indicator; native Mac window controls. | **Primary assignment layout.** Adopt two-column hierarchy: left sidebar with searchable actions, central device stage with high-contrast Kreo silhouette, anchored leader lines connecting Front/Rear side buttons to callout cards. |
| **R02 / R03** | Official G HUB Device Dashboard & Mac Discovered Card | Charcoal dark background (`#0B0D10`), clean device card showing large product render, battery indicator, connection status (USB/Wireless), active profile name. | **Device Header & Switcher.** Top 64pt toolbar displays connected device ("Kreo Chimera V2"), connection badge ("USB Wireless Receiver"), active profile ("Desktop: Default"), and a prominent **Pause Remapping** toggle button. |
| **R04 / R05 / R06** | G HUB Sensitivity, LIGHTSYNC & Settings | Stepped numeric indicators, discrete lighting effect controls with color picker, clear firmware/diagnostics separation. | **Feature Rail & Settings.** 64pt vertical rail on left margin providing icons for Assignments (`keyboard`), Lighting (`sun.max`), Performance (`speedometer`), Diagnostics (`wrench.and.screwdriver`). Kreo RGB protocol remains honestly labeled as unsupported until protocol verification. |
| **R07 / R08 / User Upload 3** | Options+ on Mac: Device Callouts & App Selection | Pill-shaped callout chips with action names (e.g., "Wispr Flow PTT", "Undo ⌘Z"), application picker popup, clean physical controls. | **Interactive Callouts & Scope.** Callouts display current assigned action directly on the stage. Clicking a callout opens its specific binding editor. Support both **Application Scope** (Global vs. Specific App) and **Device Scope** (Kreo Chimera vs. All Devices fallback). |
| **R11 / R12 / R13 (User Upload 1)** | Kreo Chimera V2 Black Top, Side & Angled Views | Exact physical contours: matte black shell, honeycomb top, purple illuminated side buttons (Front & Rear thumb buttons), purple DPI button, RGB rim. | **Actual Device Assets.** Bundle cutouts from official Kreo assets (`kreo_black_1.png` and `kreo_black_5.png`). Provide View 1 (Top) and View 2 (Left Side) toggle. Side view features calibrated SVG/Path hotspots for Front Side Button and Rear Side Button. |

---

## 2. Design Tokens & Styling (Apple Design + UI/UX Pro Max)

- **Canvas Background:** `#0B0D10` (deep gaming obsidian)
- **Surfaces / Context Panels:** `#16191F` (panel surface), `#212631` (elevated cards / hover states)
- **Borders & Dividers:** `#2D3442` (subtle 1px boundaries)
- **Accent Color:** `#27C7F7` (electric cyan highlight for active selections, pins, and callouts)
- **Secondary Accent:** `#A855F7` (Kreo brand purple for hardware accents)
- **Typography:** SF Pro Text / SF Pro Display
  - Window Title: 14pt Semibold
  - Device Header: 24pt Bold
  - Section Headings: 15pt Semibold
  - Body / Controls: 13pt Regular
  - Callout Badges / Shortcuts: 11pt Monospace / Semibold
- **Interaction Motion:** 150ms spring transitions (`.snappy`), immediate pointer-down visual feedback, zero lag.

---

## 3. Physical Side Button Architecture & Wispr Flow Integration

1. **Physical Button Identification:**
   - Front Side Button: physical forward button (standard macOS `otherMouseDown` button 4).
   - Rear Side Button: physical back button (standard macOS `otherMouseDown` button 3).
2. **Wispr Flow PTT Protocol Candidate:**
   - Wispr Flow is currently configured with virtual keycode **61** (`kVK_RightOption`) for PTT. Emulating this keycode on side button press/release is treated as a candidate requiring testing.
   - Suppression: Event tap consumes `otherMouseDown` and `otherMouseUp` for configured buttons so default actions (such as browser Back/Forward) are suppressed where remapped.
3. **Application & Device Scope:**
   - Active `CGEventTap` runs at the session level. Device attribution limitation is honestly documented (global mouse fallback when physical attribution cannot be established by Quartz).
   - Vendor HID interface (`0xFF01`) has unverified purpose; no guessed reports or hardware writes are attempted.
