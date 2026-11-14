import AppKit
import UniformTypeIdentifiers
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
            transport
            if let exportMessage = store.exportMessage {
                HStack {
                    Label(exportMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                }
                .font(.caption)
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
            TimelineView(store: store)
        }
    }

    private var transport: some View {
        HStack(spacing: 12) {
            Button(action: store.togglePlayback) {
                Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help(store.isPlaying ? "Пауза (Пробел)" : "Воспроизвести (Пробел)")
            Button { store.stepFrame(-1) } label: { Image(systemName: "backward.end.fill") }
                .help("На один кадр назад")
            Button { store.stepFrame(1) } label: { Image(systemName: "forward.end.fill") }
                .help("На один кадр вперёд")

            Text(VideoTimeFormatter.string(for: store.currentTime))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { store.currentTime },
                set: { store.seek(to: $0) }
            ), in: 0...max(store.timelineDuration, 0.01))
            .controlSize(.small)
            .help("Позиция воспроизведения")
            Text(VideoTimeFormatter.string(for: store.timelineDuration))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.secondary)

            Divider().frame(height: 24)

            Button(action: store.undo) { Image(systemName: "arrow.uturn.backward") }
                .help("Отменить")
                .disabled(!store.canUndo)
            Button(action: store.redo) { Image(systemName: "arrow.uturn.forward") }
                .help("Повторить")
                .disabled(!store.canRedo)
            Divider().frame(height: 24)
            Button(action: store.splitAtPlayhead) {
                Label("Разрезать", systemImage: "scissors")
            }
            .keyboardShortcut("b", modifiers: [])
            .help("Разрезать клип в позиции playhead (B)")
            Button(action: store.deleteSelectedClip) {
                Label("Удалить фрагмент", systemImage: "trash")
            }
            .disabled(store.clips.count < 2)
            .help("Удалить выбранный фрагмент")
            Button(action: store.addMarker) {
                Label("Маркер", systemImage: "mappin.and.ellipse")
            }
            .help("Поставить или убрать маркер на текущем кадре")

            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button("\(rate.formatted())×") { store.setPlaybackRate(Float(rate)) }
                }
            } label: {
                Label("\(store.playbackRate.formatted())×", systemImage: "speedometer")
            }
            .help("Скорость воспроизведения")

            Image(systemName: store.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { Double(store.volume) },
                set: { store.setVolume(Float($0)) }
            ), in: 0...1)
            .frame(width: 72)
            .controlSize(.small)
            .help("Громкость")
            Button(action: exportVideo) {
                Label("Экспорт", systemImage: "square.and.arrow.up")
            }
            .help("Сохранить результат в MP4")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
        .overlay(alignment: .bottom) {
            if let progress = store.exportProgress {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
                    .offset(y: 4)
            }
        }
    }

    private func exportVideo() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "\(store.project?.title ?? "Видео")_монтаж.mp4"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            store.exportVideo(to: url)
        }
    }
}
