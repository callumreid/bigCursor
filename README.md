# bigCursor 🖱️

![bigCursor Demo](bigCursor.gif)

**Shake your mouse cursor and watch it grow HUGE, then split into a swarm!**

The longer and faster you shake, the bigger it gets. Shake even harder and extra cursors burst out from the primary cursor, track along with it, and fade back away when the motion settles.

---

## Download

**[⬇️ Download bigCursor](../../releases/latest)** (macOS 13+)

### Homebrew (recommended)

```bash
brew tap callumreid/bigCursor https://github.com/callumreid/bigCursor
brew install --cask bigcursor
```

### Installation

1. Download `bigCursor.dmg` from the link above
2. Open the DMG and drag **bigCursor** to your Applications folder
3. **Important - bypass Gatekeeper** (unsigned app):
   ```bash
   xattr -cr /Applications/bigCursor.app
   ```
4. Double-click to open, then grant **Accessibility** permissions when asked (System Settings → Privacy & Security → Accessibility)

That's it! Look for the 🖱️ in your menu bar.

> **Note:** If you see "damaged and can't be opened", run the `xattr -cr` command above. The app isn't damaged — macOS blocks unsigned apps downloaded from the internet.

---

## How to Use

1. **Shake your mouse rapidly** for about 1.5 seconds
2. Watch your cursor start growing!
3. **Shake harder** to spawn extra cursors that shoot out from the primary cursor
4. **Keep shaking** to make the whole cursor swarm grow bigger and bigger
5. **Stop shaking** and the extra cursors fade out while the primary cursor smoothly shrinks back to normal

Moderately fast shaking grows the cursor. Extra-fast shaking multiplies it. Max size fills most of your screen.

**Toggle Light/Dark Mode:** Click the 🖱️ menu bar icon to switch between a black cursor (dark mode) and white cursor (light mode).

---

## Quit / Uninstall

- **Quit:** Right-click the 🖱️ menu bar icon → Quit
- **Uninstall:** Drag bigCursor from Applications to Trash

---

## For Developers

### Build from Source

```bash
git clone https://github.com/callumreid/bigCursor.git
cd bigCursor
swift build -c release
.build/release/bigCursor
```

### Create Distributable App

```bash
chmod +x build-app.sh
./build-app.sh
```

This creates:
- `bigCursor.app` — the macOS application
- `bigCursor.dmg` — disk image for easy sharing

---

## Technical Details

- Tracks mouse velocity over a sliding window
- Requires 1.5 seconds of sustained rapid movement before growth begins
- Very fast movement spawns additional cursors with no fixed cap
- Cursor grows up to 500x normal size
- Works across multiple displays
- Runs as a menu bar app (no Dock icon)
- Click menu bar icon to toggle light/dark mode

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions (for global mouse tracking)

## License

MIT — do whatever you want with it!
