//
//  FontLoader.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI
import AppKit

enum font_loader {
    static func regFonts() {
        let logFile = URL(fileURLWithPath: "/tmp/macpaper-font.log")
        var logOutput = "Registering fonts...\n"
        
        let names = ["Comfortaa-Bold.ttf", "Comfortaa-Light.ttf", "Comfortaa-Regular.ttf"]
        let bundle = Bundle.main
        let resourceURL = bundle.resourceURL
        logOutput += "Bundle resource path: \(resourceURL?.path ?? "nil")\n"

        let candidates: [URL] = [
            resourceURL,
            URL(fileURLWithPath: bundle.bundlePath + "/Contents/Resources"),
            URL(fileURLWithPath: "/tmp/Resources")
        ].compactMap { $0 }

        for name in names {
            var found = false
            for dir in candidates {
                let url = dir.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path) {
                    logOutput += "Found font: \(name) at \(url.path)\n"
                    var error: Unmanaged<CFError>?
                    if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                        let errStr = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                        logOutput += "Failed to register \(name): \(errStr)\n"
                    } else {
                        logOutput += "Successfully registered \(name)\n"
                        found = true
                    }
                    break
                }
            }
            if !found {
                logOutput += "WARNING: Font \(name) not found in candidates.\n"
            }
        }
        
        try? logOutput.write(to: logFile, atomically: true, encoding: .utf8)
    }

    static func light(size: CGFloat) -> NSFont {
        NSFont(name: "Comfortaa-Light", size: size) ?? NSFont.systemFont(ofSize: size, weight: .light)
    }
    static func regular(size: CGFloat) -> NSFont {
        NSFont(name: "Comfortaa-Regular", size: size) ?? NSFont.systemFont(ofSize: size, weight: .regular)
    }
    static func bold(size: CGFloat) -> NSFont {
        NSFont(name: "Comfortaa-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
    }
}
