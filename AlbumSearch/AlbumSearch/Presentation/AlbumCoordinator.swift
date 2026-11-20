import Observation

// REQUISITO [NAVEGACION]: Centralizar la navegación al detalle del álbum seleccionado.
@MainActor
@Observable
final class AlbumCoordinator {
    var path: [Album] = []

    func showDetail(_ album: Album) {
        // Solo hay un nivel de detalle; otra selección sustituye el destino anterior.
        path = [album]
    }
}
