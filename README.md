# Big Arrow 🏹

A macOS utility that makes your cursor grow bigger the faster and longer you shake it. Keep shaking and it'll grow until it fills your entire screen!

## Demo

Move your mouse rapidly/shake it around → cursor grows bigger and bigger.  
Stop shaking → cursor shrinks back to normal.

The longer you keep shaking, the faster it grows!

## Installation

### Option 1: Build from Source (Recommended)

Requires Xcode Command Line Tools.

```bash
git clone <this-repo>
cd bigArrow
swift build -c release
```

Then run:
```bash
.build/release/BigArrow
```

### Option 2: Quick Run

```bash
swift run
```

## Usage

1. Run the app
2. Grant Accessibility permissions when prompted (System Settings → Privacy & Security → Accessibility)
3. A 🏹 icon appears in your menu bar
4. Start shaking your mouse!
5. Click the menu bar icon → Quit to exit

## How It Works

- Tracks mouse velocity across a sliding window
- When velocity exceeds threshold, the arrow starts growing
- The longer you maintain high velocity, the faster it grows
- Maximum size: 50x normal (fills most of the screen!)
- Smoothly shrinks back when you stop

## Permissions

Big Arrow needs **Accessibility** permissions to track your mouse globally. macOS will prompt you to grant this on first run.

## Uninstall

1. Quit the app from the menu bar
2. Delete the folder
3. Optionally remove from System Settings → Privacy & Security → Accessibility

## License

MIT - Do whatever you want with it!

