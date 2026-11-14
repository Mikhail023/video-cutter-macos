import Foundation

struct VideoProject: Equatable {
    let url: URL
    let duration: TimeInterval

    var title: String { url.deletingPathExtension().lastPathComponent }
}
