import Foundation

struct SearchAlbums: Sendable {
    private let repository: any AlbumRepository

    init(repository: any AlbumRepository) {
        self.repository = repository
    }

    func execute(query: String) async throws -> [Album] {
        try Task.checkCancellation()

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        let albums = try await repository.search(query: normalizedQuery)
        // Una dependencia puede terminar aunque se haya cancelado la tarea.
        try Task.checkCancellation()
        return albums
    }
}
