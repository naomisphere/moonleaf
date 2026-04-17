//
//  ManagerApp.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers

class MenuHandler: NSObject {
    weak var service: macpaperService?
    
    @objc func toggleVideos() {
        guard let service = service else { return }
        service.showVideos.toggle()
        service.fetch_wallpapers()
        print("toggle videos: \(service.showVideos)")
    }
    
    @objc func toggleImages() {
        guard let service = service else { return }
        service.showImages.toggle()
        service.fetch_wallpapers()
        print("toggle images: \(service.showImages)")
    }
}

struct ManagerView: View {
    @StateObject private var service = macpaperService()
    @State private var show_importer = false
    @State private var importingFolder = false
    @State private var showAddPopover = false
    @State private var file_drag = false
    @State private var show_wp_util_overlay = false
    @State private var overlay_chosen_wp: endup_wp? = nil
    @State private var showFavoritesOnly = false
    @State private var showSortDropdown = false
    @State private var showWpActionsDropdown = false
    private let menuHandler = MenuHandler()
    
        var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                toolbarView
                contentView
            }

            if show_wp_util_overlay, let wallpaper = overlay_chosen_wp {
                WPCUtilOverlay(
                    wallpaper: wallpaper,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            service.select_wp(nil)
                            show_wp_util_overlay = false
                            overlay_chosen_wp = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            service.fetch_wallpapers()
            menuHandler.service = service
        }
        .onChange(of: service.selected_wp) { selected in
            withAnimation(.easeInOut(duration: 0.3)) {
                show_wp_util_overlay = selected != nil
                overlay_chosen_wp = selected
            }
        }
        .fileImporter(
            isPresented: $show_importer,
            allowedContentTypes: importingFolder ? [.folder] : [.movie, .image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if importingFolder {
                        import_folder(from: url)
                    } else {
                        import_wp(from: url)
                    }
                }
            case .failure(let error):
                print("import error: \(error)")
            }
        }
    }
        private var toolbarView: some View {
        HStack(spacing: 12) {
            Button(action: { showAddPopover.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("add wallpaper")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(width: 175)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.47, blue: 0.85), Color(red: 0.32, green: 0.37, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showAddPopover, arrowEdge: .bottom) {
                VStack(spacing: 4) {
                    Button(action: {
                        importingFolder = false
                        showAddPopover = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            show_importer = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text("file")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.001)))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        importingFolder = true
                        showAddPopover = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            show_importer = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                            Text("folder")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.001)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .frame(width: 160)
            }

            Button(action: { show_settings() }) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                    Text(NSLocalizedString("mgr_settings", comment: "settings"))
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)

            Spacer()

            if service.current_wp != nil {
                Button(action: { showWpActionsDropdown.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13))
                        Text("Active Wallpaper")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(showWpActionsDropdown ? 0.15 : 0.05)))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showWpActionsDropdown, arrowEdge: .bottom) {
                    VStack(spacing: 4) {
                        if !isStillWallpaper(service.current_wp!) {
                            Button(action: { service.wp_doPersist(!service.wp_is_agent); showWpActionsDropdown = false }) {
                                HStack {
                                    Image(systemName: service.wp_is_agent ? "checkmark.circle.fill" : "circle")
                                    Text(NSLocalizedString("persist", comment: ""))
                                    Spacer()
                                }
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.001)))
                            }
                            .buttonStyle(.plain)
                        }
                        Button(action: { service.unset_wp(); showWpActionsDropdown = false }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                                Text(NSLocalizedString("unset_current", comment: ""))
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .frame(width: 170)
                }
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { showFavoritesOnly.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                    if showFavoritesOnly {
                        Text(NSLocalizedString("favorites_filter", comment: ""))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.regularMaterial.opacity(showFavoritesOnly ? 0.9 : 0.5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(showFavoritesOnly ? Color.yellow.opacity(0.4) : Color.primary.opacity(0.15), lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)

            Button(action: { showSortDropdown.toggle() }) {
                HStack(spacing: 6) {
                    Text(service.localSort.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(showSortDropdown ? 0.15 : 0.05)))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSortDropdown, arrowEdge: .bottom) {
                VStack(spacing: 4) {
                    ForEach(macpaperService.LocalSortMode.allCases, id: \.self) { mode in
                        Button(action: { service.setLocalSort(mode); showSortDropdown = false }) {
                            HStack {
                                Text(mode.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(service.localSort == mode ? .primary : .secondary)
                                Spacer()
                                if service.localSort == mode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(service.localSort == mode ? 0.08 : 0.001)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .frame(width: 160)
            }

            Button(action: { service.fetch_wallpapers() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .padding(10)
                    .frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.primary.opacity(0.1), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func show_settings() {
    let settingsView = SettingsView()
        .environmentObject(service)
    
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    if let managerWindow = NSApp.keyWindow {
        let managerFrame = managerWindow.frame
        let settingsSize = window.frame.size
        
        let x = managerFrame.midX - settingsSize.width / 2
        let y = managerFrame.midY - settingsSize.height / 2
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    } else {
        window.center()
    }
    
    window.title = "Settings"
    window.titleVisibility = .hidden
    window.contentView = NSHostingView(rootView: settingsView)
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

    private func showFilterMenu() {
    let menu = NSMenu()
    
    let filterHeader = NSMenuItem(
        title: NSLocalizedString("show_types", comment: "Show"),
        action: nil,
        keyEquivalent: ""
    )
    filterHeader.isEnabled = false
    menu.addItem(filterHeader)
    
    let videoItem = NSMenuItem(
        title: NSLocalizedString("show_videos", comment: "Videos"),
        action: #selector(MenuHandler.toggleVideos),
        keyEquivalent: ""
    )
    videoItem.target = menuHandler
    videoItem.state = service.showVideos ? .on : .off
    menu.addItem(videoItem)
    
    let imageItem = NSMenuItem(
        title: NSLocalizedString("show_images", comment: "Images"),
        action: #selector(MenuHandler.toggleImages),
        keyEquivalent: ""
    )
    imageItem.target = menuHandler
    imageItem.state = service.showImages ? .on : .off
    menu.addItem(imageItem)
    
    if let window = NSApp.keyWindow,
       let contentView = window.contentView {
        
        let filterButtonTitle = NSLocalizedString("filter", comment: "Filter")
        if let filterButton = findButton(with: filterButtonTitle, in: contentView) {
            let buttonFrame = filterButton.convert(filterButton.bounds, to: nil)
            let menuPosition = NSPoint(x: buttonFrame.minX, y: buttonFrame.maxY)
            menu.popUp(positioning: nil, at: menuPosition, in: nil)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }
}

private func findButton(with title: String, in view: NSView) -> NSButton? {
    for subview in view.subviews {
        if let button = subview as? NSButton, button.title == title {
            return button
        }
        if let foundButton = findButton(with: title, in: subview) {
            return foundButton
        }
    }
    return nil
}
    
    private var contentView: some View {
        VStack(spacing: 0) {
            if !service.isAtRoot {
                HStack {
                    Button(action: { service.back() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 32)
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
            
            ZStack {
                if service.isLoading {
                    loadingView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9)),
                            removal: .opacity.combined(with: .scale(scale: 1.1))
                        ))
                } else if service.wallpapers.isEmpty {
                    NoWpView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                } else {
                    gridView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: service.isLoading)
        .animation(.easeInOut(duration: 0.4), value: service.wallpapers.isEmpty)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Circle()
                            .stroke(.primary.opacity(0.1), lineWidth: 1)
                    }
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primary.opacity(0.7)))
                    .scaleEffect(1.2)
            }
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("loading_wallpapers", comment: "loading wallpapers"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                
                Text(NSLocalizedString("scanning_files", comment: "scanning for video files"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var NoWpView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.primary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("no_wallpapers_found", comment: "no wallpapers found"))
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                
                Text(NSLocalizedString("drop_files_or_add", comment: "drop files or add wallpaper"))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("supported_formats", comment: "supported file formats"))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .onDrop(of: [.fileURL, .directory], isTargeted: $file_drag) { providers in
            drop_handle(providers)
        }
    }
    
    private var gridView: some View {
        ScrollView {
            let columns = [
                GridItem(.fixed(300), spacing: 30),
                GridItem(.fixed(300), spacing: 30),
                GridItem(.fixed(300), spacing: 30)
            ]
            
            LazyVGrid(columns: columns, alignment: .center, spacing: 30) {
                let displayed = showFavoritesOnly
                    ? service.wallpapers.filter { service.isFavorite($0) }
                    : service.wallpapers
                ForEach(Array(displayed.enumerated()), id: \.element.id) { index, wallpaper in
                    WallpaperCard(
                        wallpaper: wallpaper,
                        isActive: service.current_wp == wallpaper.path,
                        cardIsSelected: service.selected_wp?.id == wallpaper.id,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.3)) { service.set_wp(wallpaper) }
                        },
                        onTap: {
                            if wallpaper.isFolder {
                                service.navigateTo(folder: wallpaper)
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if service.selected_wp?.id == wallpaper.id {
                                        service.select_wp(nil)
                                    } else {
                                        service.select_wp(wallpaper)
                                    }
                                }
                            }
                        },
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                delete_wp(wallpaper)
                                if service.selected_wp?.id == wallpaper.id { service.select_wp(nil) }
                            }
                        },
                        onRename: { rename_wp(wallpaper, to: $0) },
                        onExport: { export_wp(wallpaper) }
                    )
                    .environmentObject(service)
                    .frame(width: 300, height: 260)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8).combined(with: .offset(y: 20))),
                        removal: .opacity.combined(with: .scale(scale: 0.8))
                    ))
                    .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: service.wallpapers.count)
                }
            }
            .padding(32)
        }
        .onDrop(of: [.fileURL], isTargeted: $file_drag) { providers in
            drop_handle(providers)
        }
    }
    
    private func drop_handle(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    import_wp(from: url)
                }
            }
            return true
        }
        return false
    }
    
    private func import_wp(from url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ["mp4", "mov", "gif", "jpg", "jpeg", "png"].contains(ext) else { return }
        
        let wp_storage_dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/paper/wallpaper")
        
        do {
            try FileManager.default.createDirectory(at: wp_storage_dir, withIntermediateDirectories: true)
            let destination = wp_storage_dir.appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            
            if service.importMethod == .link {
                try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: url.resolvingSymlinksInPath())
            } else {
                try FileManager.default.copyItem(at: url, to: destination)
            }
            service.fetch_wallpapers()
        } catch { print(error) }
    }
    
    private func import_folder(from url: URL) {
        let wp_storage_dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/paper/wallpaper")
        
        do {
            try FileManager.default.createDirectory(at: wp_storage_dir, withIntermediateDirectories: true)
            let destination = wp_storage_dir.appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            
            if service.importMethod == .link {
                try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: url.resolvingSymlinksInPath())
            } else {
                try FileManager.default.copyItem(at: url, to: destination)
            }
            service.fetch_wallpapers()
        } catch { print(error) }
    }
    
    private func delete_wp(_ wallpaper: endup_wp) {
        do {
            try FileManager.default.removeItem(atPath: wallpaper.path)
            service.fetch_wallpapers()
        } catch {
            print("while deleting wallpaper: \(error)")
        }
    }
    
    private func rename_wp(_ wallpaper: endup_wp, to newName: String) {
        let fileURL = URL(fileURLWithPath: wallpaper.path)
        let directory = fileURL.deletingLastPathComponent()
        let fileExtension = fileURL.pathExtension
        let newFileName = "\(newName).\(fileExtension)"
        let newURL = directory.appendingPathComponent(newFileName)
        
        do {
            try FileManager.default.moveItem(at: fileURL, to: newURL)
            service.fetch_wallpapers()
        } catch {
            print("Error renaming file: \(error)")
        }
    }
    
    private func export_wp(_ wallpaper: endup_wp) {
        let sourceURL = URL(fileURLWithPath: wallpaper.path)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        
        let fileExtension = sourceURL.pathExtension.lowercased()
        let isImage = ["jpg", "jpeg", "png", "gif"].contains(fileExtension)
        
        if isImage {
            ExportManager.shared.showExportMenu(
                for: wallpaper,
            sourceURL: sourceURL,
                showCropEditor: { image, wp, url in
                    self.showCropEditorWindow(image: image, wallpaper: wp, sourceURL: url)
                }
            )
        } else {
            ExportManager.shared.exportOriginal(wallpaper: wallpaper, sourceURL: sourceURL)
        }
    }
    
    private func showCropEditorWindow(image: NSImage, wallpaper: endup_wp, sourceURL: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let cropView = CropEditorView(
            image: image,
            wallpaperName: wallpaper.name,
            onCrop: { [weak window] cropRect, targetSize in
                window?.close()
                ExportManager.shared.exportWithCrop(
                    wallpaper: wallpaper,
                    sourceURL: sourceURL,
                    cropRect: cropRect,
                    targetSize: targetSize
                )
            },
            onCancel: { [weak window] in
                window?.close()
            }
        )
        
        window.center()
        window.title = NSLocalizedString("crop_editor_title", comment: "Crop Image")
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: cropView)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func isStillWallpaper(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png"].contains(ext)
    }
}

