//
//  Updater.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import Foundation
import Combine
import AppKit

class Updater: ObservableObject {
    @Published var updateAvailable = false
    @Published var isUpdating = false
    @Published var updateError: String?
    @Published var latestVersion: String?
    @Published var changelog: String?

    private var baseUrl: String {
        let defaultUrl = "https://raw.githubusercontent.com/naomisphere/moonleaf/main"
        let serverFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/macpaper/update_server")
        
        if FileManager.default.fileExists(atPath: serverFile.path),
           let server = try? String(contentsOf: serverFile) {
            let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("github.com/naomisphere/") {
                let repoPath = trimmed.replacingOccurrences(of: "github.com/", with: "")
                return "https://raw.githubusercontent.com/\(repoPath)/main"
            }
        }
        return defaultUrl
    }

    private var apiBaseUrl: String {
        let defaultUrl = "https://api.github.com/repos/naomisphere/moonleaf"
        let serverFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/macpaper/update_server")
        
        if FileManager.default.fileExists(atPath: serverFile.path),
           let server = try? String(contentsOf: serverFile) {
            let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("github.com/naomisphere/") {
                let repoPath = trimmed.replacingOccurrences(of: "github.com/", with: "")
                return "https://api.github.com/repos/\(repoPath)"
            }
        }
        return defaultUrl
    }

    private var latestVersionURL: URL { URL(string: "\(baseUrl)/latest")! }
    private var changelogURL: URL { URL(string: "\(apiBaseUrl)/releases/latest")! }

    func checkForUpdates() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return }

        URLSession.shared.dataTask(with: latestVersionURL) { data, _, error in
            if let error = error {
                print("updater failed: \(error)")
                return
            }
            guard let data = data,
                  let latestVersion = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

            DispatchQueue.main.async {
                self.latestVersion = latestVersion
                self.updateAvailable = self.v(latestVersion, newerThan: currentVersion)
                if self.updateAvailable {
                    self.showUpdatePrompt()
                }
            }
        }.resume()
    }

    func fetchChangelog(completion: @escaping (String?) -> Void) {
        var req = URLRequest(url: changelogURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let body = json["body"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async {
                self.changelog = body
                completion(body)
            }
        }.resume()
    }

    private func showUpdatePrompt() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Update Available"
            alert.informativeText = "A new version (\(self.latestVersion ?? "latest")) is available. Would you like to update now?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Update")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                self.do_update()
            }
        }
    }

    private let updaterScriptContent = """
#!/bin/bash

SERVER_URL="${3:-https://github.com/naomisphere/moonleaf}"
REPO=$(echo "$SERVER_URL" | sed 's|https://github.com/||')
RAW_URL="https://raw.githubusercontent.com/$REPO/main/latest"

LATEST=$(curl -s "$RAW_URL")
CURRENT="$1"

if [ "$LATEST" != "$CURRENT" ]; then
    C_TMPDIR="$2/.tmp"
    mkdir -p "$C_TMPDIR"

    LATEST_URL="$SERVER_URL/releases/download/$LATEST/moonleaf.dmg"
    DMG_PATH="$C_TMPDIR/moonleaf.dmg"

    curl -L -o "$DMG_PATH" "$LATEST_URL"

    VOLUME_NAME="moonleaf"

    if [ -d "/Volumes/$VOLUME_NAME" ]; then
        hdiutil detach "/Volumes/$VOLUME_NAME" -force
    fi

    hdiutil attach "$DMG_PATH"
    cp -rf "/Volumes/$VOLUME_NAME/moonleaf.app" "/Applications/"

    if [ -d "/Applications/macpaper.app" ]; then
        rm -rf "/Applications/macpaper.app"
    fi
    
    hdiutil detach "/Volumes/$VOLUME_NAME"

    rm -rf "$C_TMPDIR"

    echo "update completed"
else
    echo "app is up to date"
fi

exit 0
"""

    func do_update() {
        isUpdating = true

        let appPath = Bundle.main.bundlePath
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            updateError = "Could not get app version information"
            isUpdating = false
            return
        }

        let resourcesPath = "\(appPath)/Contents/Resources"
        let tempDir = NSTemporaryDirectory()
        let updaterScript = "\(tempDir)moonleaf_updater_\(UUID().uuidString).sh"

        let serverFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/macpaper/update_server")
        var serverArg = "https://github.com/naomisphere/moonleaf"
        if FileManager.default.fileExists(atPath: serverFile.path),
           let server = try? String(contentsOf: serverFile) {
            let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("github.com/naomisphere/") {
                serverArg = "https://\(trimmed)"
            }
        }

        do {
            try updaterScriptContent.write(toFile: updaterScript, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: updaterScript)
            
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = [updaterScript, currentVersion, resourcesPath, serverArg]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { p in
                try? FileManager.default.removeItem(atPath: updaterScript)
                DispatchQueue.main.async {
                    self.isUpdating = false
                    if p.terminationStatus == 0 {
                        self.show_reopen_prompt()
                    } else {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        self.updateError = String(data: data, encoding: .utf8) ?? "Unknown error"
                    }
                }
            }

            try process.run()
        } catch {
            try? FileManager.default.removeItem(atPath: updaterScript)
            updateError = error.localizedDescription
            isUpdating = false
        }
    }

    private func v(_ v1: String, newerThan v2: String) -> Bool {
        return v1.compare(v2, options: .numeric) == .orderedDescending
    }

    private func show_reopen_prompt() {
        let alert = NSAlert()
        alert.messageText = "Update Completed"
        alert.informativeText = "Update installed successfully. Restart moonleaf to use the new version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            reopen_app_after_upd()
        }
    }

    private func reopen_app_after_upd() {
        let appPath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.8 && open '\(appPath)'"]

        do {
            try task.run()
        } catch {
            print("while restarting: \(error)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}