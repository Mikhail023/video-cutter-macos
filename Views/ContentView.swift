import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.project == nil {
                EmptyEditorView(openVideo: { store.isImporting = true })
            } else {
                EditorView(store: store)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $store.isImporting,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]
        ) { result in
            switch result {
            case .success(let url):
                store.loadVideo(from: url)
            case .failure(let error):
                store.errorMessage = "Не удалось выбрать файл: \(error.localizedDescription)"
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "scissors")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
            Text("Нарезка видео")
                .font(.headline)
            Spacer()
            if let project = store.project {
                Text(project.title)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button("Открыть видео…") { store.isImporting = true }
                .keyboardShortcut("o", modifiers: .command)
        }
        .padding(16)
    }
}
