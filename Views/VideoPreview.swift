import AVFoundation
import AVKit
import SwiftUI

struct VideoPreview: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerCanvas {
        let view = PlayerCanvas()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerCanvas, context: Context) {
        nsView.playerLayer.player = player
    }
}

final class PlayerCanvas: NSView {
    override var wantsLayer: Bool {
        get { true }
        set { }
    }

    var playerLayer: AVPlayerLayer {
        if let layer = layer as? AVPlayerLayer { return layer }
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        layer = playerLayer
        return playerLayer
    }

    override func makeBackingLayer() -> CALayer {
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        return playerLayer
    }
}
