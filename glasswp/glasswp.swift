//
//  glasswp.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import AVFoundation
import AppKit
import Accelerate
import Foundation
import MediaToolbox

let g_lock = NSLock()
var g_display_bins = [Float](repeating: 0, count: 96)
let g_bar_count = 64

class GlasswpApp: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var mp: AVPlayer?
    var playerItem: AVPlayerItem?
    var playerLayer: AVPlayerLayer?
    var vizView: VisualizerView?
    var vizEngine: RealVisualizerEngine?
    var loopObserver: NSObjectProtocol?
    var vizMode: String = "disabled"
    var vizColorMode: String = "rainbow"
    var vizCustomColor: String = "#FF00FF"
    var vizTransparency: Double = 0.6
    var vizBarCount: Int = 64
    var vizMaxHeight: Double = 0.5
    var vizMinHeight: Double = 4.0
    var entryFilePath: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadVisualizerSettings()
        setupWindow()
        playWallpaper(filePath: entryFilePath)
        registerNotifications()
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }

        let wnd = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        wnd.isOpaque = false
        wnd.backgroundColor = .black
        wnd.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        wnd.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        wnd.ignoresMouseEvents = true
        wnd.makeKeyAndOrderFront(nil)
        window = wnd
    }

    private func playWallpaper(filePath: String) {
        guard let wnd = window else { return }

        let url = URL(fileURLWithPath: filePath)
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        playerItem = item
        mp = player

        let volume = readVolume()
        player.volume = Float(volume)

        let layer = AVPlayerLayer(player: player)
        layer.frame = wnd.contentView?.bounds ?? wnd.frame
        layer.videoGravity = .resizeAspectFill
        wnd.contentView?.wantsLayer = true
        wnd.contentView?.layer?.addSublayer(layer)
        playerLayer = layer

        player.play()

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        if vizMode != "disabled" {
            setupVisualizer(on: wnd, item: item)
        }
    }

    private func setupVisualizer(on window: NSWindow, item: AVPlayerItem) {
        guard let contentView = window.contentView else { return }

        let vv = VisualizerView(frame: contentView.bounds)
        vv.autoresizingMask = [.width, .height]
        vv.barCount = vizBarCount
        vv.colorMode = vizColorMode
        vv.customColorHex = vizCustomColor
        vv.transparency = vizTransparency
        vv.maxHeight = vizMaxHeight
        vv.minBarHeight = CGFloat(vizMinHeight)
        contentView.addSubview(vv)
        vizView = vv

        let engine = RealVisualizerEngine(barCount: vizBarCount)
        engine.onUpdate = { [weak vv] bins in
            vv?.updateBins(bins)
        }
        engine.attach(to: item)
        vizEngine = engine
    }

    private func readVolume() -> Double {
        let volFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/moonleaf/volume")
        if let data = try? Data(contentsOf: volFile),
           let str = String(data: data, encoding: .utf8),
           let intVal = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return Double(max(0, min(100, intVal))) / 100.0
        }
        return 0.5
    }

    private func loadVisualizerSettings() {
        let settingsFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/moonleaf/settings.json")
        guard FileManager.default.fileExists(atPath: settingsFile.path),
              let data = try? Data(contentsOf: settingsFile),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        vizMode = settings["visualizer_mode"] as? String ?? "disabled"
        vizColorMode = settings["visualizer_colorMode"] as? String ?? "rainbow"
        vizCustomColor = settings["visualizer_customColor"] as? String ?? "#FF00FF"
        vizTransparency = settings["visualizer_transparency"] as? Double ?? 0.6
        vizBarCount = settings["visualizer_barCount"] as? Int ?? 64
        vizMaxHeight = settings["visualizer_maxHeight"] as? Double ?? 0.5
        vizMinHeight = settings["visualizer_minHeight"] as? Double ?? 4.0
    }

    private func registerNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleVolumeChange(_:)),
            name: Notification.Name("com.naomisphere.moonleaf.volumeChanged"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleVizSettingsChange),
            name: Notification.Name("com.naomisphere.moonleaf.visualizerSettingsChanged"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAutoPause(_:)),
            name: Notification.Name("com.naomisphere.moonleaf.autoPauseChanged"),
            object: nil
        )
    }

    @objc private func handleVolumeChange(_ notification: Notification) {
        if let vol = notification.userInfo?["volume"] as? Float {
            DispatchQueue.main.async { self.mp?.volume = vol }
        }
    }

    @objc private func handleVizSettingsChange() {
        loadVisualizerSettings()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let vv = self.vizView else { return }
            vv.isHidden = (self.vizMode == "disabled")
            vv.barCount = self.vizBarCount
            vv.colorMode = self.vizColorMode
            vv.customColorHex = self.vizCustomColor
            vv.transparency = self.vizTransparency
            vv.maxHeight = self.vizMaxHeight
            vv.minBarHeight = CGFloat(self.vizMinHeight)
            vv.setNeedsDisplay(vv.bounds)
        }
    }

    @objc private func handleAutoPause(_ notification: Notification) {
        if let enabled = notification.userInfo?["ap_is_enabled"] as? Bool, enabled {
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(handleWorkspaceChange),
                name: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil
            )
        } else {
            NSWorkspace.shared.notificationCenter.removeObserver(self)
            DispatchQueue.main.async { self.mp?.play() }
        }
    }

    @objc private func handleWorkspaceChange() {}
}

