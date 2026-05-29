import SwiftUI
import KeyboardShortcuts

@main
struct ClipSyncApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var clipboardMonitor: ClipboardMonitor
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settingsOpened = false
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _clipboardMonitor = StateObject(wrappedValue: ClipboardMonitor(context: context))
        
        // Set default keyboard shortcut
        if KeyboardShortcuts.getShortcut(for: .toggleClipSync) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .shift]), for: .toggleClipSync)
        }
    }
    
    var body: some Scene {
        MenuBarExtra("ClipSync", systemImage: "doc.on.clipboard") {
            ContentView(settingsOpened: $settingsOpened)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(clipboardMonitor)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasPositionedWindow = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launched - setting up keyboard shortcut")
        
        KeyboardShortcuts.onKeyUp(for: .toggleClipSync) { [self] in
            print("⌨️ Keyboard shortcut triggered!")
            hasPositionedWindow = false // Reset so next opening centers
            toggleClipSync()
        }
        
        // Observe when windows are created
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidUpdate(_:)),
            name: NSWindow.didUpdateNotification,
            object: nil
        )
    }
    
    @objc private func windowDidUpdate(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Center MenuBarExtra window immediately when it appears
        if window.className.contains("MenuBarExtra") && !hasPositionedWindow {
            hasPositionedWindow = true
            
            // Position immediately, before it's visible
            centerWindow(window)
            
            print("📋 ClipSync window positioned at center")
        }
    }
    
    private func centerWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        let x = screenFrame.midX - (windowFrame.width / 2)
        let y = screenFrame.midY - (windowFrame.height / 2) + 100 // Slightly above center like Spotlight
        
        window.setFrame(NSRect(x: x, y: y, width: windowFrame.width, height: windowFrame.height), display: false, animate: false)
    }
    
    private func toggleClipSync() {
        DispatchQueue.main.async {
            print("🔄 Toggling ClipSync")
            
            NSApp.activate(ignoringOtherApps: true)
            
            if let statusBarWindow = NSApp.windows.first(where: { $0.className.contains("StatusBarWindow") }) {
                if let contentView = statusBarWindow.contentView,
                   let button = self.findButton(in: contentView) {
                    print("🖱️ Clicking button")
                    button.performClick(nil)
                    return
                }
            }
            
            print("⚠️ Button not found")
        }
    }
    
    private func findButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton {
            return button
        }
        for subview in view.subviews {
            if let button = findButton(in: subview) {
                return button
            }
        }
        return nil
    }
}
