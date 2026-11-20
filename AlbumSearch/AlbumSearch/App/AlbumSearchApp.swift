import SwiftUI

@main
struct AlbumSearchApp: App {
    @State private var coordinator = AlbumCoordinator()
    @State private var presenter: SearchPresenter
    @State private var interactor: SearchInteractor

    // REQUISITO [ARQ]: La app crea y conecta las dependencias mediante inicializadores.
    init() {
        let presenter = SearchPresenter()
        let searchAlbums = SearchAlbums(repository: ITunesAlbumRepository())
        _presenter = State(initialValue: presenter)
        _interactor = State(initialValue: SearchInteractor(searchAlbums: searchAlbums, presenter: presenter))
    }

    var body: some Scene {
        WindowGroup {
            AlbumNavigationView(coordinator: coordinator, interactor: interactor, presenter: presenter)
        }
    }
}

// Resumen de accesibilidad y cómo comprobarla.
// - La escena respeta el tamaño de texto y la apariencia elegidos por el usuario.
// - Las comprobaciones de búsqueda, detalle y navegación están al pie de sus respectivas vistas.
// Cómo probarlo: abrir con VoiceOver y un tamaño de texto de accesibilidad para comprobar que la búsqueda es accesible.
