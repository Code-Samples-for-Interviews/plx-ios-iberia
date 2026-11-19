/// REQUISITO [ARQ]: Domain define el contrato que implementa Data.
/// Recibe una búsqueda normalizada: sin espacios en los extremos y en minúsculas.
/// Cada implementación debe propagar los errores y respetar la cancelación de la tarea.
protocol AlbumRepository: Sendable {
    func search(query: String) async throws -> [Album]
}
