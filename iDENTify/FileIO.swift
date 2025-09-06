// ====================
// Sandbox-safe File I/O Helper
// ====================
//
// Drop this into your project (e.g., FileIO.swift) and replace any
// hard-coded "/Users/.../Downloads" or "~/Downloads" paths with calls to FileIO.
// This fixes "Sandbox: deny(1) file-write-create ..." errors in Xcode.
// ====================

import Foundation
#if canImport(AppKit)
import AppKit // For macOS NSSavePanel
#endif

enum AppDir {
    case documents
    case caches
    case temporary
}

enum FileIOError: Error {
    case directoryUnavailable
}

struct FileIO {
    // Get a URL inside the app sandbox
    static func url(_ name: String, in dir: AppDir = .documents) throws -> URL {
        switch dir {
        case .documents:
            guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            else { throw FileIOError.directoryUnavailable }
            return base.appendingPathComponent(name)
        case .caches:
            guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            else { throw FileIOError.directoryUnavailable }
            return base.appendingPathComponent(name)
        case .temporary:
            return FileManager.default.temporaryDirectory.appendingPathComponent(name)
        }
    }

    // Write data into sandboxed directory
    @discardableResult
    static func write(_ data: Data, to name: String, dir: AppDir = .documents) throws -> URL {
        let url = try url(name, in: dir)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}

// ====================
// Example (iOS):
// ====================
// Old (bad):
// let path = "/Users/NikhilSinha/Downloads/iDENTify/output.json"
// try data.write(to: URL(fileURLWithPath: path))
//
// New (good):
// let url = try FileIO.url("output.json", in: .documents)
// try data.write(to: url)

// ====================
// Example (macOS):
// ====================
// If you really want to let the user save to Downloads, use NSSavePanel.
// ====================

#if canImport(AppKit)
func saveDataWithPanel(_ data: Data, suggestedName: String = "output.json") {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = suggestedName
    panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            print("Saved to:", url)
        } catch {
            print("Save failed:", error)
        }
    }
}
#endif

// ====================
// Debug Guardrail
// ====================
// Prevent accidental writes outside sandbox during development.
// ====================
#if DEBUG
func assertSandbox(_ url: URL) {
    precondition(
        url.path.contains("/Documents/") ||
        url.path.contains("/Library/Caches/") ||
        url.path.contains("/tmp/"),
        "Refusing to write outside sandbox: \(url.path)"
    )
}
#endif