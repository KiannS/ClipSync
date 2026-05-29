# ClipSync

A lightweight macOS clipboard manager that lives in your menu bar. ClipSync automatically captures your clipboard history, categorizes every entry, and lets you search, pin, and re-copy past clips instantly.

---

## Features

### Clipboard History
ClipSync monitors your clipboard in real time using NSPasteboard polling on a background timer. Every new text entry or image you copy is automatically saved to a persistent local history powered by CoreData.

### Smart Categorization
Every clip is automatically classified into one of eight categories:

| Category | Detection Method |
|----------|-----------------|
| URL | Regex pattern matching on http/https/www prefixes |
| Email | RFC-style regex on address format |
| Address | NSDataDetector with keyword cross-validation |
| Phone | Digit count + formatting heuristics + address exclusion |
| Code | Keyword detection for common syntax patterns |
| Number | Pure numeric regex |
| Image | NSImage pasteboard type detection |
| Text | Default fallback |

Categories are detected with priority ordering to avoid false positives — addresses are checked before phone numbers since street numbers would otherwise match the phone pattern.

### Context-Aware Actions
Clicking a clip copies it back to your clipboard. Right-clicking opens a context menu with actions tailored to the clip type:

- **URL** — Open in Browser
- **Email** — Open in Mail
- **Phone** — Call with FaceTime
- **Address** — Open in Maps
- **Image** — Open in Preview, Copy Image, Save As

All routing is handled via NSWorkspace URL scheme handlers.

### Search
Full-text search across clipboard history with real-time filtering as you type.

### Pin
Pin important clips to keep them permanently surfaced above the main history feed regardless of how many new items come in.

### Keyboard Shortcut
Global keyboard shortcut (default: ⌘⇧V) activates ClipSync system-wide from any application. Shortcut is fully customizable via Settings. Registration handled via CGEventTap through the KeyboardShortcuts library.

### Automatic Cleanup
Clipboard history is automatically pruned based on two configurable rules:
- **History limit** — maximum number of unpinned items to retain (default: 100)
- **Auto-delete** — remove items older than N days

Cleanup runs probabilistically (1 in 10 clipboard events) to avoid performance overhead. Pinned items are always preserved.

### Settings
- Customize keyboard shortcut
- Set history limit
- Configure auto-delete window
- Manual cleanup trigger

---

## Architecture

| Component | Role |
|-----------|------|
| `ClipboardMonitor` | NSPasteboard polling, CoreData writes, duplicate detection, cleanup |
| `CategoryDetector` | Rule-based clip classification with regex and NSDataDetector |
| `ContentView` | SwiftUI menu bar window, search, pinning, context menus |
| `SettingsView` | User preferences via UserDefaults |
| `KeyboardShortcutManager` | Global shortcut registration via KeyboardShortcuts |
| `Persistence` | CoreData stack (singleton pattern) |
| `ClipSyncApp` | App entry point, AppDelegate for window positioning |

The app runs as a MenuBarExtra with no Dock icon. The window is positioned at screen center (slightly above midpoint, Spotlight-style) each time the shortcut is triggered.

---

## Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** CoreData
- **Clipboard:** NSPasteboard
- **Address Detection:** NSDataDetector
- **App Routing:** NSWorkspace URL scheme handlers
- **Keyboard Shortcuts:** KeyboardShortcuts (open source library)
- **Testing:** XCTest, XCUITest

---

## Planned Features

- **LLM summarization** — Llama API integration for automatic summarization of long clipboard entries, cached locally to avoid redundant calls
- **Cross-platform sync** — Real-time clipboard sync between macOS and Android via a WebSocket relay server
- **Core ML classification** — Replace rule-based categorization with a trained on-device model for higher accuracy across edge cases

---

## Running Locally

1. Clone the repo
2. Open `ClipSync.xcodeproj` in Xcode
3. Build and run (macOS 13+ required)
4. Grant accessibility permissions when prompted (required for global keyboard shortcut)

ClipSync will appear in your menu bar. Press ⌘⇧V or click the menu bar icon to open.

---

## Notes

This is a personal project built for fun with no external spec or deadline. The codebase is actively developed — contributions and feedback welcome.

*Built by Kiann Skkandann*
