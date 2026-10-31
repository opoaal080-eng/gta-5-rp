import Foundation
import SwiftUI
import SceneKit

// READ ONLY: masterlist is not the GTA5RP game connection.
// The public RAGE MP master list reports counts, not avatars/locations.
struct ServerSnapshot: Equatable {
    let players: Int
    let maxPlayers: Int
    let title: String
    let address: String
}

@MainActor
final class LiveServerMonitor: ObservableObject {
    @Published private(set) var servers: [String: ServerSnapshot] = [:]
    @Published private(set) var refreshed: Date?
    @Published private(set) var error: String?
    @Published private(set) var fetching = false

    func snapshot(for name: String) -> ServerSnapshot? { servers[name.lowercased()] }
    var projectOnline: Int? {
        guard !servers.isEmpty else { return nil }
        return servers.values.reduce(0) { $0 + $1.players }
    }

    func refresh() async {
        guard !fetching else { return }
        fetching = true
        defer { fetching = false }
        do {
            var request = URLRequest(url: URL(string: "https://cdn.rage.mp/master/")!)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count <= 20_000_000 else { throw MonitorError.invalidResponse }
            let parsed = try JSONSerialization.jsonObject(with: data)
            guard let list = parsed as? [String: [String: Any]] else { throw MonitorError.invalidResponse }
            let names = ["eclipse", "downtown", "rockford", "redwood", "murrieta", "chiliad", "mirror", "blaine"]
            var found: [String: ServerSnapshot] = [:]
            for (address, row) in list {
                guard let title = row["name"] as? String else { continue }
                let lowerTitle = title.lowercased()
                // Avoid accidentally labeling an unrelated server as GTA5RP.
                guard lowerTitle.contains("gta5rp") else { continue }
                let players = (row["players"] as? NSNumber)?.intValue
                let maxPlayers = (row["maxplayers"] as? NSNumber)?.intValue
                guard let count = players, let limit = maxPlayers,
                      count >= 0, limit > 0, count <= limit else { continue }
                for name in names where lowerTitle.contains(name) {
                    let entry = ServerSnapshot(players: count, maxPlayers: limit, title: title, address: address)
                    if found[name] == nil { found[name] = entry }
                }
            }
            servers = found
            refreshed = Date()
            error = found.isEmpty ? "GTA5RP отсутствует в ответе masterlist. Это не означает, что серверы выключены." : nil
        } catch {
            error = "Masterlist недоступен: \(error.localizedDescription)"
            // Do not show stale values as live data.
            servers = [:]
            refreshed = nil
        }
    }
}

private enum MonitorError: LocalizedError {
    case invalidResponse
    var errorDescription: String? { "Некорректный ответ RAGE MP masterlist" }
}

// Positions can ONLY arrive from an authorized server-side HTTPS feed.
// This is not a bypass of game authorization or encryption.
struct ObservedPlayer: Decodable, Identifiable {
    let id: String
    let name: String
    let x: Double
    let y: Double
    let z: Double
}
private struct PlayerFeed: Decodable {
    let players: [ObservedPlayer]
}
@MainActor
final class PlayerObserver: ObservableObject {
    @Published private(set) var players: [ObservedPlayer] = []
    @Published private(set) var status = "Координаты не подключены"
    @Published private(set) var busy = false
    @Published private(set) var refreshed: Date?

    func fetch(_ address: String) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let urlString = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString),
              url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else {
            players = []
            status = "Укажи HTTPS-адрес разрешённого API координат"
            return
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count <= 1_000_000 else { throw MonitorError.invalidResponse }
            let feed = try JSONDecoder().decode(PlayerFeed.self, from: data)
            guard feed.players.count <= 300 else { throw MonitorError.invalidResponse }
            var seen = Set<String>()
            for player in feed.players {
                guard !player.id.isEmpty, seen.insert(player.id).inserted,
                      player.name.count <= 64,
                      [player.x, player.y, player.z].allSatisfy({ $0.isFinite && abs($0) < 100000 }) else {
                    throw MonitorError.invalidResponse
                }
            }
            players = feed.players
            refreshed = Date()
            status = "Получено реальных позиций: \(feed.players.count)"
        } catch {
            players = []
            refreshed = nil
            status = "API не ответил: \(error.localizedDescription)"
        }
    }
}

struct PlayerWorldView: View {
    let players: [ObservedPlayer]
    var body: some View {
        if players.isEmpty {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.11)
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 39)).foregroundStyle(.orange)
                    Text("НЕТ ДАННЫХ О ПОЗИЦИЯХ").font(.headline)
                    Text("GTA5RP не отдаёт координаты через публичный masterlist.")
                        .font(.caption).multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }.padding(18)
            }.frame(height: 265).clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            SceneView(scene: Self.makeScene(players), options: [.allowsCameraControl])
                .frame(height: 310)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottomLeading) {
                    Text("Упрощённые 3D-маркеры, не игровые модели GTA")
                        .font(.caption2).padding(8)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
                        .padding(9)
                }
        }
    }

    static func makeScene(_ allPlayers: [ObservedPlayer]) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.055, green: 0.057, blue: 0.068, alpha: 1)
        let floor = SCNNode(geometry: SCNPlane(width: 140, height: 140))
        floor.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 1)
        floor.geometry?.firstMaterial?.isDoubleSided = true
        floor.eulerAngles.x = -.pi / 2
        floor.position.y = -0.02
        scene.rootNode.addChildNode(floor)
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 1100
        light.position = SCNVector3(15, 45, 15)
        scene.rootNode.addChildNode(light)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = 600
        camera.position = SCNVector3(0, 65, 85)
        camera.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camera)
        scene.pointOfView = camera

        guard let first = allPlayers.first else { return scene }
        for player in allPlayers.prefix(100) {
            let positionX = Float(max(-60, min(60, player.x - first.x)))
            let positionZ = Float(max(-60, min(60, player.y - first.y)))
            let node = SCNNode()
            let torso = SCNNode(geometry: SCNCapsule(capRadius: 0.4, height: 1.3))
            torso.geometry?.firstMaterial?.diffuse.contents = UIColor.systemOrange
            torso.position.y = 1.1
            node.addChildNode(torso)
            let head = SCNNode(geometry: SCNSphere(radius: 0.32))
            head.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            head.position.y = 2
            node.addChildNode(head)
            // All scene coordinates are relative to first observed player.
            node.position = SCNVector3(positionX, 0, positionZ)
            scene.rootNode.addChildNode(node)
        }
        return scene
    }
}
