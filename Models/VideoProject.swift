import AppKit
import Foundation

struct VideoProject: Equatable {
    let url: URL
    let duration: TimeInterval

    var title: String { url.deletingPathExtension().lastPathComponent }
}

struct VideoClip: Identifiable, Equatable {
    let id: UUID
    var sourceStart: TimeInterval
    var sourceEnd: TimeInterval

    init(id: UUID = UUID(), sourceStart: TimeInterval, sourceEnd: TimeInterval) {
        self.id = id
        self.sourceStart = sourceStart
        self.sourceEnd = sourceEnd
    }

    var duration: TimeInterval { max(0, sourceEnd - sourceStart) }
}

struct TimelineThumbnail: Identifiable {
    let id: Int
    let sourceTime: TimeInterval
    let image: NSImage
}
