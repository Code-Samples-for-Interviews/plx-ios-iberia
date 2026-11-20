import SwiftUI

@main
struct AlbumSearchApp: App {
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
            AlbumSearchView(interactor: interactor, presenter: presenter)
        }
    }
}

// Resumen de accesibilidad y cómo comprobarla.
// - La escena respeta el tamaño de texto y la apariencia elegidos por el usuario.
// - El comportamiento de la pantalla se explica al final de AlbumSearchView.
// Cómo probarlo: abrir con VoiceOver y un tamaño de texto de accesibilidad para comprobar que la búsqueda es accesible.
