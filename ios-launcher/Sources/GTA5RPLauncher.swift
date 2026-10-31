import SwiftUI
import Foundation
import CryptoKit

struct Manifest: Decodable {
    let version: Int
    let files: [GameFile]
}
struct GameFile: Decodable {
    let path: String
    let url: String
    let size: Int64
    let sha256: String
}
@MainActor final class GameAssets: ObservableObject {
    @Published var status = "Файлы не проверены"
    @Published var progress = ""
    @Published var busy = false
    @Published var count = 0
    private var files: [GameFile] = []
    private var baseURL: URL?
    private let fm = FileManager.default

    private var root: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RPResources", isDirectory: true)
    }
    private func target(_ file: GameFile) throws -> URL {
        let pieces = file.path.split(separator: "/", omittingEmptySubsequences: false)
        guard !pieces.isEmpty, !file.path.hasPrefix("/"), !file.path.contains("\\"),
              pieces.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw NSError(domain: "GTA5RP", code: 1,
                          userInfo: [NSLocalizedDescriptionKey:"Небезопасное имя файла"])
        }
        return pieces.reduce(root) { $0.appendingPathComponent(String($1)) }
    }
    private func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            digest.update(data: chunk)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private func matches(_ file: GameFile, at url: URL) throws -> Bool {
        guard fm.fileExists(atPath: url.path) else { return false }
        let props = try fm.attributesOfItem(atPath: url.path)
        guard let n = props[.size] as? NSNumber,
              n.int64Value == file.size else { return false }
        return try sha256(url) == file.sha256.lowercased()
    }
    func load(_ address: String) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            guard let url = URL(string: address), url.scheme == "https", url.host != nil else {
                throw NSError(domain:"GTA5RP", code:2,
                              userInfo:[NSLocalizedDescriptionKey:"Укажи HTTPS URL manifest.json"])
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count < 10_000_000 else {
                throw NSError(domain:"GTA5RP", code:3,
                              userInfo:[NSLocalizedDescriptionKey:"Неверный ответ сервера"])
            }
            let m = try JSONDecoder().decode(Manifest.self, from: data)
            guard m.version == 1, m.files.count <= 50000 else {
                throw NSError(domain:"GTA5RP", code:4,
                              userInfo:[NSLocalizedDescriptionKey:"Неверная версия манифеста"])
            }
            var paths = Set<String>()
            for file in m.files {
                _ = try target(file)
                guard file.size >= 0, file.sha256.count == 64,
                      file.sha256.lowercased().utf8.allSatisfy({
                          (48...57).contains($0) || (97...102).contains($0)
                      }), paths.insert(file.path).inserted else {
                    throw NSError(domain:"GTA5RP", code:5,
                                  userInfo:[NSLocalizedDescriptionKey:"Некорректный файл в списке"])
                }
            }
            files = m.files
            baseURL = url.deletingLastPathComponent()
            count = 0
            status = "Список файлов загружен"
            progress = "\(files.count) объектов"
        } catch {
            status = "Ошибка загрузки списка"
            progress = error.localizedDescription
        }
    }
    func download() async {
        guard !busy else { return }
        guard let baseURL = baseURL, !files.isEmpty else {
            progress = "Сначала получи список файлов"
            return
        }
        busy = true
        defer { busy = false }
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            for (i,file) in files.enumerated() {
                let dest = try target(file)
                status = "Обработка \(i + 1) / \(files.count)"
                progress = file.path
                if !(try matches(file, at: dest)) {
                    guard let link = URL(string:file.url, relativeTo:baseURL)?.absoluteURL,
                          link.scheme == "https", link.host == baseURL.host else {
                        throw NSError(domain:"GTA5RP", code:6,
                                      userInfo:[NSLocalizedDescriptionKey:"Ресурс должен быть на том же HTTPS-хосте"])
                    }
                    let (temp, response) = try await URLSession.shared.download(from:link)
                    guard (response as? HTTPURLResponse)?.statusCode == 200,
                          try matches(file, at:temp) else {
                        throw NSError(domain:"GTA5RP", code:7,
                                      userInfo:[NSLocalizedDescriptionKey:"Ошибка хеша или скачивания: \(file.path)"])
                    }
                    try fm.createDirectory(at:dest.deletingLastPathComponent(), withIntermediateDirectories:true)
                    if fm.fileExists(atPath:dest.path) { try fm.removeItem(at:dest) }
                    try fm.moveItem(at:temp,to:dest)
                }
                count = i + 1
            }
            status = "Все ресурсы загружены"
            progress = "\(count) файлов"
        } catch {
            status = "Загрузка прервана"
            progress = error.localizedDescription
        }
    }
}
struct ContentView: View {
    var body: some View { MainDashboard() }
}
@main struct GTA5RPLauncher: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
