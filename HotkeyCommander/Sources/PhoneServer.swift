import Foundation
import Network
import os

/// What the phones may see, taken from the saved configuration. The server works on a copy, away from the
/// main thread.
struct PhoneContent {
    var deviceKeys: Set<String> = []
    var buttonIDs: Set<String> = []
    var icons: Set<String> = []
    /// Changes whenever anything above does.
    var version = ""
    /// The buttons as a JSON array.
    var buttons = "[]"
    /// The Mac's name, alone in a JSON array.
    var macName = "[\"Mac\"]"
    var appIcon = Data()
}

/// Serves the phones' page on the local network and passes on which button was touched.
final class PhoneServer {
    enum State {
        case off, starting, on, failed(String)
    }

    /// Both are called on the main thread.
    var onStateChange: ((State) -> Void)?
    var onRun: ((String) -> Void)?

    /// Fixed, because it is part of every phone's link. A test build has its own.
    static let port: UInt16 = AppPaths.bundleID == "com.hotkeycommander.app" ? 47110 : 47111

    private static let maxConnections = 64

    private let queue = DispatchQueue(label: "phone-server", qos: .userInitiated)
    private var listener: NWListener?
    private var isWanted = false
    private var failure: NWError?
    private var connections: [ObjectIdentifier: PhoneConnection] = [:]
    private var content = PhoneContent()

    func update(_ content: PhoneContent) {
        queue.async { self.content = content }
    }

    func start() {
        queue.async {
            self.isWanted = true
            // One that is still closing starts the next when it is done.
            if self.listener == nil {
                self.listen()
            }
        }
    }

    func stop() {
        queue.async {
            self.isWanted = false
            self.report(.off)
            self.listener?.cancel()
            self.connections.values.forEach { $0.close() }
        }
    }

    private func report(_ state: State) {
        DispatchQueue.main.async { self.onStateChange?(state) }
    }

    // MARK: - Listening

    private func listen() {
        report(.starting)

        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = true
        // Without it, turning off and on again finds the port held by its own closed connections.
        parameters.allowLocalEndpointReuse = true

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: Self.port)!)
        } catch {
            isWanted = false
            report(.failed(Self.message(for: error as? NWError)))
            return
        }

        listener.stateUpdateHandler = { [weak self] state in
            self?.listenerChanged(to: state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    private func listenerChanged(to state: NWListener.State) {
        switch state {
        case .ready:
            if isWanted {
                report(.on)
            }
        case .waiting(let error) where error == .posix(.EADDRINUSE):
            failure = error
            listener?.cancel()
        case .failed(let error):
            failure = error
            listener?.cancel()
        case .cancelled:
            listener = nil
            let error = failure
            failure = nil
            guard isWanted else { return }
            if error == nil {
                listen()
            } else if error == .posix(.EADDRINUSE) {
                isWanted = false
                report(.failed(Self.message(for: error)))
            } else {
                // The network went away under it.
                Logger.app.error("phone server: \(String(describing: error), privacy: .public)")
                queue.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self = self, self.isWanted, self.listener == nil else { return }
                    self.listen()
                }
            }
        default:
            break
        }
    }

    private static func message(for error: NWError?) -> String {
        return error == .posix(.EADDRINUSE)
            ? "Port \(port) is used by another app."
            : "Can't use port \(port)."
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        guard isWanted, connections.count < Self.maxConnections else {
            connection.cancel()
            return
        }

        let phone = PhoneConnection(connection)
        let id = ObjectIdentifier(phone)
        connections[id] = phone
        phone.onRequest = { [weak self] request in
            self?.answer(to: request) ?? .notFound
        }
        phone.onClose = { [weak self] in
            self?.connections[id] = nil
        }
        phone.start(on: queue)
    }

    /// Everything that is not exactly one of these gets the same empty answer.
    private func answer(to request: PhoneRequest) -> PhoneResponse {
        let path = request.path
        guard path.count >= 2, path[0] == "d", content.deviceKeys.contains(path[1]) else { return .notFound }
        let base = "/d/\(path[1])"

        switch (request.method, path.dropFirst(2).joined(separator: "/")) {
        case ("GET", ""):
            return PhoneResponse(type: "text/html; charset=utf-8", body: PhonePage.html(base: base, state: state(full: true)))
        case ("GET", "state"):
            return PhoneResponse(type: "application/json", body: state(full: request.query["v"] != content.version))
        case ("GET", "app-icon.png"):
            return PhoneResponse(type: "image/png", body: content.appIcon)
        case ("GET", "manifest.webmanifest"):
            return PhoneResponse(type: "application/manifest+json", body: PhonePage.manifest(base: base))
        default:
            break
        }

        guard path.count == 4 else { return .notFound }
        switch (request.method, path[2]) {
        case ("GET", "icon"):
            guard content.icons.contains(path[3]),
                  let png = try? Data(contentsOf: AppPaths.icons.appendingPathComponent(path[3])) else {
                return .notFound
            }
            // A changed icon has a new name.
            return PhoneResponse(type: "image/png", body: png, cache: "max-age=31536000, immutable")
        case ("POST", "run"):
            return run(id: path[3], sentAt: request.query["at"])
        default:
            return .notFound
        }
    }

    /// A touch that arrives late, after the Mac slept or the network came back, is not run.
    private func run(id: String, sentAt: String?) -> PhoneResponse {
        guard content.buttonIDs.contains(id), let sentAt = sentAt.flatMap(Int64.init),
              abs(Self.now() - sentAt) <= 3000 else {
            return .notFound
        }
        DispatchQueue.main.async { self.onRun?(id) }
        return PhoneResponse(status: "204 No Content")
    }

    private func state(full: Bool) -> Data {
        let rest = full ? ",\"mac\":\(content.macName),\"buttons\":\(content.buttons)" : ""
        return Data("{\"now\":\(Self.now()),\"v\":\"\(content.version)\"\(rest)}".utf8)
    }

    /// Milliseconds on a clock that goes on while the Mac sleeps.
    private static func now() -> Int64 {
        return Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000)
    }
}