struct videoPreview: View {
    let videoURL: URL
    @State private var thumbnail: NSImage?
    
    private static var thumbnailCache = NSCache<NSString, NSImage>()
    private static var loadingOperations = [String: Operation]()
    private static let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .utility
        return queue
    }()
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(Color.brown.opacity(0.3))
                    .overlay {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                            .scaleEffect(0.8)
                    }
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            cancelLoading()
        }
    }

    private func loadThumbnail() {
        let cacheKey = videoURL.path as NSString
        
        if let cachedThumbnail = Self.thumbnailCache.object(forKey: cacheKey) {
            self.thumbnail = cachedThumbnail
            return
        }
        
        cancelLoading()
        
        var operation: BlockOperation?
        
        operation = BlockOperation {
            if operation?.isCancelled ?? true { return }
            
            let asset = AVAsset(url: self.videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 300, height: 200)
            imageGenerator.requestedTimeToleranceAfter = .zero
            imageGenerator.requestedTimeToleranceBefore = .zero
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 60), actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                
                if operation?.isCancelled ?? true { return }
                
                Self.thumbnailCache.setObject(nsImage, forKey: cacheKey)
                
                DispatchQueue.main.async {
                    Self.loadingOperations.removeValue(forKey: self.videoURL.path)
                    if let op = operation, !op.isCancelled {
                        self.thumbnail = nsImage
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    Self.loadingOperations.removeValue(forKey: self.videoURL.path)
                }
            }
        }
        
        if let op = operation {
            Self.loadingOperations[videoURL.path] = op
            Self.operationQueue.addOperation(op)
        }
    }

    private func cancelLoading() {
        if let operation = Self.loadingOperations[videoURL.path] {
            operation.cancel()
            Self.loadingOperations.removeValue(forKey: videoURL.path)
        }
    }
}

