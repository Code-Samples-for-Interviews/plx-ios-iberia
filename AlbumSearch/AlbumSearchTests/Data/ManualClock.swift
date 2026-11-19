import Synchronization

// DECISIÓN: Adelantar el reloj permite probar la expiración sin esperas ni estado compartido inseguro.
final class ManualClock: Sendable {
    private let instant = Mutex(ContinuousClock.now)

    var now: ContinuousClock.Instant { instant.withLock { $0 } }

    func advance(by duration: Duration) {
        instant.withLock { $0 = $0.advanced(by: duration) }
    }
}
