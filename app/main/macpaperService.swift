//
//  macpaperService.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import Foundation
import Combine
import AppKit

class macpaperService: NSObject, ObservableObject {
    @Published var wallpapers: [endup_wp] = []
    @Published var isLoading = false
    @Published var current_wp: String?
    @Published var volume: Double = 0.5
    @Published var wp_is_agent: Bool = false
    @Published var ap_is_enabled: Bool = false
    @Published var showVideos: Bool = true
    @Published var showImages: Bool = true
    @Published var selected_wp: endup_wp? = nil
    @Published var favorites: Set<String> = []
    @Published var localSort: LocalSortMode = .date
    @Published var shuffleEnabled: Bool = false
    @Published var shuffleInterval: ShuffleInterval = .oneHour
    @Published var importMethod: ImportMethod = .link
    @Published var currentPath: URL?
    @Published var navStack: [URL] = []

    var isAtRoot: Bool {
        return navStack.isEmpty
    }

    private let wrapped_obj: String
    private let wp_storage_dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/paper/wallpaper")
    private let settings_file = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/moonleaf/settings.json")
    private let export_folder_file = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/moonleaf/export_folder")
    private var shuffleTimer: DispatchSourceTimer?

    enum LocalSortMode: String, CaseIterable {
        case date = "date"
        case name = "name"
        case size = "size"

        var displayName: String {
            switch self {
            case .date: return NSLocalizedString("sort_by_date", comment: "Date Added")
            case .name: return NSLocalizedString("sort_by_name", comment: "Name")
            case .size: return NSLocalizedString("sort_by_size", comment: "File Size")
            }
        }
    }

    enum ShuffleInterval: String, CaseIterable {
        case fifteenMin = "15min"
        case oneHour = "1hr"
        case threeHour = "3hr"
        case daily = "daily"

        var displayName: String {
            switch self {
            case .fifteenMin: return NSLocalizedString("shuffle_interval_15min", comment: "15 minutes")
            case .oneHour: return NSLocalizedString("shuffle_interval_1hr", comment: "1 hour")
            case .threeHour: return NSLocalizedString("shuffle_interval_3hr", comment: "3 hours")
            case .daily: return NSLocalizedString("shuffle_interval_daily", comment: "Daily")
            }
        }

        var seconds: Double {
            switch self {
            case .fifteenMin: return 15 * 60
            case .oneHour: return 60 * 60
            case .threeHour: return 3 * 60 * 60
            case .daily: return 24 * 60 * 60
            }
        }
    }

    enum ImportMethod: String, CaseIterable {
        case copy = "copy"
        case link = "link"
    }

    override init() {
        let app_path = Bundle.main.bundlePath
        wrapped_obj = "\(app_path)/Contents/MacOS/macpaper-bin"
        super.init()
        syncConfigs()
        loadSettings()
        loadVolume()
        if shuffleEnabled {
            startShuffleTimer()
        }
    }

    deinit {
        shuffleTimer?.cancel()
    }

    func select_wp(_ wallpaper: endup_wp?) {
        selected_wp = wallpaper
    }

    func toggleFavorite(_ wallpaper: endup_wp) {
        if favorites.contains(wallpaper.path) {
            favorites.remove(wallpaper.path)
        } else {
            favorites.insert(wallpaper.path)
        }
        saveFavorites()
    }

