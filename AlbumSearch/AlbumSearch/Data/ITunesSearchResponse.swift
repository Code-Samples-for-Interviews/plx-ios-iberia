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
                genre: primaryGenreName ?? Strings.unavailableGenre,
                trackCount: trackCount ?? 0,
                releaseDate: releaseDate.flatMap { ISO8601DateFormatter().date(from: $0) }
            )
        }
    }
}

private enum Strings {
    static var unavailableGenre: String { String(localized: "album.genre_unavailable") }
}
