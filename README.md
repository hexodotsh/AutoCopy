# 📋 AutoCopy

A lightweight macOS menu bar utility that **automatically copies any text you select** to your clipboard — no ⌘C needed.

Select a word, drag across a sentence, or triple-click a paragraph — it's instantly on your clipboard.

---

## ✨ Features

- **Auto-copy on select** — highlight any text and it's copied instantly
- **Double-click support** — double-click a word to select and copy it
- **Triple-click support** — triple-click to select and copy a full line or paragraph
- **Drag selection** — click and drag across text to copy
- **Menu bar icon** — clean clipboard icon in your top bar with quick controls
- **Toggle on/off** — easily disable and re-enable from the menu bar
- **Launch at Login** — built-in option to start automatically on boot
- **Visual feedback** — icon flashes ✅ when text is copied
- **No dock icon** — runs silently in the menu bar only
- **Universal** — works in any app that supports ⌘C (browsers, editors, terminals, PDFs, etc.)

---

## 📸 How It Looks

| Menu Bar Icon | Copied Feedback |
|:---:|:---:|
| 📋 (clipboard icon in top bar) | ✅ (flashes briefly on copy) |

**Menu options:** Disable/Enable AutoCopy · Launch at Login · About · Quit

---

## 🚀 Install

### Requirements

- macOS 12+ (Monterey or later)
- Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```

### Build & Install

```bash
git clone https://github.com/YOUR_USERNAME/AutoCopy.git
cd AutoCopy
chmod +x build.sh
./build.sh
```

This compiles the Swift source and installs `AutoCopy.app` into `/Applications`.

### Grant Accessibility Access (one-time)

AutoCopy needs Accessibility permission to detect selections and simulate ⌘C.

1. Open **System Settings → Privacy & Security → Accessibility**
2. Click the **+** button (unlock with your password if needed)
3. Navigate to `/Applications`, select **AutoCopy**, click **Open**
4. Make sure the toggle next to AutoCopy is **ON**

### Launch

```bash
open /Applications/AutoCopy.app
```

Or find it via Spotlight / Launchpad.

---

## 🎯 Usage

Once running, a **clipboard icon** appears in your menu bar. That's it — just select text anywhere:

| Action | What Happens |
|---|---|
| **Click + drag** across text | Selected text is copied |
| **Double-click** a word | Word is copied |
| **Triple-click** a line | Entire line/paragraph is copied |

The menu bar icon briefly flashes ✅ to confirm each copy.

### Menu Bar Controls

Click the 📋 icon to access:

| Option | Description |
|---|---|
| Disable / Enable AutoCopy | Toggle auto-copy on or off |
| Launch at Login | Auto-start when you log in (macOS 13+) |
| About AutoCopy | Version info |
| Quit AutoCopy | Stop the app |

---

## ⚙️ How It Works

AutoCopy uses a completely different approach from clipboard managers or Accessibility API readers — it simulates what you'd do manually:

1. A **global CGEvent tap** monitors all mouse events system-wide
2. On **mouse-down**, records the cursor position
3. On **mouse-up**, checks what happened:
   - **Drag** (moved 8+ pixels) → it was a text selection
   - **Double-click** → word selection
   - **Triple-click** → line/paragraph selection
4. After a brief delay (to let the target app finish updating its selection), it **simulates ⌘C**
5. If the clipboard content changed, flashes the ✅ confirmation

This approach works universally because it uses the exact same copy mechanism as pressing ⌘C yourself.

---

## ✅ Compatibility

| App | Works |
|---|:---:|
| Safari | ✅ |
| Chrome / Edge / Arc | ✅ |
| Firefox | ✅ |
| VS Code / Cursor | ✅ |
| Xcode | ✅ |
| TextEdit / Notes / Pages | ✅ |
| Terminal / iTerm2 / Warp | ✅ |
| Microsoft Word / Excel | ✅ |
| Preview (PDFs) | ✅ |
| Finder (filenames) | ✅ |
| Any app that supports ⌘C | ✅ |

---

## 🗑️ Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

Then optionally remove Accessibility access from System Settings.

---

## 🐛 Troubleshooting

**Nothing happens when I select text**
→ Accessibility access must be granted and toggled ON for AutoCopy in System Settings → Privacy & Security → Accessibility.

**No menu bar icon**
→ Check if AutoCopy is running: `ps aux | grep AutoCopy`. Some menu bar managers may hide overflow icons.

**Double-click doesn't copy**
→ Make sure you're on v2.1+. Rebuild with `./build.sh` if you updated the source.

**⌘C gets triggered on non-text drags (scrollbars, windows)**
→ AutoCopy only fires ⌘C after a drag. If nothing was actually selected, the clipboard stays unchanged — no harm done.

**"Launch at Login" doesn't stick**
→ Uses `SMAppService` which requires macOS 13+. On older versions, add AutoCopy manually via System Settings → General → Login Items.

---

## 📁 Project Structure

```
AutoCopy/
├── main.swift            # App entry point
├── AppDelegate.swift     # All logic: menu bar, event tap, clipboard, ⌘C simulation
├── Info.plist            # App bundle configuration (LSUIElement hides dock icon)
├── build.sh              # Compile + bundle + install to /Applications
├── uninstall.sh          # Remove app + stop running instance
└── README.md
```

---

## 📄 License

MIT — do whatever you want with it.
