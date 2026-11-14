import SwiftUI

struct EmptyEditorView: View {
    let openVideo: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Откройте видео", systemImage: "film.stack")
        } description: {
            Text("Выберите MP4, MOV или перетащите файл сюда, чтобы начать монтаж.")
        } actions: {
            Button("Выбрать видео", action: openVideo)
                .buttonStyle(.borderedProminent)
        }
    }
}