struct SimpleButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        RippleButton(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isPrimary ? .primary : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial.opacity(isPrimary ? 0.9 : (isHovered ? 0.7 : 0.5)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.primary.opacity(isPrimary ? 0.3 : 0.2), lineWidth: 1)
                    }
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct VolumeSlider: View {
    @Binding var volume: Double
    let onVolumeChange: (Double) -> Void
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : (volume < 0.33 ? "speaker.fill" : (volume < 0.67 ? "speaker.wave.1.fill" : "speaker.wave.2.fill")))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
                .frame(width: 16)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.regularMaterial.opacity(0.6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [
                                Color.primary.opacity(0.8),
                                Color.primary.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * volume, height: 12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(isDragging ? 0.3 : 0.2))
                        }
                    
                    Circle()
                        .fill(.regularMaterial)
                        .overlay {
                            Circle()
                                .fill(.white.opacity(0.9))
                                .scaleEffect(0.7)
                        }
                        .overlay {
                            Circle()
                                .stroke(.primary.opacity(0.2), lineWidth: 1)
                        }
                        .frame(width: isDragging ? 18 : 16, height: isDragging ? 18 : 16)
                        .position(
                            x: max(8, min(geometry.size.width - 8, geometry.size.width * volume)),
                            y: geometry.size.height / 2
                        )
                        .scaleEffect(isHovered || isDragging ? 1.1 : 1.0)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isDragging = true
                                }
                            }
                            
                            let newVolume = max(0, min(1, value.location.x / geometry.size.width))
                            volume = newVolume
                            
                            let now = Date()
                            if now.timeIntervalSince(lastUpdateTime) > 0.02 {
                                lastUpdateTime = now
                                onVolumeChange(newVolume)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDragging = false
                            }
                            onVolumeChange(volume)
                        }
                )
            }
            .frame(width: 80, height: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.primary.opacity(0.2), lineWidth: 1)
                }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct WallpaperCard: View {
    let wallpaper: endup_wp
    let isActive: Bool
    let cardIsSelected: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onExport: () -> Void
    
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName = ""
    @FocusState private var isNameFocused: Bool
    @EnvironmentObject private var service: macpaperService
    
    private var isStillWallpaper: Bool {
        let ext = (wallpaper.path as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png"].contains(ext)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            previewSection
                .frame(maxWidth: .infinity)
            infoSection
                .frame(height: 50)
        }
        .frame(width: 300, height: 260)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.regularMaterial.opacity(0.8))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            cardIsSelected ? Color.blue.opacity(0.6) :
                            isActive ? Color.primary.opacity(0.4) : Color.primary.opacity(0.1), 
                            lineWidth: cardIsSelected ? 3 : (isActive ? 2 : 1)
                        )
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onTapGesture {
            onTap()
        }
        .onChange(of: isEditing) { editing in
            if editing {
                editedName = wallpaper.name
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isNameFocused = true
                }
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }

        private var previewSection: some View {
        ZStack {
            Rectangle()
                .fill(Color.brown.opacity(0.2))
            
            let ext = (wallpaper.path as NSString).pathExtension.lowercased()
            
            if wallpaper.isFolder {
                VStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            } else if ["gif", "jpg", "jpeg", "png"].contains(ext) {
                LazyImagePreview(path: wallpaper.path)
            } else if ["mp4", "mov"].contains(ext) {
                videoPreview(videoURL: URL(fileURLWithPath: wallpaper.path))
                    .clipped()
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                            .background {
                                Circle()
                                    .fill(.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
                    }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }
            
            if isHovered || isActive {
                overlayControls
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
            }
        }
        .frame(width: 276, height: 184)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isActive 
                        ? Color.primary.opacity(0.4)
                        : Color.primary.opacity(0.1), 
                    lineWidth: isActive ? 2 : 1
                )
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }

    private var overlayControls: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black.opacity(0.6),
                    .black.opacity(0.3),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack {
                HStack {
                    if isActive {
                        Circle()
                            .fill(.green.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .background {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 28, height: 28)
                            }
                    }

                    FavoriteButton(
                        isFavorite: service.isFavorite(wallpaper),
                        action: { service.toggleFavorite(wallpaper) }
                    )
                    
                    Spacer()
                    
                    if isActive && !isStillWallpaper {
                        VolumeSlider(
                            volume: $service.volume,
                            onVolumeChange: { newVolume in
                                service.chvol(newVolume)
                            }
                        )
                        .scaleEffect(0.85)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            isEditing = true
                        }) {
                            Circle()
                                .fill(.mint.opacity(0.9))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                .background {
                                    Circle()
                                        .fill(.regularMaterial)
                                        .frame(width: 28, height: 28)
                                }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onExport) {
                            Circle()
                                .fill(.blue.opacity(0.9))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                .background {
                                    Circle()
                                        .fill(.regularMaterial)
                                        .frame(width: 28, height: 28)
                                }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onDelete) {
                            Circle()
                                .fill(.red.opacity(0.9))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                .background {
                                    Circle()
                                        .fill(.regularMaterial)
                                        .frame(width: 28, height: 28)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Spacer()
                
                if !isActive {
                    SimpleButton(
                        title: NSLocalizedString("set_wallpaper", comment: "set wallpaper"),
                        icon: "wand.and.stars",
                        isPrimary: true,
                        action: onSelect
                    )
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(width: 276, height: 184)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                HStack(spacing: 4) {
                    TextField("", text: $editedName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.9))
                        .focused($isNameFocused)
                        .onSubmit {
                            saveName()
                        }
                    
                    Button(action: saveName) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        isEditing = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.1))
                )
            } else {
                Text(wallpaper.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(2)
            }
            
            HStack {
                let ext = (wallpaper.path as NSString).pathExtension.lowercased()
                
                let fileType = wallpaper.isFolder ? "folder" :
                            ["mp4", "mov"].contains(ext) ? "video" :
                            ext == "gif" ? "gif" :
                            ["jpg", "jpeg", "png"].contains(ext) ? "image" : "unknown"
                
                Text(fileType)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(Color.brown.opacity(0.3))
                    }
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: wallpaper.fileSize, countStyle: .file))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
    }
    
    private func saveName() {
        if !editedName.isEmpty && editedName != wallpaper.name {
            onRename(editedName)
        }
        isEditing = false
    }
}

