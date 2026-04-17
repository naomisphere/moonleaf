//
//  macpaperSaver.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import ScreenSaver
import AVFoundation
import Cocoa

@objc(macpaperSaverView)
class macpaperSaverView: ScreenSaverView {

    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var imageView: NSImageView?
    private var wallpaperPath: String?
    private var loopObserver: NSObjectProtocol?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        loadWallpaperPath()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        loadWallpaperPath()
    }

    private func loadWallpaperPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dirs = [
            home.appendingPathComponent("Library/Application Support/moonleaf"),
            home.appendingPathComponent("Library/Application Support/macpaper"),
        ]
        let videoExts = ["mp4", "mov"]
        let imageExts = ["jpg", "jpeg", "png"]

        for dir in dirs {
            guard FileManager.default.fileExists(atPath: dir.path),
                  let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }

            let named = files.filter { $0.deletingPathExtension().lastPathComponent == "current_screensaver_wallpaper" }
            for file in named {
                let ext = file.pathExtension.lowercased()
                if videoExts.contains(ext) || imageExts.contains(ext) {
                    wallpaperPath = file.path
                    return
                }
            }

            for file in files {
                let ext = file.pathExtension.lowercased()
                if videoExts.contains(ext) || imageExts.contains(ext) {
                    wallpaperPath = file.path
                    return
                }
            }
        }
    }

    override func startAnimation() {
        super.startAnimation()

        guard let path = wallpaperPath, FileManager.default.fileExists(atPath: path) else { return }

        let ext = (path as NSString).pathExtension.lowercased()

        if ["jpg", "jpeg", "png"].contains(ext) {
            showStaticImage(path: path)
        } else {
            showVideo(path: path)
        }
    }

    private func showStaticImage(path: String) {
        guard let img = NSImage(contentsOfFile: path) else { return }
        let iv = NSImageView(frame: bounds)
        iv.image = img
        iv.imageScaling = .scaleAxesIndependently
        iv.autoresizingMask = [.width, .height]
        addSubview(iv)
        imageView = iv
    }

    private func showVideo(path: String) {
        let url = URL(fileURLWithPath: path)
        player = AVPlayer(url: url)
        player?.isMuted = true
        player?.actionAtItemEnd = .none

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        playerLayer?.videoGravity = .resizeAspectFill

        if let pl = playerLayer {
            layer?.addSublayer(pl)
        }

        player?.play()

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
        if let obs = loopObserver { NotificationCenter.default.removeObserver(obs) }
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        imageView?.removeFromSuperview()
        imageView = nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        playerLayer?.frame = bounds
    }

    override func draw(_ rect: NSRect) { super.draw(rect) }
    override func animateOneFrame() {}
    override var hasConfigureSheet: Bool { false }
}