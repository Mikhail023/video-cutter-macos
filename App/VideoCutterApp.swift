import AppKit
import SwiftUI

@main
struct VideoCutterApp: App {
    @NSApplicationDelegateAdaptor(WindowController.self) private var windowController
    @State private var store = EditorStore()

    var body: some Scene {
        WindowGroup("Нарезка видео") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Открыть видео…") {
                    store.isImporting = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

final class WindowController: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = NSApp.windows.first,
                  !window.styleMask.contains(.fullScreen) else { return }

            window.collectionBehavior.insert(.fullScreenPrimary)
            window.toggleFullScreen(nil)
        }
    }
}
