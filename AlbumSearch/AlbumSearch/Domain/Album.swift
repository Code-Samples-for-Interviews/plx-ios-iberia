import Foundation

/// Datos del álbum que necesita la app, sin detalles del formato de la API.
struct Album: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let artist: String
    let genre: String
    let trackCount: Int
    let releaseDate: Date?
}
