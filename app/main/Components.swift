//
//  Components.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI

struct RippleButton<Label: View>: View {
    var cornerRadius: CGFloat = 14
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @AppStorage("enableRipple") private var enableRipple = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                label()

                if enableRipple {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                        .frame(width: 80, height: 80)
                        .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { if enableRipple { fire() } else { action() } }
    }

    private func fire() {
        rippleScale = 0
        rippleOpacity = 0.7
        withAnimation(.easeOut(duration: 0.45)) {
            rippleScale = 2.2
            rippleOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action() }
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var bounce = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounce.toggle() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bounce = false }
            }
            action()
        }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(Font(font_loader.bold(size: 14)))
                .foregroundStyle(isFavorite ? .yellow : .white)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .scaleEffect(bounce ? 1.4 : (isHovered ? 1.15 : 1.0))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.black.opacity(isFavorite ? 0.6 : 0.35))
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering } }
    }
}
