import Foundation

// Separar el transporte permite inyectar un cliente de prueba.
protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

enum HTTPError: Error, Equatable {
    case invalidResponse
    case statusCode(Int)
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init() {
        // AlbumSearchCache controla la vigencia, evitamos una segunda caché HTTP.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
    }

    // REQUISITO [CANCELACION]: Esperar esta llamada conserva la cancelación de la tarea de búsqueda.
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        return (data, response)
    }
}
