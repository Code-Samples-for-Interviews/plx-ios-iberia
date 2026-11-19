import Foundation
import Testing
@testable import AlbumSearch

// REQUISITO [TEST-02]: Tests de Data que validan el uso y la expiración de la caché.
// REQUISITO PROPIO [TEST-03]: Esta suite usa Swift Testing.
@Suite("Repositorio de iTunes y caché")
struct ITunesAlbumRepositoryTests {
    @Test("Convierte la respuesta de iTunes al modelo de la app")
    func mapsResponse() async throws {
        let repository = ITunesAlbumRepository(client: HTTPClientStub(responses: [.success(albumJSON)]))
        let result = try await repository.search(query: "queen")

        #expect(result == [Album(
            id: 1,
            title: "A Night at the Opera",
            artist: "Queen",
            genre: "Rock",
            trackCount: 12,
            releaseDate: ISO8601DateFormatter().date(from: "1975-11-21T08:00:00Z")
        )])
    }

    // REQUISITO [CACHE-03, TEST-02]: Una entrada vigente debe evitar otra petición de red.
    @Test("La caché vigente evita otra petición, también con resultados vacíos", arguments: [albumJSON, emptyJSON])
    func validCacheAvoidsNetwork(json: Data) async throws {
        let client = HTTPClientStub(responses: [.success(json)])
        let clock = ManualClock()
        let repository = ITunesAlbumRepository(client: client, cache: AlbumSearchCache(now: { clock.now }))

        let first = try await repository.search(query: "queen")
        clock.advance(by: .seconds(179))
        let second = try await repository.search(query: "queen")

        #expect(first == second)
        #expect(await client.requests.count == 1)
    }

    // REQUISITO [CACHE-04, TEST-02]: Al caducar, recuperar de red y reutilizar el nuevo resultado.
    @Test("Al caducar se consulta la red y se reemplaza la entrada")
    func expiredCacheIsReplaced() async throws {
        let client = HTTPClientStub(responses: [.success(albumJSON), .success(emptyJSON)])
        let clock = ManualClock()
        let repository = ITunesAlbumRepository(client: client, cache: AlbumSearchCache(now: { clock.now }))

        _ = try await repository.search(query: "queen")
        clock.advance(by: .seconds(180))
        let refreshed = try await repository.search(query: "queen")
        let cached = try await repository.search(query: "queen")

        #expect(refreshed.isEmpty)
        #expect(cached == refreshed)
        #expect(await client.requests.count == 2)
    }

    // REQUISITO [CACHE-01]: Cada query conserva sus propios resultados.
    @Test("Cada query tiene su propia entrada")
    func queriesHaveIndependentEntries() async throws {
        let client = HTTPClientStub(responses: [.success(albumJSON), .success(emptyJSON)])
        let repository = ITunesAlbumRepository(client: client)

        _ = try await repository.search(query: "queen")
        #expect(try await repository.search(query: "adele").isEmpty)
        #expect(try await repository.search(query: "queen").count == 1)
        #expect(await client.requests.count == 2)
    }

    @Test("La petición codifica el texto y fija el catálogo de álbumes")
    func buildsSearchRequest() async throws {
        let client = HTTPClientStub(responses: [.success(emptyJSON)])
        let repository = ITunesAlbumRepository(client: client)
        _ = try await repository.search(query: "ac/dc & amigos")

        let request = try #require(await client.requests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(url.scheme == "https")
        #expect(url.host == "itunes.apple.com")
        #expect(url.path == "/search")
        #expect(components.queryItems == [
            URLQueryItem(name: "term", value: "ac/dc & amigos"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "country", value: "es"),
            URLQueryItem(name: "limit", value: "30")
        ])
    }

    @Test("Los errores HTTP se propagan y no se guardan", arguments: [404, 429, 503])
    func httpErrorsAreNotCached(status: Int) async throws {
        let client = HTTPClientStub(responses: [.httpError(status), .success(albumJSON)])
        let repository = ITunesAlbumRepository(client: client)

        await #expect(throws: HTTPError.statusCode(status)) {
            try await repository.search(query: "queen")
        }
        #expect(try await repository.search(query: "queen").count == 1)
        #expect(await client.requests.count == 2)
    }

    @Test("Los errores de conexión se propagan y no se guardan")
    func transportErrorsAreNotCached() async throws {
        let client = HTTPClientStub(responses: [.offline, .success(albumJSON)])
        let repository = ITunesAlbumRepository(client: client)

        await #expect(throws: URLError.self) {
            try await repository.search(query: "queen")
        }
        #expect(try await repository.search(query: "queen").count == 1)
        #expect(await client.requests.count == 2)
    }

    @Test("Una respuesta que no se puede decodificar no se guarda")
    func decodingErrorsAreNotCached() async throws {
        let client = HTTPClientStub(responses: [.success(Data("no es json".utf8)), .success(albumJSON)])
        let repository = ITunesAlbumRepository(client: client)

        await #expect(throws: DecodingError.self) {
            try await repository.search(query: "queen")
        }
        #expect(try await repository.search(query: "queen").count == 1)
        #expect(await client.requests.count == 2)
    }

    @Test("Los campos opcionales ausentes tienen un valor conocido")
    func mapsMissingOptionalFields() async throws {
        let json = Data(#"{"results":[{"collectionId":2,"collectionName":"Un álbum","artistName":"Un artista"}]}"#.utf8)
        let repository = ITunesAlbumRepository(client: HTTPClientStub(responses: [.success(json)]))
        let album = try #require(try await repository.search(query: "album").first)

        #expect(album.genre == "Género no disponible")
        #expect(album.trackCount == 0)
        #expect(album.releaseDate == nil)
    }

    // REQUISITO [CAN-01]: La cancelación debe impedir continuar aunque el cliente no coopere.
    @Test("Una respuesta cancelada no llena la caché aunque el cliente siga trabajando")
    func cancelledResponseIsNotCached() async throws {
        let client = ControlledHTTPClient()
        let repository = ITunesAlbumRepository(client: client)
        let task = Task { try await repository.search(query: "queen") }
        await client.waitUntilRequested()
        task.cancel()
        await client.complete()

        await #expect(throws: CancellationError.self) { try await task.value }

        let nextTask = Task { try await repository.search(query: "queen") }
        await client.waitUntilRequested()
        await client.complete()
        _ = try await nextTask.value
        #expect(await client.requestCount == 2)
    }

    @Test("La vigencia empieza al recibir los datos, no al iniciar la petición")
    func lifetimeStartsAfterResponse() async throws {
        let client = ControlledHTTPClient()
        let clock = ManualClock()
        let repository = ITunesAlbumRepository(client: client, cache: AlbumSearchCache(now: { clock.now }))
        let task = Task { try await repository.search(query: "queen") }
        await client.waitUntilRequested()
        clock.advance(by: .seconds(120))
        await client.complete()
        _ = try await task.value

        clock.advance(by: .seconds(179))
        #expect(try await repository.search(query: "queen").count == 1)
        #expect(await client.requestCount == 1)
    }

}

