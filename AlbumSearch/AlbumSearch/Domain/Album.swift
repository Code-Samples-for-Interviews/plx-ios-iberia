import Foundation

/// REQUISITO [ARQ]: El modelo de Domain no conoce el formato de la API ni la interfaz.
// Hashable permite representar el destino de navegación como un valor.
struct Album: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let artist: String
    let genre: String
    let trackCount: Int
    let releaseDate: Date?
}
