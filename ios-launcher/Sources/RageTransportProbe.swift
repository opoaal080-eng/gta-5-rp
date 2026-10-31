import Foundation
import Network

/// A transport diagnostic, NOT a RAGE MP session handshake.
@MainActor final class RageTransportProbe: ObservableObject {
    @Published var status = "Не проверено"
    @Published var busy = false

    func check(host: String, port: UInt16 = 22005) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty, !cleanHost.contains("/"),
              let nwPort = NWEndpoint.Port(rawValue: port) else {
            status = "Некорректный адрес"
            return
        }
        status = "Проверяем TCP \(cleanHost):\(port)…"
        let connection = NWConnection(host: NWEndpoint.Host(cleanHost), port: nwPort, using: .tcp)
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let queue = DispatchQueue(label: "rage.transport.probe")
            let lock = NSLock()
            var finished = false
            func complete(_ success: Bool) {
                lock.lock()
                let shouldResume = !finished
                if shouldResume { finished = true }
                lock.unlock()
                if shouldResume { continuation.resume(returning: success) }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: complete(true)
                case .failed, .cancelled: complete(false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 5) { complete(false) }
        }
        connection.cancel()
        status = result
            ? "TCP-порт доступен. Игровая авторизация и UDP-сессия не проверены."
            : "TCP не ответил за 5 секунд. Это не доказывает, что игровой UDP-сервер недоступен."
    }
}
