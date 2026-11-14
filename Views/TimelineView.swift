import SwiftUI

struct TimelineView: View {
    @Bindable var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Видеодорожка", systemImage: "film")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(store.clips.count) фрагм.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(VideoTimeFormatter.string(for: store.timelineDuration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                let totalWidth = max(geometry.size.width, 1)
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(Array(store.clips.enumerated()), id: \.element.id) { index, clip in
                            clipTile(clip, index: index)
                                .frame(width: max(44, totalWidth * clip.duration / max(store.timelineDuration, 0.01) - 3))
                        }
                    }

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = min(max(value.location.x / totalWidth, 0), 1)
                                store.seek(to: fraction * store.timelineDuration)
                            })

                    ForEach(store.pendingCutRanges) { range in
                        CutRangeTimelineOverlay(
                            range: range,
                            duration: store.timelineDuration,
                            width: totalWidth,
                            update: { start, end in store.updateCutRange(range.id, start: start, end: end) }
                        )
                    }

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 76)
                        .overlay(alignment: .top) {
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 9))
                                .rotationEffect(.degrees(180))
                                .offset(y: -5)
                        }
                        .offset(x: min(totalWidth - 2, totalWidth * store.currentTime / max(store.timelineDuration, 0.01)))
                        .allowsHitTesting(false)

                    ForEach(Array(store.markers.enumerated()), id: \.offset) { _, marker in
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.yellow)
                            .offset(x: min(totalWidth - 14, totalWidth * marker / max(store.timelineDuration, 0.01)), y: -25)
                            .allowsHitTesting(false)
                    }

                }
            }
            .frame(height: 76)

            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
                Text("Аудио")
                Text("Исходная звуковая дорожка")
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .font(.caption2)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func clipTile(_ clip: VideoClip, index: Int) -> some View {
        let matchingImages = store.thumbnails.filter { $0.sourceTime >= clip.sourceStart && $0.sourceTime < clip.sourceEnd }
        let images = matchingImages.isEmpty
            ? store.thumbnails.min(by: { abs($0.sourceTime - (clip.sourceStart + clip.duration / 2)) < abs($1.sourceTime - (clip.sourceStart + clip.duration / 2)) }).map { [$0] } ?? []
            : matchingImages
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 1) {
                    ForEach(images) { thumbnail in
                        Image(nsImage: thumbnail.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: max(36, geometry.size.width / CGFloat(max(images.count, 1))), height: 72)
                            .clipped()
                    }
                    if images.isEmpty {
                        Rectangle().fill(Color.secondary.opacity(0.2))
                    }
                }
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
            .frame(width: geometry.size.width, height: 72)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(store.selectedClipID == clip.id ? Color.accentColor : Color.white.opacity(0.22), lineWidth: store.selectedClipID == clip.id ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture { store.selectClip(clip) }
            .help("Фрагмент \(index + 1) · \(VideoTimeFormatter.string(for: clip.duration))")
        }
    }
}

private struct CutRangeTimelineOverlay: View {
    let range: CutRange
    let duration: TimeInterval
    let width: CGFloat
    let update: (TimeInterval?, TimeInterval?) -> Void
    @State private var startDragAnchor: TimeInterval?
    @State private var endDragAnchor: TimeInterval?

    var body: some View {
        let safeDuration = max(duration, 0.01)
        let startX = width * range.start / safeDuration
        let endX = width * range.end / safeDuration
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.red.opacity(0.30))
                .frame(width: max(endX - startX, 2), height: 76)
                .offset(x: startX)
                .allowsHitTesting(false)

            handle(color: .orange)
                .offset(x: startX - 5)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startDragAnchor == nil { startDragAnchor = range.start }
                        let next = (startDragAnchor ?? range.start) + value.translation.width / width * safeDuration
                        update(min(max(next, 0), range.end - 0.1), nil)
                    }
                    .onEnded { _ in startDragAnchor = nil })

            handle(color: .red)
                .offset(x: endX - 5)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if endDragAnchor == nil { endDragAnchor = range.end }
                        let next = (endDragAnchor ?? range.end) + value.translation.width / width * safeDuration
                        update(nil, max(min(next, duration), range.start + 0.1))
                    }
                    .onEnded { _ in endDragAnchor = nil })
        }
        .frame(width: width, height: 76, alignment: .leading)
        .overlay(alignment: .topLeading) {
            Text("ВЫРЕЗАТЬ · \(VideoTimeFormatter.string(for: range.start))–\(VideoTimeFormatter.string(for: range.end))")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(.red.opacity(0.9), in: Capsule())
                .offset(x: min(max(startX, 0), max(width - 170, 0)), y: 3)
                .allowsHitTesting(false)
        }
    }

    private func handle(color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: 10, height: 76)
            .overlay(alignment: .top) {
                Circle().fill(color).frame(width: 12, height: 12).offset(y: 1)
            }
            .frame(width: 20, height: 76)
            .contentShape(Rectangle())
    }
}
