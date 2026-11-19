import Foundation

// REQUISITO [ABASTRACCION]: El caso de uso pertenece a Domain y trabaja con un repositorio abstracto.
struct SearchAlbums: Sendable {
    private let repository: any AlbumRepository

    // Inyección por inicializador para sustituir el repositorio en tests.
    init(repository: any AlbumRepository) {
        self.repository = repository
    }

    // REQUISITO [CANCELACION]: La búsqueda comprueba la cancelación antes y después del repositorio.
    func execute(query: String) async throws -> [Album] {
        try Task.checkCancellation()

        // Normalizar aquí permite compartir la misma query entre interfaz y caché.
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        let albums = try await repository.search(query: normalizedQuery)
        // Una dependencia puede terminar aunque se haya cancelado la tarea.
        try Task.checkCancellation()
        return albums
    }
}
