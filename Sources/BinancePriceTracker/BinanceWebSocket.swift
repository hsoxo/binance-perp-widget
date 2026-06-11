import Foundation

/// Streams Binance USDT-M perpetual futures `<symbol>@bookTicker` updates over
/// a single combined WebSocket. Reconnects with exponential backoff.
///
/// `bookTicker` was chosen over `miniTicker` / `aggTrade` because on some
/// networks the latter two never deliver frames (handshake succeeds but the
/// stream stays silent). `bookTicker` pushes on every best-bid/ask change and
/// is reliably available.
final class BinanceWebSocketClient: NSObject {
    private let baseURL = "wss://fstream.binance.com/stream"

    /// Called with (symbol, bid, ask) on every tick.
    private let onBookTick: @Sendable (String, Double, Double) -> Void
    private let staleTimeout: TimeInterval
    private let watchdogInterval: TimeInterval

    private let queue = DispatchQueue(label: "binance.ws.client")
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var desiredSymbols: Set<String> = []
    private var reconnectDelay: TimeInterval = 1
    private var reconnectWorkItem: DispatchWorkItem?
    private var watchdogTimer: DispatchSourceTimer?
    private var lastMessageAt: Date?

    init(staleTimeout: TimeInterval = 45,
         watchdogInterval: TimeInterval = 15,
         onBookTick: @escaping @Sendable (String, Double, Double) -> Void) {
        self.staleTimeout = staleTimeout
        self.watchdogInterval = watchdogInterval
        self.onBookTick = onBookTick
    }

    /// Replace the subscribed symbol set. Reconnects only if it changed.
    func setSymbols(_ symbols: [String]) {
        let normalized = Set(symbols.map { $0.lowercased() })
        queue.async { [weak self] in
            guard let self else { return }
            guard normalized != self.desiredSymbols else { return }
            self.desiredSymbols = normalized
            self.reconnect(resetBackoff: true)
        }
    }

    /// Tear down and reopen the socket immediately. Use after the system wakes
    /// from sleep — the existing task can stay in a half-open state that never
    /// errors out, so neither `receive()` nor `didCloseWith` fires.
    func forceReconnect() {
        queue.async { [weak self] in
            self?.reconnect(resetBackoff: true)
        }
    }

    // MARK: - Connection lifecycle (queue-isolated)

    private func reconnect(resetBackoff: Bool) {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        if resetBackoff { reconnectDelay = 1 }

        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        stopWatchdog()

        guard !desiredSymbols.isEmpty else { return }
        connect()
    }

    private func connect() {
        let symbols = desiredSymbols
        guard !symbols.isEmpty else { return }
        let streams = symbols.map { "\($0)@bookTicker" }.joined(separator: "/")
        guard let url = URL(string: "\(baseURL)?streams=\(streams)") else { return }

        let newTask = session.webSocketTask(with: url)
        task = newTask
        lastMessageAt = Date()
        newTask.resume()
        startReceiveLoop(task: newTask)
        startWatchdog(task: newTask)
    }

    /// The closure-based `receive(completionHandler:)` API silently stops
    /// firing on some macOS 14+ builds when the URLSession also has a delegate.
    /// The `async` form is reliable.
    private func startReceiveLoop(task: URLSessionWebSocketTask) {
        receiveTask?.cancel()
        receiveTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    self?.queue.async { self?.markMessageReceived(task: task) }
                    self?.handle(message)
                } catch {
                    if !Task.isCancelled {
                        self?.queue.async { self?.scheduleReconnect(ifCurrent: task) }
                    }
                    return
                }
            }
        }
    }

    private func markMessageReceived(task receivedTask: URLSessionWebSocketTask) {
        guard task === receivedTask else { return }
        lastMessageAt = Date()
        reconnectDelay = 1
    }

    private func startWatchdog(task watchedTask: URLSessionWebSocketTask) {
        stopWatchdog()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + watchdogInterval, repeating: watchdogInterval)
        timer.setEventHandler { [weak self, weak watchedTask] in
            guard let self, let watchedTask else { return }
            guard self.task === watchedTask, !self.desiredSymbols.isEmpty else {
                self.stopWatchdog()
                return
            }

            let idle = Date().timeIntervalSince(self.lastMessageAt ?? .distantPast)
            if idle >= self.staleTimeout {
                NSLog("[BPT] WS stream stale for %.0fs; reconnecting", idle)
                self.reconnect(resetBackoff: true)
            }
        }
        watchdogTimer = timer
        timer.resume()
    }

    private func stopWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        lastMessageAt = nil
    }

    private func scheduleReconnect() {
        reconnectWorkItem?.cancel()

        let delay = min(reconnectDelay, 30)
        reconnectDelay = min(reconnectDelay * 2, 30)
        let work = DispatchWorkItem { [weak self] in
            self?.reconnect(resetBackoff: false)
        }
        reconnectWorkItem = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func scheduleReconnect(ifCurrent receivedTask: URLSessionWebSocketTask) {
        guard task === receivedTask else { return }
        scheduleReconnect()
    }

    nonisolated private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let s):
            guard let d = s.data(using: .utf8) else { return }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            return
        }
        guard let envelope = try? JSONDecoder().decode(StreamEnvelope.self, from: data) else { return }
        let payload = envelope.data
        guard let bid = Double(payload.bid), let ask = Double(payload.ask) else { return }
        onBookTick(payload.symbol, bid, ask)
    }
}

extension BinanceWebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        queue.async { [weak self, weak webSocketTask] in
            guard let self, let webSocketTask else { return }
            self.scheduleReconnect(ifCurrent: webSocketTask)
        }
    }
}

private struct StreamEnvelope: Decodable {
    let stream: String
    let data: BookTickerPayload
}

private struct BookTickerPayload: Decodable {
    let symbol: String
    let bid: String
    let ask: String

    enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case bid = "b"
        case ask = "a"
    }
}
