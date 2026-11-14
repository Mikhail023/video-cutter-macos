import SwiftUI

struct CutRangePanel: View {
    @Bindable var store: EditorStore
    @State private var rangePrompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Что вырезать?")
                        .font(.subheadline.weight(.semibold))
                    Text("Введите интервал, например: 00:05–00:12. Границы можно подвинуть на таймлайне.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                TextField("00:05–00:12", text: $rangePrompt)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit(addPromptRange)
                Button("Добавить", action: addPromptRange)
                    .disabled(rangePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: store.applyPendingCuts) {
                    Label("Вырезать интервалы", systemImage: "scissors")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.pendingCutRanges.isEmpty || store.isRebuildingComposition)
                .help("Удалить отмеченные участки из монтажа")
            }

            if !store.pendingCutRanges.isEmpty {
                ForEach(Array(store.pendingCutRanges)) { range in
                    CutRangeEditorRow(range: range, store: store)
                }
            }

            if store.isRebuildingComposition {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Обновляю видео и таймлайн…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func addPromptRange() {
        let matches = timecodeMatches(in: rangePrompt)
        guard matches.count == 2,
              let start = VideoTimeFormatter.parse(matches[0]),
              let end = VideoTimeFormatter.parse(matches[1]) else {
            store.errorMessage = "Введите две отметки времени, например 00:05–00:12. Можно вводить и текст «вырезать с 00:05 по 00:12»."
            return
        }
        store.addCutRange(start: start, end: end)
        rangePrompt = ""
    }

    private func timecodeMatches(in text: String) -> [String] {
        let pattern = #"(?:\d{1,2}:){1,2}\d{1,2}(?:[.,]\d+)?|\d+(?:[.,]\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }
}

private struct CutRangeEditorRow: View {
    let range: CutRange
    let store: EditorStore
    @State private var startText: String
    @State private var endText: String

    init(range: CutRange, store: EditorStore) {
        self.range = range
        self.store = store
        _startText = State(initialValue: VideoTimeFormatter.editString(for: range.start))
        _endText = State(initialValue: VideoTimeFormatter.editString(for: range.end))
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "scissors")
                .foregroundStyle(.orange)
            Text("Вырезать")
                .font(.caption.weight(.medium))
            TextField("Начало", text: $startText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 84)
                .onSubmit(commitStart)
            Text("—").foregroundStyle(.secondary)
            TextField("Конец", text: $endText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 84)
                .onSubmit(commitEnd)
            Text("\(VideoTimeFormatter.string(for: range.end - range.start))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.removeCutRange(range.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Убрать интервал")
        }
        .font(.caption)
        .onChange(of: range.start) { _, value in startText = VideoTimeFormatter.editString(for: value) }
        .onChange(of: range.end) { _, value in endText = VideoTimeFormatter.editString(for: value) }
    }

    private func commitStart() {
        guard let value = VideoTimeFormatter.parse(startText) else { return }
        store.updateCutRange(range.id, start: value)
    }

    private func commitEnd() {
        guard let value = VideoTimeFormatter.parse(endText) else { return }
        store.updateCutRange(range.id, end: value)
    }
}
