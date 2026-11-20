import Foundation

struct ITunesAlbumRepository: AlbumRepository {
    private let client: any HTTPClient
    private let cache: AlbumSearchCache

    init(
        client: any HTTPClient = URLSessionHTTPClient(),
        cache: AlbumSearchCache = AlbumSearchCache()
    ) {
        self.client = client
        self.cache = cache
    }

    func search(query: String) async throws -> [Album] {
        let cached = try await cache.albums(for: query)
        try Task.checkCancellation()
        // REQUISITO [CACHE]: Un resultado cacheado válido se devuelve sin llamar a la red.
        if let cached {
            return cached
        }

        // REQUISITO [CACHE]: Si no hay caché válida, obtener el dato de red y actualizar la entrada.
        let albums = try await fetchAlbums(query: query)
        try await cache.store(albums, for: query)
        try Task.checkCancellation()
        return albums
    }

    // REQUISITO [CANCELACION]: Una respuesta recibida después de cancelar no continúa el flujo.
    private func fetchAlbums(query: String) async throws -> [Album] {
        let request = try makeRequest(query: query)
        let (data, response) = try await client.data(for: request)
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPError.statusCode(response.statusCode)
        }
        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return decoded.results.map { $0.album() }
    }

    // REQUISITO [API]: Consumir una API pública; la elegida es la búsqueda de álbumes de iTunes.
    private func makeRequest(query: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "country", value: "es"),
            URLQueryItem(name: "limit", value: "30")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        return URLRequest(url: url)
    }
}