final class RealVisualizerEngine {
    private let barCount: Int
    private let fftSize = 2048
    private var fftSetup: OpaquePointer?
    private var hannWindow = [Float]()
    private var realIn = [Float]()
    private var imagIn = [Float]()
    private var realOut = [Float]()
    private var imagOut = [Float]()
    private var smoothed = [Float]()
    private var tap: MTAudioProcessingTap?
    private var displayTimer: DispatchSourceTimer?
    var onUpdate: (([Float]) -> Void)?

    init(barCount: Int) {
        self.barCount = barCount
        smoothed = [Float](repeating: 0, count: barCount)
        g_display_bins = [Float](repeating: 0, count: barCount)

        let n = fftSize
        hannWindow = (0..<n).map { i in
            0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(n - 1)))
        }
        realIn = [Float](repeating: 0, count: n)
        imagIn = [Float](repeating: 0, count: n)
        realOut = [Float](repeating: 0, count: n)
        imagOut = [Float](repeating: 0, count: n)

        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(n), .FORWARD)

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        displayTimer = timer
    }

    deinit {
        displayTimer?.cancel()
        if let s = fftSetup { vDSP_DFT_DestroySetup(s) }
    }

    func attach(to playerItem: AVPlayerItem) {
        let retainedSelf = Unmanaged.passRetained(self)
        let clientPtr = retainedSelf.toOpaque()

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: clientPtr,
            `init`: { (tap: MTAudioProcessingTap, clientInfo: UnsafeMutableRawPointer?, tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { (tap: MTAudioProcessingTap) in
                Unmanaged<RealVisualizerEngine>
                    .fromOpaque(MTAudioProcessingTapGetStorage(tap))
                    .release()
            },
            prepare: nil,
            unprepare: nil,
            process: { (tap: MTAudioProcessingTap, frameCount: CMItemCount, flags: MTAudioProcessingTapFlags, bufferList: UnsafeMutablePointer<AudioBufferList>, framesOut: UnsafeMutablePointer<CMItemCount>, flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>) in
                MTAudioProcessingTapGetSourceAudio(tap, frameCount, bufferList, flagsOut, nil, framesOut)
                let engine = Unmanaged<RealVisualizerEngine>
                    .fromOpaque(MTAudioProcessingTapGetStorage(tap))
                    .takeUnretainedValue()
                engine.processAudioBuffer(bufferList, frameCount: frameCount)
            }
        )

        var tapRef: Unmanaged<MTAudioProcessingTap>?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tapRef
        )

        guard status == noErr, let builtTap = tapRef?.takeRetainedValue() else {
            retainedSelf.release()
            return
        }
        tap = builtTap

        playerItem.asset.loadTracks(withMediaType: .audio) { [weak playerItem] tracks, _ in
            guard let track = tracks?.first, let item = playerItem else { return }
            let inputParams = AVMutableAudioMixInputParameters(track: track)
            inputParams.audioTapProcessor = builtTap
            let mix = AVMutableAudioMix()
            mix.inputParameters = [inputParams]
            DispatchQueue.main.async { item.audioMix = mix }
        }
    }

    func processAudioBuffer(_ bufferListPtr: UnsafeMutablePointer<AudioBufferList>, frameCount: CMItemCount) {
        guard frameCount > 0 else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        guard let first = buffers.first,
              let rawData = first.mData else { return }

        let samples = UnsafeBufferPointer<Float>(
            start: rawData.assumingMemoryBound(to: Float.self),
            count: Int(frameCount)
        )

        let n = min(fftSize, Int(frameCount))
        for i in 0..<n {
            realIn[i] = samples[i] * hannWindow[i]
        }
        for i in n..<fftSize { realIn[i] = 0 }
        for i in 0..<fftSize { imagIn[i] = 0 }

        guard let setup = fftSetup else { return }
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        let halfN = fftSize / 2
        var magnitudes = [Float](repeating: 0, count: halfN)
        for i in 0..<halfN {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        g_lock.lock()
        let displayCount = self.barCount
        let maxFreqIndex = min(halfN, Int(Float(n) * 8000.0 / 44100.0))
        let minFreqIndex = 1

        var newBins = [Float](repeating: 0, count: displayCount)
        if maxFreqIndex > minFreqIndex {
            let logMin = log10(Float(minFreqIndex))
            let logMax = log10(Float(maxFreqIndex))

            for i in 0..<displayCount {
                let currentLog = logMin + Float(i) * (logMax - logMin) / Float(displayCount - 1)
                let nextLog = logMin + Float(i + 1) * (logMax - logMin) / Float(displayCount - 1)

                let startIndex = min(maxFreqIndex - 1, max(minFreqIndex, Int(pow(10, currentLog))))
                var endIndex = min(maxFreqIndex, Int(pow(10, nextLog)))
                if endIndex <= startIndex { endIndex = startIndex + 1 }

                var sum: Float = 0
                for j in startIndex..<endIndex {
                    sum += magnitudes[j]
                }
                let avg = sum / Float(endIndex - startIndex)
                newBins[i] = avg
            }
        }

        for i in 0..<displayCount {
            let old = self.smoothed[i]
            let raw = newBins[i]
            let mapped = min(1.0, sqrt(raw) * 0.15)
            self.smoothed[i] = old * 0.8 + mapped * 0.2
            g_display_bins[i] = self.smoothed[i]
        }
        g_lock.unlock()
    }

    private func tick() {
        g_lock.lock()
        let bins = Array(g_display_bins.prefix(barCount))
        g_lock.unlock()
        onUpdate?(bins)
    }
}