struct LazyImagePreview: View {
    let path: String
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 276, maxHeight: 184)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.brown.opacity(0.3))
                    .onAppear {
                        loadThumbnail()
                    }
            }
        }
    }
    
    private func loadThumbnail() {
        if let cachedImage = ImageCache.shared.getImage(forKey: path) {
            self.image = cachedImage
            return
        }
        
        DispatchQueue.global(qos: .utility).async {
            if let fullImage = NSImage(contentsOfFile: self.path) {
                let targetSize = NSSize(width: 276, height: 184)
                let thumbnail = self.resizeImageToFill(fullImage, to: targetSize)
                
                ImageCache.shared.setImage(thumbnail, forKey: self.path)
                
                DispatchQueue.main.async {
                    self.image = thumbnail
                }
            }
        }
    }
    
    private func resizeImageToFill(_ image: NSImage, to size: NSSize) -> NSImage {
        let imageSize = image.size
        let widthRatio  = size.width / imageSize.width
        let heightRatio = size.height / imageSize.height
        
        let scaleRatio = max(widthRatio, heightRatio)
        
        let scaledSize = NSSize(
            width: imageSize.width * scaleRatio,
            height: imageSize.height * scaleRatio
        )
        
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        let drawingRect = NSRect(
            x: (size.width - scaledSize.width) / 2,
            y: (size.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        image.draw(in: drawingRect,
                  from: NSRect(origin: .zero, size: imageSize),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

struct WPCUtilOverlay: View {
    let wallpaper: endup_wp
    let onClose: () -> Void
    
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage? = nil
    
    var body: some View {
        HStack(spacing: 20) {
            Group {
                let ext = (wallpaper.path as NSString).pathExtension.lowercased()
                
                if ["gif", "jpg", "jpeg", "png"].contains(ext) {
                    LazyImagePreview(path: wallpaper.path)
                        .id(wallpaper.id)
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if ["mp4", "mov"].contains(ext) {
                    videoPreview(videoURL: URL(fileURLWithPath: wallpaper.path))
                        .id(wallpaper.id)
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .transition(.opacity)

            VStack(alignment: .leading, spacing: 4) {
                Text(wallpaper.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(ByteCountFormatter.string(fromByteCount: wallpaper.fileSize, countStyle: .file))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(.regularMaterial)
                            .overlay {
                                Circle()
                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(width: 300)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .padding(.bottom, 20)
        .transition(.opacity)
    }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 30
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    func getImage(forKey key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: NSImage, forKey key: String) {
        let cost = image.size.width * image.size.height * 4
        cache.setObject(image, forKey: key as NSString, cost: Int(cost))
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

struct CropEditorView: View {
    let image: NSImage
    let wallpaperName: String
    let onCrop: (CGRect, CGSize) -> Void
    let onCancel: () -> Void
    
    @State private var selectedRatioIndex: Int = 0
    @State private var imageSize: CGSize = .zero
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    
    struct RatioOption: Identifiable {
        let id: String
        let name: String
        let size: CGSize
        var aspectRatio: CGFloat { size.width / size.height }
    }
    
    private let ratios: [RatioOption] = [
        RatioOption(id: "iphone15promax", name: "iPhone 15 Pro Max", size: CGSize(width: 1290, height: 2796)),
        RatioOption(id: "iphone15pro", name: "iPhone 15 Pro", size: CGSize(width: 1179, height: 2556)),
        RatioOption(id: "iphone14pro", name: "iPhone 14 Pro", size: CGSize(width: 1179, height: 2556)),
        RatioOption(id: "iphone13pro", name: "iPhone 13 Pro", size: CGSize(width: 1170, height: 2532)),
        RatioOption(id: "iphonese", name: "iPhone SE", size: CGSize(width: 750, height: 1334)),
        RatioOption(id: "ipadpro12", name: "iPad Pro 12.9\"", size: CGSize(width: 2732, height: 2048)),
        RatioOption(id: "ipadpro11", name: "iPad Pro 11\"", size: CGSize(width: 2388, height: 1668)),
        RatioOption(id: "4k", name: "4K UHD (3840×2160)", size: CGSize(width: 3840, height: 2160)),
        RatioOption(id: "1440p", name: "1440p (2560×1440)", size: CGSize(width: 2560, height: 1440)),
        RatioOption(id: "1080p", name: "1080p (1920×1080)", size: CGSize(width: 1920, height: 1080)),
        RatioOption(id: "ultrawide", name: "Ultrawide 21:9", size: CGSize(width: 3440, height: 1440))
    ]
    
    private var selectedRatio: RatioOption { ratios[selectedRatioIndex] }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                headerView
                cropCanvas
                controlsView
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            ratioSidebar
                .frame(width: 220)
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            loadImageSize()
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("crop_editor_title", comment: "Crop Image"))
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var cropCanvas: some View {
        GeometryReader { geo in
            let canvasSize = geo.size
            let cropFrameSize = calculateCropFrameSize(in: canvasSize)
            let imageDisplaySize = calculateImageDisplaySize(for: cropFrameSize)
            let clampedOffset = clampOffset(imageSize: imageDisplaySize, cropSize: cropFrameSize)
            
            ZStack {
                Color(NSColor.darkGray).opacity(0.3)
                
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
                        .offset(clampedOffset)
                }
                .frame(width: cropFrameSize.width, height: cropFrameSize.height)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .overlay(cropGridOverlay(size: cropFrameSize))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newOffset = CGSize(
                                width: lastPanOffset.width + value.translation.width,
                                height: lastPanOffset.height + value.translation.height
                            )
                            panOffset = newOffset
                        }
                        .onEnded { _ in
                            lastPanOffset = clampOffset(imageSize: imageDisplaySize, cropSize: cropFrameSize)
                            panOffset = lastPanOffset
                        }
                )
                
                VStack {
                    Spacer()
                    HStack {
                        Text("\(Int(selectedRatio.size.width)) × \(Int(selectedRatio.size.height))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                    .padding(.bottom, 8)
                }
                .frame(width: cropFrameSize.width, height: cropFrameSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
    }
    
    private func cropGridOverlay(size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width / 3, y: 0))
                path.addLine(to: CGPoint(x: size.width / 3, y: size.height))
                path.move(to: CGPoint(x: size.width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: size.width * 2 / 3, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height / 3))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 3))
                path.move(to: CGPoint(x: 0, y: size.height * 2 / 3))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 2 / 3))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text(NSLocalizedString("crop_zoom", comment: "Zoom"))
                    .font(.system(size: 12))
                    .frame(width: 40, alignment: .leading)
                
                Slider(value: $zoomScale, in: 1.0...3.0, step: 0.1)
                    .frame(maxWidth: 300)
                
                Text(String(format: "%.1fx", zoomScale))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(width: 40)
                
                Button(action: resetCrop) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text(NSLocalizedString("browse_cancel", comment: "Cancel"))
                        .frame(width: 100)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
                
                Button(action: performCrop) {
                    Text(NSLocalizedString("crop_apply", comment: "Apply"))
                        .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var ratioSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("export_aspect_ratio", comment: "Aspect Ratio"))
                .font(.system(size: 13, weight: .semibold))
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader("iPhone")
                    ForEach(0..<5) { i in
                        ratioRow(index: i)
                    }
                    
                    sectionHeader("iPad")
                    ForEach(5..<7) { i in
                        ratioRow(index: i)
                    }
                    
                    sectionHeader("Desktop")
                    ForEach(7..<ratios.count) { i in
                        ratioRow(index: i)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
    
    private func ratioRow(index: Int) -> some View {
        let ratio = ratios[index]
        let isSelected = selectedRatioIndex == index
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedRatioIndex = index
                resetCrop()
            }
        }) {
            HStack {
                Text(ratio.name)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    private func loadImageSize() {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        }
    }
    
    private func calculateCropFrameSize(in canvasSize: CGSize) -> CGSize {
        let targetRatio = selectedRatio.aspectRatio
        let maxWidth = canvasSize.width * 0.85
        let maxHeight = canvasSize.height * 0.85
        
        var width: CGFloat
        var height: CGFloat
        
        if maxWidth / maxHeight > targetRatio {
            height = maxHeight
            width = height * targetRatio
        } else {
            width = maxWidth
            height = width / targetRatio
        }
        
        return CGSize(width: width, height: height)
    }
    
    private func calculateImageDisplaySize(for cropSize: CGSize) -> CGSize {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return cropSize
        }
        
        let imageRatio = imageSize.width / imageSize.height
        let cropRatio = cropSize.width / cropSize.height
        
        var baseWidth: CGFloat
        var baseHeight: CGFloat
        
        if imageRatio > cropRatio {
            baseHeight = cropSize.height
            baseWidth = baseHeight * imageRatio
        } else {
            baseWidth = cropSize.width
            baseHeight = baseWidth / imageRatio
        }
        
        return CGSize(width: baseWidth * zoomScale, height: baseHeight * zoomScale)
    }
    
    private func clampOffset(imageSize: CGSize, cropSize: CGSize) -> CGSize {
        let maxX = max(0, (imageSize.width - cropSize.width) / 2)
        let maxY = max(0, (imageSize.height - cropSize.height) / 2)
        
        return CGSize(
            width: min(maxX, max(-maxX, panOffset.width)),
            height: min(maxY, max(-maxY, panOffset.height))
        )
    }
    
    private func resetCrop() {
        panOffset = .zero
        lastPanOffset = .zero
        zoomScale = 1.0
    }
    
    private func performCrop() {
        guard imageSize.width > 0 && imageSize.height > 0 else { return }
        
        let targetRatio = selectedRatio.aspectRatio
        let imageRatio = imageSize.width / imageSize.height
        
        var baseCropWidth: CGFloat
        var baseCropHeight: CGFloat
        
        if imageRatio > targetRatio {
            baseCropHeight = imageSize.height
            baseCropWidth = baseCropHeight * targetRatio
        } else {
            baseCropWidth = imageSize.width
            baseCropHeight = baseCropWidth / targetRatio
        }
        
        let cropWidth = baseCropWidth / zoomScale
        let cropHeight = baseCropHeight / zoomScale
        
        let imageDisplaySize = CGSize(
            width: imageRatio > targetRatio ? imageSize.height * targetRatio * zoomScale : imageSize.width * zoomScale,
            height: imageRatio > targetRatio ? imageSize.height * zoomScale : imageSize.width / targetRatio * zoomScale
        )
        
        let normalizedOffsetX = -panOffset.width / imageDisplaySize.width
        let normalizedOffsetY = -panOffset.height / imageDisplaySize.height
        
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        
        let cropCenterX = centerX + normalizedOffsetX * imageSize.width
        let cropCenterY = centerY + normalizedOffsetY * imageSize.height
        
        var cropX = cropCenterX - cropWidth / 2
        var cropY = cropCenterY - cropHeight / 2
        
        cropX = max(0, min(imageSize.width - cropWidth, cropX))
        cropY = max(0, min(imageSize.height - cropHeight, cropY))
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        onCrop(cropRect, selectedRatio.size)
    }
}


class ExportManager: NSObject {
    static let shared = ExportManager()
    
    private var currentWallpaper: endup_wp?
    private var currentSourceURL: URL?
    private var onShowCropEditor: ((NSImage, endup_wp, URL) -> Void)?
    
    private let exportFolderFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/macpaper/export_folder")
    
    private override init() {
        super.init()
    }
    
    private func getExportFolder() -> URL {
        if FileManager.default.fileExists(atPath: exportFolderFile.path) {
            do {
                let path = try String(contentsOf: exportFolderFile).trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
            } catch {}
        }
        
        if let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            return picturesURL
        }
        
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    func showExportMenu(
        for wallpaper: endup_wp,
        sourceURL: URL,
        showCropEditor: @escaping (NSImage, endup_wp, URL) -> Void
    ) {
        self.currentWallpaper = wallpaper
        self.currentSourceURL = sourceURL
        self.onShowCropEditor = showCropEditor
        
        let menu = NSMenu()
        
        let originalItem = NSMenuItem(
            title: NSLocalizedString("export_original", comment: "Original Size"),
            action: #selector(handleExportOriginal),
            keyEquivalent: ""
        )
        originalItem.target = self
        menu.addItem(originalItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let customItem = NSMenuItem(
            title: NSLocalizedString("download_custom_ratio", comment: "Custom Aspect Ratio"),
            action: #selector(handleExportCustom),
            keyEquivalent: ""
        )
        customItem.target = self
        menu.addItem(customItem)
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func handleExportOriginal() {
        guard let wallpaper = currentWallpaper, let sourceURL = currentSourceURL else { return }
        exportOriginal(wallpaper: wallpaper, sourceURL: sourceURL)
    }
    
    @objc private func handleExportCustom() {
        guard let wallpaper = currentWallpaper,
              let sourceURL = currentSourceURL,
              let showCropEditor = onShowCropEditor,
              let image = NSImage(contentsOfFile: sourceURL.path) else { return }
        showCropEditor(image, wallpaper, sourceURL)
    }
    
    func exportOriginal(wallpaper: endup_wp, sourceURL: URL) {
        let fileExtension = sourceURL.pathExtension.lowercased()
        var allowedTypes: [UTType] = []
        
        switch fileExtension {
        case "jpg", "jpeg": allowedTypes = [.jpeg]
        case "png": allowedTypes = [.png]
        case "gif": allowedTypes = [.gif]
        case "mp4": allowedTypes = [.mpeg4Movie]
        case "mov": allowedTypes = [.quickTimeMovie]
        default: allowedTypes = [.jpeg, .png, .gif, .mpeg4Movie, .quickTimeMovie]
        }
        
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = allowedTypes
        savePanel.nameFieldStringValue = wallpaper.name
        savePanel.title = NSLocalizedString("export_wallpaper", comment: "Export Wallpaper")
        savePanel.directoryURL = getExportFolder()
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                } catch {
                    self.showError(error.localizedDescription)
                }
            }
            
            if previousPolicy == .accessory && NSApp.windows.filter({ $0.isVisible }).isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    func exportWithCrop(wallpaper: endup_wp, sourceURL: URL, cropRect: CGRect, targetSize: NSSize) {
        guard let sourceImage = NSImage(contentsOfFile: sourceURL.path) else { return }
        
        let croppedImage = cropImage(sourceImage, cropRect: cropRect, targetSize: targetSize)
        
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "\(wallpaper.name)_\(Int(targetSize.width))x\(Int(targetSize.height))"
        savePanel.title = NSLocalizedString("export_wallpaper", comment: "Export Wallpaper")
        savePanel.directoryURL = getExportFolder()
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                self.saveCroppedImage(croppedImage, to: destinationURL)
            }
            
            if previousPolicy == .accessory && NSApp.windows.filter({ $0.isVisible }).isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    private func cropImage(_ image: NSImage, cropRect: CGRect, targetSize: NSSize) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let croppedCGImage = cgImage.cropping(to: cropRect),
              let context = CGContext(
                  data: nil,
                  width: Int(targetSize.width),
                  height: Int(targetSize.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }
        
        context.interpolationQuality = .high
        context.draw(croppedCGImage, in: CGRect(origin: .zero, size: targetSize))
        
        guard let finalCGImage = context.makeImage() else { return image }
        return NSImage(cgImage: finalCGImage, size: targetSize)
    }
    
    private func saveCroppedImage(_ image: NSImage, to destinationURL: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            showError("Could not convert image")
            return
        }
        
        let fileExtension = destinationURL.pathExtension.lowercased()
        let imageData = fileExtension == "png"
            ? bitmapImage.representation(using: .png, properties: [:])
            : bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.95])
        
        guard let data = imageData else {
            showError("Could not create image data")
            return
        }
        
        do {
            try data.write(to: destinationURL)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("export_error", comment: "Export Error")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}