    func isFavorite(_ wallpaper: endup_wp) -> Bool {
        return favorites.contains(wallpaper.path)
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "moonleaf_favorites"),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            favorites = Set(paths)
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(Array(favorites)) {
            UserDefaults.standard.set(data, forKey: "moonleaf_favorites")
        }
    }

    func setLocalSort(_ mode: LocalSortMode) {
        localSort = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "moonleaf_localSort")
        applyLocalSort()
    }

    private func applyLocalSort() {
        switch localSort {
        case .date:
            wallpapers = wallpapers.sorted { $0.createdDate > $1.createdDate }
        case .name:
            wallpapers = wallpapers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            wallpapers = wallpapers.sorted { $0.fileSize > $1.fileSize }
        }
    }

    func setShuffleEnabled(_ enabled: Bool) {
        shuffleEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "moonleaf_shuffleEnabled")
        if enabled {
            startShuffleTimer()
        } else {
            shuffleTimer?.cancel()
            shuffleTimer = nil
        }
    }

    func setShuffleInterval(_ interval: ShuffleInterval) {
        shuffleInterval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: "moonleaf_shuffleInterval")
        if shuffleEnabled {
            startShuffleTimer()
        }
    }

    private func startShuffleTimer() {
        shuffleTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + shuffleInterval.seconds, repeating: shuffleInterval.seconds)
        timer.setEventHandler { [weak self] in
            self?.shuffleToNext()
        }
        timer.resume()
        shuffleTimer = timer
    }

    private func shuffleToNext() {
        guard !wallpapers.isEmpty else { return }
        let randomWallpaper = wallpapers.randomElement()!
        DispatchQueue.main.async {
            self.set_wp(randomWallpaper)
        }
    }

    func _ap_enabled(_ enabled: Bool) {
        ap_is_enabled = enabled
        saveSettings()

        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.naomisphere.moonleaf.autoPauseChanged"),
            object: nil,
            userInfo: ["ap_is_enabled": enabled],
            deliverImmediately: true
        )
    }

    private func loadSettings() {
        do {
            if FileManager.default.fileExists(atPath: settings_file.path) {
                let data = try Data(contentsOf: settings_file)
                if let settings = try? JSONDecoder().decode([String: String].self, from: data) {
                    ap_is_enabled = (settings["ap_is_enabled"] == "true")
                    showVideos = (settings["showVideos"] ?? "true") == "true"
                    showImages = (settings["showImages"] ?? "true") == "true"
                    if let methodRaw = settings["import_method"], let method = ImportMethod(rawValue: methodRaw) {
                        importMethod = method
                    }
                }
            }
        } catch {}

        currentPath = wp_storage_dir

        loadFavorites()

        if let sortRaw = UserDefaults.standard.string(forKey: "moonleaf_localSort"),
           let sort = LocalSortMode(rawValue: sortRaw) {
            localSort = sort
        }

        shuffleEnabled = UserDefaults.standard.bool(forKey: "moonleaf_shuffleEnabled")

        if let intervalRaw = UserDefaults.standard.string(forKey: "moonleaf_shuffleInterval"),
           let interval = ShuffleInterval(rawValue: intervalRaw) {
            shuffleInterval = interval
        }
    }

    private func loadVolume() {
        let volFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/moonleaf/volume")
        if let data = try? Data(contentsOf: volFile),
           let str = String(data: data, encoding: .utf8),
           let intVal = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            volume = Double(max(0, min(100, intVal))) / 100.0
        }
    }

    func saveSettings() {
        do {
            let settings: [String: String] = [
                "ap_is_enabled": ap_is_enabled ? "true" : "false",
                "showVideos": showVideos ? "true" : "false",
                "showImages": showImages ? "true" : "false",
                "import_method": importMethod.rawValue
            ]
            let data = try JSONEncoder().encode(settings)
            try FileManager.default.createDirectory(
                at: settings_file.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: settings_file)
        } catch {}
    }

    func chvol(_ new_vol: Double) {
        volume = new_vol
        let volumeFloat = Float(new_vol)

        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.naomisphere.moonleaf.volumeChanged"),
            object: nil,
            userInfo: ["volume": volumeFloat],
            deliverImmediately: true
        )

        let vol_in_percentage = Int(new_vol * 100)
        _exec([wrapped_obj, "--volume", "\(vol_in_percentage)"]) { _ in }
    }

    func fetch_wallpapers() {
        isLoading = true

        try? FileManager.default.createDirectory(at: wp_storage_dir, withIntermediateDirectories: true)

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let scanPath = (self.currentPath ?? self.wp_storage_dir).resolvingSymlinksInPath()
                let files = try FileManager.default.contentsOfDirectory(
                    at: scanPath,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey])

                let validExts = ["mov", "mp4", "gif", "jpg", "jpeg", "png"]
                let possible_wp_obj = files.filter { url in
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                        if isDir.boolValue { return true }
                    }
                    return validExts.contains(url.pathExtension.lowercased())
                }

                let items = possible_wp_obj.compactMap { url -> endup_wp? in
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    let isFolder = isDir.boolValue
                    
                    let rv = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])

                    let modDate: Date
                    if let d = rv?.contentModificationDate {
                        modDate = d
                    } else if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                              let d = attrs[.modificationDate] as? Date {
                        modDate = d
                    } else {
                        modDate = Date.distantPast
                    }

                    let fileSize: Int64
                    if let sz = rv?.fileSize {
                        fileSize = Int64(sz)
                    } else if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                              let sz = attrs[.size] as? Int64 {
                        fileSize = sz
                    } else {
                        fileSize = 0
                    }

                    return endup_wp(
                        id: UUID(),
                        name: url.deletingPathExtension().lastPathComponent,
                        path: url.path,
                        preview: nil,
                        createdDate: modDate,
                        fileSize: fileSize,
                        isFolder: isFolder
                    )
                }

                DispatchQueue.main.async {
                    var filtered = items

                    if !self.showVideos {
                        filtered = filtered.filter { !["mov", "mp4", "gif"].contains(($0.path as NSString).pathExtension.lowercased()) }
                    }

                    if !self.showImages {
                        filtered = filtered.filter { $0.isFolder || !["jpg", "jpeg", "png"].contains(($0.path as NSString).pathExtension.lowercased()) }
                    }

                    self.wallpapers = filtered
                    self.applyLocalSort()
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }

    func set_still_wp(_ wallpaper: endup_wp) {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        let script = """
        tell application "System Events"
            tell every desktop
                set picture to POSIX file "\(wallpaper.path)"
            end tell
        end tell
        """
        task.arguments = ["-e", script]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let current_wp_file = home.appendingPathComponent(".local/share/macpaper/current_wallpaper")
                try? FileManager.default.createDirectory(
                    at: current_wp_file.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try? wallpaper.path.write(to: current_wp_file, atomically: true, encoding: .utf8)
                DispatchQueue.main.async { self.current_wp = wallpaper.path }
            }
        } catch {}
    }

    func set_wp(_ wallpaper: endup_wp) {
        let ext = (wallpaper.path as NSString).pathExtension.lowercased()
        let isMoving = ["mov", "mp4", "gif"].contains(ext)
        let isStill = ["jpg", "jpeg", "png"].contains(ext)

        guard isMoving || isStill else { return }

        DispatchQueue.main.async { self.selected_wp = wallpaper }

        copyWallpaperForScreensaver(wallpaper)

        if current_wp != nil {
            _unset_wp { [weak self] in
                if isMoving { self?.set_wp_after_unset(wallpaper) }
                else { self?.set_still_wp(wallpaper) }
            }
        } else {
            if isMoving { set_wp_after_unset(wallpaper) }
            else { set_still_wp(wallpaper) }
        }
    }

    private func copyWallpaperForScreensaver(_ wallpaper: endup_wp) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let screensaverDir = home.appendingPathComponent("Library/Application Support/macpaper")
        let fileExtension = (wallpaper.path as NSString).pathExtension
        let destURL = screensaverDir.appendingPathComponent("current_screensaver_wallpaper.\(fileExtension)")

        do {
            try FileManager.default.createDirectory(at: screensaverDir, withIntermediateDirectories: true)
            let oldFiles = try? FileManager.default.contentsOfDirectory(at: screensaverDir, includingPropertiesForKeys: nil)
            oldFiles?.filter { $0.deletingPathExtension().lastPathComponent == "current_screensaver_wallpaper" }.forEach {
                try? FileManager.default.removeItem(at: $0)
            }
            try FileManager.default.copyItem(atPath: wallpaper.path, toPath: destURL.path)
        } catch {}
    }

    private func set_wp_after_unset(_ wallpaper: endup_wp) {
        _exec([wrapped_obj, "--set", wallpaper.path]) { [weak self] success in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.current_wp = wallpaper.path
                }
            } else {
                self?.current_wp = nil
            }
        }
    }

    private func _unset_wp(completion: @escaping () -> Void) {
        DispatchQueue.main.async { self.selected_wp = nil }
        current_wp = nil
        wp_is_agent = false
        _exec([wrapped_obj, "--unset"]) { [weak self] success in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }
    }

    func unset_wp() {
        selected_wp = nil
        _unset_wp {}
    }

    func wp_doPersist(_ enabled: Bool) {
        wp_is_agent = enabled

        if enabled {
            _exec([wrapped_obj, "--persist"]) { [weak self] success in
                DispatchQueue.main.async { self?.wp_is_agent = success }
            }
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let launchAgent = home.appendingPathComponent("Library/LaunchAgents/com.naomisphere.macpaper.wallpaper.plist")
            let unload = Process()
            unload.launchPath = "/bin/launchctl"
            unload.arguments = ["unload", launchAgent.path]
            try? unload.run()
            unload.waitUntilExit()
            try? FileManager.default.removeItem(at: launchAgent)
            DispatchQueue.main.async { self.wp_is_agent = false }
        }
    }

    func getExportFolder() -> URL {
        if FileManager.default.fileExists(atPath: export_folder_file.path),
           let path = try? String(contentsOf: export_folder_file).trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
    }

    func get_wp_storage_dir() -> URL {
        return wp_storage_dir
    }

    private func _exec(_ arguments: [String], completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.launchPath = arguments[0]
            task.arguments = Array(arguments.dropFirst())
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.launch()
            task.waitUntilExit()
            DispatchQueue.main.async { completion(task.terminationStatus == 0) }
        }
    }

    func installScreensaver() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let destFolder = home.appendingPathComponent("Library/Screen Savers")
        let destURL = destFolder.appendingPathComponent("macpaperSaver.saver")

        guard let saverPath = Bundle.main.path(forResource: "macpaperSaver", ofType: "saver") else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(atPath: saverPath, toPath: destURL.path)

            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: "useAsScreensaver")
                if let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings") {
                    NSWorkspace.shared.open(url)
                }
            }
        } catch {
            DispatchQueue.main.async {
                UserDefaults.standard.set(false, forKey: "useAsScreensaver")
            }
        }
    }

    func uninstallScreensaver() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let saverURL = home.appendingPathComponent("Library/Screen Savers/macpaperSaver.saver")
        if FileManager.default.fileExists(atPath: saverURL.path) {
            try? FileManager.default.removeItem(at: saverURL)
            DispatchQueue.main.async {
                UserDefaults.standard.set(false, forKey: "useAsScreensaver")
            }
        }
    }

    func checkScreensaverStatus() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let saverURL = home.appendingPathComponent("Library/Screen Savers/macpaperSaver.saver")
        DispatchQueue.main.async {
            UserDefaults.standard.set(
                FileManager.default.fileExists(atPath: saverURL.path),
                forKey: "useAsScreensaver")
        }
    }
    func back() {
        guard !navStack.isEmpty else { return }
        currentPath = navStack.removeLast()
        fetch_wallpapers()
    }

    func navigateTo(folder: endup_wp) {
        guard folder.isFolder else { return }
        if let current = currentPath {
            navStack.append(current)
        }
        currentPath = URL(fileURLWithPath: folder.path)
        fetch_wallpapers()
    }

    private func syncConfigs() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let legacyDir = home.appendingPathComponent(".local/share/macpaper")
        let newDir = home.appendingPathComponent(".config/moonleaf")
        
        guard FileManager.default.fileExists(atPath: legacyDir.path) else { return }
        try? FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
        
        if let files = try? FileManager.default.contentsOfDirectory(at: legacyDir, includingPropertiesForKeys: nil) {
            for file in files {
                let dest = newDir.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try? FileManager.default.createSymbolicLink(at: dest, withDestinationURL: file)
                }
            }
        }
    }
}

struct endup_wp: Identifiable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let preview: String?
    let createdDate: Date
    let fileSize: Int64
    var isFolder: Bool = false
}