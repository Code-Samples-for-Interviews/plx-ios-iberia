import Testing
@testable import AlbumSearch

// REQUISITO [TEST]: Pruebas unitarias de la caché de Data.
@Suite("Caché de búsquedas")
struct AlbumSearchCacheTests {
    @Test("Al llegar al límite se elimina la entrada con el vencimiento más próximo")
    func cacheHasLimitedCapacity() async throws {
        let clock = ManualClock()
        let cache = AlbumSearchCache(now: { clock.now })

        for index in 0..<51 {
            try await cache.store([], for: "query-\(index)")
            clock.advance(by: .seconds(1))
        }

        #expect(try await cache.albums(for: "query-50") != nil)
        #expect(try await cache.albums(for: "query-0") == nil)
    }

    // REQUISITO [CANCELACION]: Respetar la cancelación al guardar resultados.
    @Test("Una tarea cancelada no guarda resultados al entrar en la caché")
    @MainActor
    func cancelledWriteDoesNotStoreResults() async throws {
        let cache = AlbumSearchCache()
        let task = Task { try await cache.store([], for: "queen") }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await cache.albums(for: "queen") == nil)
    }

    // REQUISITO [CANCELACION]: Respetar la cancelación al leer una entrada vigente.
    @Test("Una tarea cancelada tampoco obtiene un resultado cacheado")
    @MainActor
    func cancelledReadDoesNotReturnCachedResults() async throws {
        let cache = AlbumSearchCache()
        try await cache.store([], for: "queen")
        let task = Task { try await cache.albums(for: "queen") }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