private let albumJSON = Data(#"{"results":[{"collectionId":1,"collectionName":"A Night at the Opera","artistName":"Queen","primaryGenreName":"Rock","trackCount":12,"releaseDate":"1975-11-21T08:00:00Z"}]}"#.utf8)
private let emptyJSON = Data(#"{"results":[]}"#.utf8)

private enum StubResponse: Sendable {
    case success(Data)
    case httpError(Int)
    case offline
}

private enum StubError: Error { case noResponse }

private actor HTTPClientStub: HTTPClient {
    private var responses: [StubResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [StubResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw StubError.noResponse }
        let url = try #require(request.url)
        switch responses.removeFirst() {
        case .success(let data):
            return (data, try makeResponse(url: url, status: 200))
        case .httpError(let status):
            return (Data(), try makeResponse(url: url, status: status))
        case .offline:
            throw URLError(.notConnectedToInternet)
        }
    }
}

private actor ControlledHTTPClient: HTTPClient {
    private var pending: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private(set) var requestCount = 0

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        // Permite completar una petición incluso después de cancelarla.
        await withCheckedContinuation { continuation in
            pending = continuation
            waiter?.resume()
            waiter = nil
        }
        let url = try #require(request.url)
        return (albumJSON, try makeResponse(url: url, status: 200))
    }

    func waitUntilRequested() async {
        guard pending == nil else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func complete() {
        guard let continuation = pending else {
            preconditionFailure("No hay ninguna petición pendiente")
        }
        pending = nil
        continuation.resume()
    }
}

private func makeResponse(url: URL, status: Int) throws -> HTTPURLResponse {
    try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
}
