# Big Arrow 🏹

<video src="https://github.com/callumreid/bigCursor/raw/main/bigCursor.mp4" autoplay loop muted playsinline width="100%"></video>

**Shake your mouse cursor and watch it grow HUGE!**

The longer and faster you shake, the bigger it gets — until it fills your entire screen. Stop shaking and it smoothly shrinks back to normal.

---

## Download

**[⬇️ Download Big Arrow](../../releases/latest)** (macOS 13+)

### Installation

1. Download `BigArrow.dmg` from the link above
2. Open the DMG and drag **Big Arrow** to your Applications folder
3. **First time only:** Right-click the app → **Open** (this bypasses macOS security for unsigned apps)
4. Click **Open** when prompted
5. Grant **Accessibility** permissions when asked (System Settings → Privacy & Security → Accessibility)

That's it! Look for the 🏹 in your menu bar.

---

## How to Use

1. **Shake your mouse rapidly** for about 1.5 seconds
2. Watch your cursor start growing!
3. **Keep shaking** — it keeps growing bigger and bigger
4. **Stop shaking** — it smoothly shrinks back to normal

The faster you shake, the faster it grows. Max size fills most of your screen!

---

## Quit / Uninstall

- **Quit:** Click the 🏹 menu bar icon → Quit
- **Uninstall:** Drag Big Arrow from Applications to Trash

---

## For Developers

### Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/BigArrow.git
cd BigArrow
swift build -c release
.build/release/BigArrow
```

### Create Distributable App

```bash
chmod +x build-app.sh
./build-app.sh
```

This creates:
- `Big Arrow.app` — the macOS application
- `BigArrow.dmg` — disk image for easy sharing

---

## Technical Details

- Tracks mouse velocity over a sliding window
- Requires 1.5 seconds of sustained rapid movement before growth begins
- Arrow grows up to 500x normal size
- Works across multiple displays
- Runs as a menu bar app (no Dock icon)

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions (for global mouse tracking)

## License

MIT — do whatever you want with it!
