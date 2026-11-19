import Foundation

// REQUISITO [ARQ]: Los nombres y el formato de iTunes se quedan en Data; se convierten a Album.
struct ITunesSearchResponse: Decodable {
    let results: [AlbumDTO]

    struct AlbumDTO: Decodable {
        let collectionId: Int
        let collectionName: String
        let artistName: String
        let primaryGenreName: String?
        let trackCount: Int?
        let releaseDate: String?

        func album() -> Album {
            Album(
                id: collectionId,
                title: collectionName,
                artist: artistName,
                genre: primaryGenreName ?? "Género no disponible",
                trackCount: trackCount ?? 0,
                releaseDate: releaseDate.flatMap { ISO8601DateFormatter().date(from: $0) }
            )
        }
    }
}
