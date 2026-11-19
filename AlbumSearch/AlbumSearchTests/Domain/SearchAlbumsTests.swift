import Foundation
import Testing
@testable import AlbumSearch

@Suite("Búsqueda de álbumes")
struct SearchAlbumsTests {
    @Test("Una búsqueda vacía no consulta el repositorio", arguments: ["", "   ", "\n\t"])
    func emptyQueriesDoNotReachRepository(query: String) async throws {
        let repository = RepositorySpy()
        let result = try await SearchAlbums(repository: repository).execute(query: query)

        #expect(result.isEmpty)
        #expect(await repository.queries.isEmpty)
    }

    @Test("El texto se recorta y se convierte a minúsculas", arguments: ["  QUEEN\n", "queen", "\tQuEeN  "])
    func normalizesQuery(query: String) async throws {
        let repository = RepositorySpy()
        _ = try await SearchAlbums(repository: repository).execute(query: query)

        #expect(await repository.queries == ["queen"])
    }

    @Test("Devuelve los resultados del repositorio en el mismo orden")
    func returnsRepositoryResults() async throws {
        let repository = RepositorySpy(albums: sampleAlbums)
        let result = try await SearchAlbums(repository: repository).execute(query: "queen")

        #expect(result == sampleAlbums)
    }

    @Test("Propaga los errores del repositorio")
    func propagatesRepositoryErrors() async {
        let search = SearchAlbums(repository: FailingRepository())

        await #expect(throws: RepositoryError.unavailable) {
            try await search.execute(query: "queen")
        }
    }

    @Test("Una tarea ya cancelada no consulta el repositorio")
    @MainActor
    func cancellationBeforeSearchSkipsRepository() async {
        let repository = RepositorySpy()
        let search = SearchAlbums(repository: repository)
        // La tarea hereda MainActor: la cancelamos antes de cederle la ejecución.
        let task = Task { try await search.execute(query: "queen") }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await repository.queries.isEmpty)
    }

    @Test("Descarta resultados si se cancela durante la consulta")
    func cancellationAfterRequestRejectsResults() async {
        let repository = ControlledRepository()
        let search = SearchAlbums(repository: repository)
        let task = Task { try await search.execute(query: "queen") }

        await repository.waitUntilRequested()
        task.cancel()
        await repository.complete(with: sampleAlbums)

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}

private let sampleAlbums = [
    Album(
        id: 1,
        title: "A Night at the Opera",
        artist: "Queen",
        genre: "Rock",
        trackCount: 12,
        releaseDate: Date(timeIntervalSince1970: 185_760_000)
    ),
    Album(
        id: 2,
        title: "The Works",
        artist: "Queen",
        genre: "Rock",
        trackCount: 9,
        releaseDate: nil
    )
]

private actor RepositorySpy: AlbumRepository {
    private let albums: [Album]
    private(set) var queries: [String] = []

    init(albums: [Album] = []) {
        self.albums = albums
    }

    func search(query: String) async throws -> [Album] {
        queries.append(query)
        return albums
    }
}

private enum RepositoryError: Error, Equatable {
    case unavailable
}

private struct FailingRepository: AlbumRepository {
    func search(query: String) async throws -> [Album] {
        throw RepositoryError.unavailable
    }
}

private actor ControlledRepository: AlbumRepository {
    private var pendingResult: CheckedContinuation<[Album], Never>?
    private var requestWaiter: CheckedContinuation<Void, Never>?

    func search(query: String) async throws -> [Album] {
        // Ignora la cancelación a propósito para probar la comprobación del caso de uso.
        await withCheckedContinuation { continuation in
            pendingResult = continuation
            requestWaiter?.resume()
            requestWaiter = nil
        }
    }

    func waitUntilRequested() async {
        guard pendingResult == nil else { return }
        await withCheckedContinuation { requestWaiter = $0 }
    }

    func complete(with albums: [Album]) {
        guard let continuation = pendingResult else {
            preconditionFailure("No hay ninguna búsqueda pendiente")
        }
        pendingResult = nil
        continuation.resume(returning: albums)
    }
}
