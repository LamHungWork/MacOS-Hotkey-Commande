import Foundation
import Network

/// The parts of a request the server looks at.
struct PhoneRequest {
    let method: String
    let path: [String]
    let query: [String: String]

    /// nil when the head is not a request.
    init?(head: Data) {
        guard let text = String(data: head, encoding: .utf8),
              let line = text.components(separatedBy: "\r\n").first else {
            return nil
        }
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/1."), parts[1].hasPrefix("/") else { return nil }

        let target = parts[1].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        method = String(parts[0])
        path = target[0].split(separator: "/").map(String.init)

        var query: [String: String] = [:]
        if target.count == 2 {
            for pair in target[1].split(separator: "&") {
                let sides = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                query[String(sides[0])] = sides.count == 2 ? String(sides[1]) : ""
            }
        }
        self.query = query
    }
}

struct PhoneResponse {
    static let notFound = PhoneResponse(status: "404 Not Found")

    var status = "200 OK"
    var type: String?
    var body = Data()
    var cache = "no-store"

    var data: Data {
        var head = "HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nCache-Control: \(cache)\r\nConnection: close\r\n"
        if let type = type {
            head += "Content-Type: \(type)\r\n"
        }
        return Data((head + "\r\n").utf8) + body
    }
}

/// One request, one answer. Whatever comes in, it is over within a fixed time and a fixed size.
final class PhoneConnection {
    var onRequest: ((PhoneRequest) -> PhoneResponse)?
    var onClose: (() -> Void)?

    private static let maxHead = 8192
    private static let timeLimit: TimeInterval = 10

    private let connection: NWConnection
    private var received = Data()
    private var extra = 0
    private var isClosed = false

    init(_ connection: NWConnection) {
        self.connection = connection
    }

    func start(on queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.close()
            default: break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.timeLimit) { [weak self] in
            self?.close()
        }
        receive()
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
        onClose?()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxHead) { [weak self] data, _, isComplete, error in
            guard let self = self, !self.isClosed else { return }
            if let data = data {
                self.received.append(data)
            }

            if let end = self.received.range(of: Data("\r\n\r\n".utf8)), end.lowerBound <= Self.maxHead {
                let request = PhoneRequest(head: self.received.subdata(in: 0..<end.lowerBound))
                self.send(request.flatMap { self.onRequest?($0) } ?? .notFound)
            } else if isComplete || error != nil || self.received.count > Self.maxHead {
                self.close()
            } else {
                self.receive()
            }
        }
    }

    private func send(_ response: PhoneResponse) {
        connection.send(content: response.data, completion: .contentProcessed { [weak self] error in
            if error != nil {
                self?.close()
            } else {
                self?.waitForOtherSide()
            }
        })
    }

    /// The phone closes first, so the Mac's side of the port is free again at once.
    private func waitForOtherSide() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxHead) { [weak self] data, _, isComplete, error in
            guard let self = self, !self.isClosed else { return }
            self.extra += data?.count ?? 0
            if isComplete || error != nil || self.extra > Self.maxHead {
                self.close()
            } else {
                self.waitForOtherSide()
            }
        }
    }
}
