import AVFoundation
import AVKit
import AppKit
import Observation

@MainActor
@Observable
final class EditorStore {
    var project: VideoProject?
    var player: AVPlayer?
    var isImporting = false
    var errorMessage: String?
    var thumbnails: [TimelineThumbnail] = []
    var clips: [VideoClip] = []
    var pendingCutRanges: [CutRange] = []
    var markers: [TimeInterval] = []
    var selectedClipID: UUID?
    var currentTime: TimeInterval = 0
    var isPlaying = false
    var playbackRate: Float = 1
    var volume: Float = 1
    var exportProgress: Double?
    var exportMessage: String?
    var isRebuildingComposition = false

    private var sourceAsset: AVURLAsset?
    private var timeObserver: Any?
    private var securityScopedURL: URL?
    private var thumbnailGeneration = UUID()
    private var undoStack: [[VideoClip]] = []
    private var redoStack: [[VideoClip]] = []

    var timelineDuration: TimeInterval { clips.reduce(0) { $0 + $1.duration } }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func loadVideo(from url: URL) {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        if url.startAccessingSecurityScopedResource() { securityScopedURL = url }
        thumbnailGeneration = UUID()
        thumbnails = []
        clips = []
        pendingCutRanges = []
        markers = []
        project = nil
        player?.pause()
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player = nil
        isPlaying = false
        let asset = AVURLAsset(url: url)
        sourceAsset = asset
        Task {
            do {
                let duration = try await asset.load(.duration)
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                guard !videoTracks.isEmpty else {
                    errorMessage = "В выбранном файле не найдена видеодорожка."
                    return
                }
                project = VideoProject(url: url, duration: duration.seconds)
                clips = [VideoClip(sourceStart: 0, sourceEnd: duration.seconds)]
                selectedClipID = clips.first?.id
                currentTime = 0
                undoStack.removeAll()
                redoStack.removeAll()
                generateThumbnails(url: url, duration: duration.seconds)
                installPlayer(item: AVPlayerItem(asset: asset))
            } catch {
                errorMessage = "Не удалось открыть видео: \(error.localizedDescription)"
            }
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if currentTime >= timelineDuration { seek(to: 0) }
            player.playImmediately(atRate: playbackRate)
            isPlaying = true
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clampedTime = min(max(time, 0), timelineDuration)
        currentTime = clampedTime
        if let index = clipIndex(at: clampedTime), clips.indices.contains(index) {
            selectedClipID = clips[index].id
        }
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stepFrame(_ direction: Double) {
        seek(to: currentTime + direction / 30)
    }

    func addMarker() {
        guard timelineDuration > 0 else { return }
        if let existing = markers.firstIndex(where: { abs($0 - currentTime) < 0.25 }) {
            markers.remove(at: existing)
        } else {
            markers.append(currentTime)
            markers.sort()
        }
    }

    func addCutRange(start: TimeInterval, end: TimeInterval) {
        let safeStart = min(max(start, 0), timelineDuration)
        let safeEnd = min(max(end, 0), timelineDuration)
        guard safeEnd - safeStart >= 0.1 else {
            errorMessage = "Укажите интервал длительностью не менее 0,1 секунды."
            return
        }
        pendingCutRanges.append(CutRange(start: safeStart, end: safeEnd))
        pendingCutRanges.sort { $0.start < $1.start }
    }

    func updateCutRange(_ id: UUID, start: TimeInterval? = nil, end: TimeInterval? = nil) {
        guard let index = pendingCutRanges.firstIndex(where: { $0.id == id }) else { return }
        var range = pendingCutRanges[index]
        if let start {
            range.start = min(max(start, 0), range.end - 0.1)
        }
        if let end {
            range.end = max(min(end, timelineDuration), range.start + 0.1)
        }
        pendingCutRanges[index] = range
        pendingCutRanges.sort { $0.start < $1.start }
    }

    func removeCutRange(_ id: UUID) {
        pendingCutRanges.removeAll { $0.id == id }
    }

    func applyPendingCuts() {
        guard !pendingCutRanges.isEmpty, !isRebuildingComposition else { return }
        let sortedRanges = pendingCutRanges.sorted { $0.start < $1.start }
        var result: [VideoClip] = []
        var clipTimelineStart: TimeInterval = 0

        for clip in clips {
            let clipTimelineEnd = clipTimelineStart + clip.duration
            var sourceCursor = clip.sourceStart
            for cut in sortedRanges where cut.start < clipTimelineEnd && cut.end > clipTimelineStart {
                let intersectStart = max(cut.start, clipTimelineStart) - clipTimelineStart
                let intersectEnd = min(cut.end, clipTimelineEnd) - clipTimelineStart
                let sourceCutStart = clip.sourceStart + intersectStart
                let sourceCutEnd = clip.sourceStart + intersectEnd
                if sourceCutStart - sourceCursor >= 0.05 {
                    result.append(VideoClip(sourceStart: sourceCursor, sourceEnd: sourceCutStart))
                }
                sourceCursor = max(sourceCursor, sourceCutEnd)
            }
            if clip.sourceEnd - sourceCursor >= 0.05 {
                result.append(VideoClip(sourceStart: sourceCursor, sourceEnd: clip.sourceEnd))
            }
            clipTimelineStart = clipTimelineEnd
        }

        guard !result.isEmpty else {
            errorMessage = "Нельзя вырезать всё видео целиком. Оставьте хотя бы один фрагмент."
            return
        }

        saveUndo()
        let oldTime = currentTime
        currentTime = timelineTimeAfterRemoving(sortedRanges, at: oldTime)
        markers = markers.map { timelineTimeAfterRemoving(sortedRanges, at: $0) }
        clips = result
        pendingCutRanges.removeAll()
        selectedClipID = clipIndex(at: currentTime).flatMap { clips.indices.contains($0) ? clips[$0].id : nil } ?? clips.first?.id
        rebuildComposition()
    }

    private func timelineTimeAfterRemoving(_ ranges: [CutRange], at time: TimeInterval) -> TimeInterval {
        var removed: TimeInterval = 0
        for range in ranges {
            if time >= range.end {
                removed += range.end - range.start
            } else if time > range.start {
                return max(0, range.start - removed)
            } else {
                break
            }
        }
        return max(0, time - removed)
    }

    func splitAtPlayhead() {
        guard let index = clipIndex(at: currentTime), clips.indices.contains(index) else { return }
        let clip = clips[index]
        let start = timelineStart(of: index)
        let sourceCut = clip.sourceStart + (currentTime - start)
        guard sourceCut > clip.sourceStart + 0.05, sourceCut < clip.sourceEnd - 0.05 else { return }
        saveUndo()
        let left = VideoClip(sourceStart: clip.sourceStart, sourceEnd: sourceCut)
        let right = VideoClip(sourceStart: sourceCut, sourceEnd: clip.sourceEnd)
        clips.replaceSubrange(index...index, with: [left, right])
        selectedClipID = right.id
        rebuildComposition()
    }

    func deleteSelectedClip() {
        guard let selectedClipID,
              let index = clips.firstIndex(where: { $0.id == selectedClipID }), clips.count > 1 else { return }
        saveUndo()
        let deletedStart = timelineStart(of: index)
        let deletedDuration = clips[index].duration
        let deletedEnd = deletedStart + deletedDuration
        clips.remove(at: index)
        let selectedIndex = min(index, clips.count - 1)
        self.selectedClipID = clips[selectedIndex].id
        if currentTime >= deletedEnd {
            currentTime -= deletedDuration
        } else if currentTime >= deletedStart {
            currentTime = min(deletedStart, timelineDuration)
        }
        markers = markers.compactMap { marker in
            if marker >= deletedStart && marker < deletedEnd { return nil }
            return marker >= deletedEnd ? marker - deletedDuration : marker
        }
        rebuildComposition()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(clips)
        clips = previous
        selectedClipID = clips.first?.id
        currentTime = min(currentTime, timelineDuration)
        rebuildComposition()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(clips)
        clips = next
        selectedClipID = clips.first?.id
        currentTime = min(currentTime, timelineDuration)
        rebuildComposition()
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying { player?.rate = rate }
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        player?.volume = newVolume
    }

    func exportVideo(to url: URL) {
        guard pendingCutRanges.isEmpty else {
            errorMessage = "Сначала нажмите «Вырезать интервалы», чтобы применить отмеченные границы."
            return
        }
        guard !isRebuildingComposition else {
            errorMessage = "Дождитесь завершения обновления таймлайна."
            return
        }
        guard let asset = player?.currentItem?.asset ?? sourceAsset else { return }
        Task {
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                errorMessage = "Не удалось подготовить видео к экспорту."
                return
            }
            session.shouldOptimizeForNetworkUse = true
            exportProgress = 0
            exportMessage = nil
            do {
                let progressTask = Task { @MainActor in
                    while session.status == .waiting || session.status == .exporting {
                        self.exportProgress = Double(session.progress)
                        try? await Task.sleep(for: .milliseconds(150))
                    }
                }
                try await session.export(to: url, as: .mp4)
                progressTask.cancel()
                exportProgress = 1
                exportMessage = "Экспорт завершён: \(url.lastPathComponent)"
                try? await Task.sleep(for: .seconds(2))
                exportProgress = nil
            } catch {
                exportProgress = nil
                errorMessage = "Не удалось экспортировать видео: \(error.localizedDescription)"
            }
        }
    }

    func selectClip(_ clip: VideoClip) {
        selectedClipID = clip.id
    }

    func seek(to time: TimeInterval, in clip: VideoClip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        seek(to: timelineStart(of: index) + min(max(time - clip.sourceStart, 0), clip.duration))
    }

    private func installPlayer(item: AVPlayerItem) {
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = volume
        player = newPlayer
        let interval = CMTime(seconds: 1.0 / 15.0, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.player === newPlayer else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                self.isPlaying = newPlayer.timeControlStatus == .playing
            }
        }
    }

