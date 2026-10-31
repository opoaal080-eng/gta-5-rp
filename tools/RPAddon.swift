import Foundation
import CryptoKit

// These are companion files only. No GTA5RP/RAGE MP protocol is implemented.
struct RPFile: Codable {
    let path: String
    let size: Int64
    let sha256: String
}

struct RPManifest: Codable {
    let schemaVersion: Int
    let packageName: String
    let version: String
    let files: [RPFile]

    func validate() throws {
        guard schemaVersion == 1, files.count <= 100_000 else {
            throw RPProblem.invalid("Unsupported or oversized manifest")
        }
        var seen = Set<String>()
        var total: Int64 = 0
        for file in files {
            let parts = file.path.split(separator: "/", omittingEmptySubsequences: false)
            guard !file.path.isEmpty, !file.path.hasPrefix("/"),
                  !file.path.contains("\\"), !file.path.contains("\u{0000}"),
                  parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  seen.insert(file.path).inserted else {
                throw RPProblem.invalid("Unsafe or repeated path")
            }
            guard file.size >= 0, file.size <= 30_000_000_000,
                  file.sha256.count == 64,
                  file.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                throw RPProblem.invalid("Invalid size or checksum")
            }
            total += file.size
            guard total <= 100_000_000_000 else { throw RPProblem.invalid("Package exceeds limit") }
        }
    }
}

enum RPProblem: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

enum RPHash {
    static func check(_ url: URL) throws -> (Int64, String) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var sha = SHA256()
        var size: Int64 = 0
        while true {
            let piece = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if piece.isEmpty { break }
            size += Int64(piece.count)
            sha.update(data: piece)
        }
        return (size, sha.finalize().map { String(format: "%02x", $0) }.joined())
    }
}

@MainActor
final class RPFileManager: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var status = "No RP resources imported"
    @Published private(set) var count = 0
    @Published private(set) var bytes: Int64 = 0

    nonisolated static var root: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    nonisolated static var destination: URL {
        root.appendingPathComponent("RPResources", isDirectory: true)
    }
    nonisolated static var meta: URL { root.appendingPathComponent("rp-manifest.json") }

    func refresh() {
        guard let content = try? Data(contentsOf: Self.meta),
              let manifest = try? JSONDecoder().decode(RPManifest.self, from: content),
              (try? manifest.validate()) != nil else { return }
        count = manifest.files.count
        bytes = manifest.files.reduce(0) { $0 + $1.size }
        status = "Previously imported resources found. They are not mounted into the game."
    }

    func importFolder(_ picked: URL) {
        guard !busy else { return }
        busy = true
        status = "Importing..."
        Task {
            do {
                let manifest = try await Task.detached(priority: .userInitiated) {
                    try Self.importLocal(picked)
                }.value
                finish(manifest)
                status = "Imported and verified local files."
            } catch {
                busy = false
                status = "Import error: \(error.localizedDescription)"
            }
        }
    }

    func download(_ address: String) {
        guard !busy else { return }
        guard let url = URL(string: address), url.scheme?.lowercased() == "https",
              url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            status = "Enter an HTTPS manifest URL without credentials or query."
            return
        }
        busy = true
        status = "Reading manifest..."
        Task {
            let fm = FileManager.default
            let staging = Self.root.appendingPathComponent("RPResources_staging", isDirectory: true)
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                try Self.expect200(response)
                guard data.count <= 30_000_000 else { throw RPProblem.invalid("Manifest too large") }
                let manifest = try JSONDecoder().decode(RPManifest.self, from: data)
                try manifest.validate()
                if fm.fileExists(atPath: staging.path) { try fm.removeItem(at: staging) }
                try fm.createDirectory(at: staging, withIntermediateDirectories: true)
                for (index, file) in manifest.files.enumerated() {
                    try Task.checkCancellation()
                    status = "Downloading \(index + 1)/\(manifest.files.count)"
                    let from = url.deletingLastPathComponent().appendingPathComponent(file.path)
                    let to = staging.appendingPathComponent(file.path)
                    try fm.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let (tmp, result) = try await URLSession.shared.download(from: from)
                    try Self.expect200(result)
                    try fm.moveItem(at: tmp, to: to)
                    let actual = try await Task.detached(priority: .utility) {
                        try RPHash.check(to)
                    }.value
                    guard actual.0 == file.size, actual.1 == file.sha256 else {
                        throw RPProblem.invalid("SHA-256 mismatch: \(file.path)")
                    }
                }
                try Self.install(staging, manifest)
                finish(manifest)
                status = "Downloaded and SHA-256 verified."
            } catch {
                try? fm.removeItem(at: staging)
                busy = false
                status = "Download error: \(error.localizedDescription)"
            }
        }
    }

    private func finish(_ manifest: RPManifest) {
        count = manifest.files.count
        bytes = manifest.files.reduce(0) { $0 + $1.size }
        busy = false
    }

    nonisolated private static func importLocal(_ picked: URL) throws -> RPManifest {
        let access = picked.startAccessingSecurityScopedResource()
        defer { if access { picked.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let staging = root.appendingPathComponent("RPResources_staging", isDirectory: true)
        if fm.fileExists(atPath: staging.path) { try fm.removeItem(at: staging) }
        do {
            try fm.copyItem(at: picked, to: staging)
            guard let enumerator = fm.enumerator(at: staging,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
                throw RPProblem.invalid("Unable to scan imported files")
            }
            var files: [RPFile] = []
            for case let file as URL in enumerator {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true { throw RPProblem.invalid("Symbolic links not allowed") }
                guard values.isRegularFile == true else { continue }
                let rel = String(file.path.dropFirst(staging.path.count + 1))
                    .replacingOccurrences(of: "\\", with: "/")
                let (size, digest) = try RPHash.check(file)
                files.append(RPFile(path: rel, size: size, sha256: digest))
            }
            files.sort { $0.path < $1.path }
            let manifest = RPManifest(schemaVersion: 1, packageName: "Local RP",
                                      version: "local-1", files: files)
            try manifest.validate()
            try install(staging, manifest)
            return manifest
        } catch {
            try? fm.removeItem(at: staging)
            throw error
        }
    }

    nonisolated private static func install(_ staged: URL, _ manifest: RPManifest) throws {
        let fm = FileManager.default
        let backup = root.appendingPathComponent("RPResources_backup", isDirectory: true)
        if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) }
        let hadOld = fm.fileExists(atPath: destination.path)
        if hadOld { try fm.moveItem(at: destination, to: backup) }
        do {
            try fm.moveItem(at: staged, to: destination)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: meta, options: .atomic)
            if hadOld { try? fm.removeItem(at: backup) }
        } catch {
            try? fm.removeItem(at: destination)
            if hadOld { try? fm.moveItem(at: backup, to: destination) }
            throw error
        }
    }

    nonisolated private static func expect200(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RPProblem.invalid("HTTP status is not 200")
        }
    }
}
