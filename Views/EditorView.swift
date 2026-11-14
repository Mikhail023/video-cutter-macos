import SwiftUI

struct EditorView: View {
    @Bindable var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let player = store.player {
                    VideoPreview(player: player)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
            TimelineView(duration: store.project?.duration ?? 0)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: store.togglePlayback) {
                Label("Воспроизвести", systemImage: "play.fill")
            }
            .keyboardShortcut(.space, modifiers: [])

            Divider().frame(height: 20)

            ForEach(["Нарезка", "Субтитры", "Разрезать", "Удалить"], id: \.self) { title in
                Button(title) {}
                    .disabled(true)
            }

            Spacer()
            Button("Экспорт") {}
                .disabled(true)
        }
        .padding(12)
        .background(.bar)
    }
}
