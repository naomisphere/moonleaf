//
//  ContentView.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: TabSelection = .wallpapers
    @State private var version_label_alpha: Double = 0.6
    @AppStorage("glassBackground") private var glassBackground = false

    private func app_version() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "unknown"
    }

    enum TabSelection: CaseIterable {
        case wallpapers
        case browse

        var title: String {
            switch self {
            case .wallpapers: return NSLocalizedString("mgr_wp_title", comment: "wallpapers")
            case .browse: return NSLocalizedString("mgr_browse_title", comment: "browse")
            }
        }

        var icon: String {
            switch self {
            case .wallpapers: return "photo.on.rectangle"
            case .browse: return "globe"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    HStack(spacing: 12) {
                        HStack(spacing: 12) {
                            if let ml_logo = NSImage(named: ".moonleaf_logo") {
                                Image(nsImage: ml_logo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 42, height: 42)
                            }
                        }

                        Text(NSLocalizedString("mgr_title", comment: "moonleaf"))
                            .font(Font(font_loader.bold(size: 28)))
                            .foregroundStyle(.primary.opacity(0.9))

                        Text(app_version())
                            .font(Font(font_loader.regular(size: 12)))
                            .foregroundStyle(.secondary.opacity(version_label_alpha))
                            .padding(.leading, 4)
                            .padding(.top, 4)
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: {
                            if let url = URL(string: "https://ko-fi.com/naomisphere") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            if let kofi_cup = NSImage(named: ".kofi") {
                                Image(nsImage: kofi_cup)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .frame(width: 36, height: 36)
                                    .background {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.regularMaterial.opacity(0.6))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(.primary.opacity(0.2), lineWidth: 1)
                                            }
                                    }
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(TabSelection.allCases, id: \.self) { tab in
                            tabButton(
                                title: tab.title,
                                icon: tab.icon,
                                isSelected: selectedTab == tab,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.3)) { selectedTab = tab }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(bg(useGlass: glassBackground))
                .padding(.horizontal, 16)

                ZStack {
                    Group {
                        switch selectedTab {
                        case .wallpapers:
                            ManagerView()
                        case .browse:
                            BrowseView()
                        }
                    }
                    .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .focusable(false)
        }
    }
}

struct tabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        RippleButton(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(Font(font_loader.regular(size: 14)))
                Text(title)
                    .font(Font(font_loader.regular(size: 14)))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                        }
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary.opacity(0.3))
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) { isHovered = hovering }
        }
    }
}

struct bg: View {
    var useGlass: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(useGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial))
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.75, green: 0.85, blue: 1.0).opacity(0.12))
                
            VStack(spacing: 0) {
                Spacer()
                AnimatedWaveView()
                    .frame(height: 75)
                    .opacity(0.9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            RoundedRectangle(cornerRadius: 20)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        }
    }
}

struct GPUWave: View {
    var amplitude: CGFloat
    var frequency: CGFloat
    var duration: Double
    var color: Color
    var lineWidth: CGFloat
    var reverse: Bool
    var isFilled: Bool = false
    
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let path = makePath(width: w, height: geo.size.height)
            
            Group {
                if isFilled {
                    path.fill(color)
                } else {
                    path.stroke(color, lineWidth: lineWidth)
                }
            }
            .offset(x: isAnimating ? (reverse ? w : -w) : 0)
            .offset(x: reverse ? -w : 0)
            .frame(width: w * 2, alignment: .leading)
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
        }
    }
    
    func makePath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let mid = isFilled ? 0 : height / 2
        let step: CGFloat = 5
        let totalWidth = width * 2 
        
        if isFilled { path.move(to: CGPoint(x: 0, y: height)) }
        path.addLine(to: CGPoint(x: 0, y: mid))
        
        for x in stride(from: step, through: totalWidth + step, by: step) {
            let relativeX = x / width
            let sine = sin(relativeX * frequency * .pi * 2)
            path.addLine(to: CGPoint(x: x, y: mid + sine * amplitude))
        }
        
        if isFilled {
            path.addLine(to: CGPoint(x: totalWidth + step, y: height))
            path.closeSubpath()
        }
        return path
    }
}

struct AnimatedWaveView: View {
    var body: some View {
        ZStack {
            GPUWave(amplitude: 15, frequency: 1, duration: 8.0, color: Color(red: 137/255, green: 156/255, blue: 232/255).opacity(0.20), lineWidth: 0, reverse: false, isFilled: true)
                .padding(.top, 15)
            GPUWave(amplitude: 10, frequency: 2, duration: 5.5, color: Color(red: 137/255, green: 156/255, blue: 232/255).opacity(0.35), lineWidth: 0, reverse: true, isFilled: true)
                .padding(.top, 30)

            GPUWave(amplitude: 14, frequency: 1, duration: 7.0, color: Color(red: 137/255, green: 156/255, blue: 232/255).opacity(0.5), lineWidth: 2.5, reverse: false)
            GPUWave(amplitude: 8, frequency: 2, duration: 4.5, color: Color(red: 137/255, green: 156/255, blue: 232/255).opacity(0.6), lineWidth: 1.5, reverse: true)
        }
    }
}
