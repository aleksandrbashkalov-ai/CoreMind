import Foundation

/// A lightweight ticking timer that wraps the common `Task.sleep` + `MainActor.run` pattern.
/// Each tick calls `onTick` with the current elapsed time.
///
/// Not actor-isolated — the timer's Task runs on the cooperative thread pool
/// and dispatches callbacks to MainActor via `MainActor.run`.
///
/// Example:
/// ```swift
/// let timer = TimerManager(interval: 1.0)
/// timer.start(
///     onTick: { elapsed in
///         elapsed >= duration ? .stop : .continue
///     },
///     onComplete: { print("Done!") }
/// )
/// timer.cancel()
/// ```
final class TimerManager {
    enum TickResult {
        case `continue`
        case stop
    }

    private var task: Task<Void, Never>?
    private let interval: TimeInterval
    private let elapsed = MutableBox(0.0)

    /// Whether the timer is currently ticking.
    var isRunning: Bool { task != nil }

    /// Creates a timer with the given tick interval.
    /// - Parameter interval: Seconds between ticks (default 1.0, use 0.1 for breathing).
    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    /// Starts (or restarts) the timer.
    /// - Parameters:
    ///   - onTick: Called on MainActor each tick with elapsed seconds.
    ///             Return `.stop` to end the timer cleanly.
    ///   - onComplete: Called once on MainActor when the timer stops for any reason.
    func start(
        onTick: @escaping @Sendable (TimeInterval) -> TickResult,
        onComplete: @escaping @Sendable () -> Void = {}
    ) {
        cancel()
        elapsed.value = 0

        task = Task { [self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                let result = await MainActor.run {
                    elapsed.value += interval
                    return onTick(elapsed.value)
                }

                if result == .stop || Task.isCancelled {
                    await MainActor.run { onComplete() }
                    break
                }
            }
        }
    }

    /// Cancels the timer. Safe to call even if not running.
    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// A simple mutable reference type for passing values across actor boundaries.
private final class MutableBox<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
