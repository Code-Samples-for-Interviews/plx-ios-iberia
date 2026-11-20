import SwiftUI

// REQUISITO [UI]: El contenedor de navegación también está implementado con SwiftUI.
struct AlbumNavigationView: View {
    @Bindable var coordinator: AlbumCoordinator
    let interactor: SearchInteractor
    let presenter: SearchPresenter

    var body: some View {
        // REQUISITO [NAVEGACION]: El Coordinator controla el estado del NavigationStack.
        NavigationStack(path: $coordinator.path) {
            AlbumSearchView(interactor: interactor, presenter: presenter, onSelect: coordinator.showDetail)
                .navigationDestination(for: Album.self) { album in
                    AlbumDetailView(album: album)
                }
        }
    }
}

// Resumen de accesibilidad y cómo comprobarla.
// - Usa la navegación y el botón de volver del sistema, con su semántica accesible.
// - Las comprobaciones de cada pantalla están al pie de AlbumSearchView y AlbumDetailView.
// Cómo probarlo: con VoiceOver, abrir un resultado y volver al listado. Comprobar también
// el gesto de volver y que el texto de búsqueda se conserva. Revisar el foco al regresar.
