// REQUISITO [ARQ]: El almacenamiento de resultados pertenece a Data.
// Un actor protege el estado mutable de la caché.
actor AlbumSearchCache {
    private struct Entry {
        let albums: [Album]
        let expiresAt: ContinuousClock.Instant
    }

    private let lifetime: Duration
    private let now: @Sendable () -> ContinuousClock.Instant
    private let maximumEntries = 50 // El límite de 50 entradas acota memoria. No es requisito.
    // REQUISITO [CACHE]: Guardar los resultados por query en memoria es suficiente. La persistencia en disco es opcional y no se implementa.
    private var entries: [String: Entry] = [:]

    // REQUISITO [CACHE]: Los resultados deben tener una vigencia limitada. Se toman tres minutos.
    init(lifetime: Duration = .seconds(3 * 60),
         now: @escaping @Sendable () -> ContinuousClock.Instant = { .now }) {
        self.lifetime = lifetime
        self.now = now
    }

    // REQUISITO [CACHE]: La lectura solo puede devolver entradas que no hayan caducado.
    func albums(for query: String) throws -> [Album]? {
        try Task.checkCancellation()
        removeExpiredEntries()
        return entries[query]?.albums
    }

    func store(_ albums: [Album], for query: String) throws {
        // REQUISITO [CANCELACION]: Respetar también la cancelación mientras se espera para entrar en el actor.
        try Task.checkCancellation()
        removeExpiredEntries()
        if entries[query] == nil {
            makeRoomIfNeeded()
        }
        entries[query] = Entry(albums: albums, expiresAt: now().advanced(by: lifetime))
    }

    // REQUISITO [CACHE]: Una entrada caducada deja de ser un resultado válido.
    private func removeExpiredEntries() {
        let instant = now()
        entries = entries.filter { $0.value.expiresAt > instant }
    }

    private func makeRoomIfNeeded() {
        guard entries.count >= maximumEntries,
              let oldest = entries.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key else {
            return
        }
        entries.removeValue(forKey: oldest)
    }
}
