import AppKit
import SwiftUI

@main
struct VideoCutterApp: App {
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