class VisualizerView: NSView {
    var barCount: Int = 64
    var colorMode: String = "rainbow"
    var customColorHex: String = "#FF00FF"
    var transparency: Double = 0.6
    var maxHeight: Double = 0.5
    var minBarHeight: CGFloat = 4.0
    private var bins: [Float] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func updateBins(_ newBins: [Float]) {
        bins = newBins
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !bins.isEmpty else { return }

        let n = min(bins.count, barCount)
        let totalWidth = bounds.width
        let barWidth = (totalWidth / CGFloat(n)) * 0.7
        let gap = (totalWidth / CGFloat(n)) * 0.3
        let maxBarHeight = bounds.height * CGFloat(maxHeight)
        let alpha = CGFloat(transparency)

        for i in 0..<n {
            let x = CGFloat(i) * (barWidth + gap) + gap / 2
            let h = max(minBarHeight, CGFloat(bins[i]) * maxBarHeight)
            let rect = NSRect(x: x, y: 0, width: barWidth, height: h)

            let color: NSColor
            if colorMode == "rainbow" {
                let hue = CGFloat(i) / CGFloat(n)
                color = NSColor(hue: hue, saturation: 0.9, brightness: 0.95, alpha: alpha)
            } else {
                color = hexColor(customColorHex, alpha: alpha)
            }

            color.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            path.fill()
        }
    }

    private func hexColor(_ hex: String, alpha: CGFloat) -> NSColor {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt32(h, radix: 16) else {
            return NSColor(hue: 0.8, saturation: 0.9, brightness: 0.95, alpha: alpha)
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return NSColor(red: r, green: g, blue: b, alpha: alpha)
    }
}

let argc = CommandLine.arguments.count
guard argc >= 2 else {
    print("usage: glasswp <wallpaper_file>")
    exit(1)
}

let filePath = CommandLine.arguments[1]
guard FileManager.default.fileExists(atPath: filePath) else {
    print("error: file not found: \(filePath)")
    exit(1)
}

let ext = (filePath as NSString).pathExtension.lowercased()
let isStaticImage = ["jpg", "jpeg", "png", "gif"].contains(ext)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = GlasswpApp()
delegate.entryFilePath = filePath

if isStaticImage {
    app.delegate = delegate
    DispatchQueue.main.async {
        guard let screen = NSScreen.main else { return }
        let wnd = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        wnd.isOpaque = true
        wnd.backgroundColor = .black
        wnd.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        wnd.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        wnd.ignoresMouseEvents = true

        if let img = NSImage(contentsOfFile: filePath) {
            let iv = NSImageView(frame: screen.frame)
            iv.image = img
            iv.imageScaling = .scaleAxesIndependently
            iv.animates = true
            wnd.contentView?.addSubview(iv)
        }

        wnd.makeKeyAndOrderFront(nil)
    }
} else {
    app.delegate = delegate
}

app.run()