    private func generateThumbnails(url: URL, duration: TimeInterval) {
        let generation = thumbnailGeneration
        Task.detached(priority: .utility) { [weak self] in
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 180, height: 110)
            let count = min(max(Int(duration / 2.5), 12), 72)
            var frames: [(Int, TimeInterval, CGImage)] = []
            for index in 0..<count {
                let time = duration * (Double(index) + 0.5) / Double(count)
                do {
                    let cgImage = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
                    frames.append((index, time, cgImage))
                } catch {
                    continue
                }
            }
            await MainActor.run {
                guard let self, self.thumbnailGeneration == generation else { return }
                self.thumbnails = frames.map { TimelineThumbnail(id: $0.0, sourceTime: $0.1, image: NSImage(cgImage: $0.2, size: .zero)) }
            }
        }
    }

    private func saveUndo() {
        undoStack.append(clips)
        redoStack.removeAll()
    }

    private func timelineStart(of index: Int) -> TimeInterval {
        clips.prefix(index).reduce(0) { $0 + $1.duration }
    }

    private func clipIndex(at timelineTime: TimeInterval) -> Int? {
        var end: TimeInterval = 0
        for (index, clip) in clips.enumerated() {
            end += clip.duration
            if timelineTime < end - 0.001 { return index }
        }
        return clips.indices.last
    }

    private func rebuildComposition() {
        guard let sourceAsset, !isRebuildingComposition else { return }
        let clipsSnapshot = clips
        let playhead = min(currentTime, clipsSnapshot.reduce(0) { $0 + $1.duration })
        let wasPlaying = isPlaying
        player?.pause()
        isPlaying = false
        isRebuildingComposition = true

        Task {
            defer { isRebuildingComposition = false }
            do {
                let sourceVideo = try await sourceAsset.loadTracks(withMediaType: .video)
                let composition = AVMutableComposition()
                guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let sourceTrack = sourceVideo.first else { return }
                videoTrack.preferredTransform = try await sourceTrack.load(.preferredTransform)
                let sourceAudio = try await sourceAsset.loadTracks(withMediaType: .audio).first
                let audioTrack = sourceAudio.flatMap { _ in composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) }
                let sourceAudioRange = try await sourceAudio?.load(.timeRange)
                var cursor = CMTime.zero
                var newPlayhead = CMTime.zero
                for clip in clipsSnapshot {
                    let range = CMTimeRange(start: CMTime(seconds: clip.sourceStart, preferredTimescale: 600), duration: CMTime(seconds: clip.duration, preferredTimescale: 600))
                    try videoTrack.insertTimeRange(range, of: sourceTrack, at: cursor)
                    if let sourceAudio, let audioTrack, let sourceAudioRange,
                       range.start < sourceAudioRange.end {
                        let availableDuration = sourceAudioRange.end - range.start
                        let audioRange = CMTimeRange(start: range.start, duration: min(range.duration, availableDuration))
                        if audioRange.duration > .zero {
                            try audioTrack.insertTimeRange(audioRange, of: sourceAudio, at: cursor)
                        }
                    }
                    if cursor.seconds <= playhead { newPlayhead = cursor + min(range.duration, CMTime(seconds: playhead - cursor.seconds, preferredTimescale: 600)) }
                    cursor = cursor + range.duration
                }
                let item = AVPlayerItem(asset: composition)
                installPlayer(item: item)
                await player?.seek(to: newPlayhead, toleranceBefore: .zero, toleranceAfter: .zero)
                currentTime = newPlayhead.seconds
                if wasPlaying { player?.playImmediately(atRate: playbackRate); isPlaying = true }
            } catch {
                errorMessage = "Не удалось обновить монтаж: \(error.localizedDescription)"
            }
        }
    }
}
