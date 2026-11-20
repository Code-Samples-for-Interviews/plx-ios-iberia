import SwiftUI

struct AlbumSearchView: View {
    @Bindable var interactor: SearchInteractor
    let presenter: SearchPresenter
    let onSelect: @MainActor (Album) -> Void

    var body: some View {
        List {
            content
        }
        .navigationTitle("Buscador de álbumes")
        // REQUISITO [BUSQUEDA]: Campo de texto que comunica la búsqueda al Interactor.
        .searchable(text: $interactor.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Artista o álbum")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .scrollDismissesKeyboard(.interactively)
        // REQUISITO [CANCELACION]: SwiftUI cancela la tarea anterior al cambiar el intento o desaparecer la vista.
        .task(id: interactor.requestID) {
            await interactor.search()
        }
        // Elemento accesible. Anuncia resultados y errores sin mover el foco del usuario.
        .onChange(of: presenter.state) { _, state in
            announce(state)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.state {
        case .idle:
            ContentUnavailableView("Busca un álbum",
                                   systemImage: "magnifyingglass",
                                   description: Text("Escribe un artista o un álbum para buscar en iTunes."))
        case .loading:
            ProgressView("Buscando álbumes…")
                .frame(maxWidth: .infinity)
        case .loaded(let albums):
            // REQUISITO [LISTADO]: Mostrar los resultados en una lista.
            ForEach(albums) { album in
                albumButton(album)
            }
        case .empty:
            ContentUnavailableView("No hay resultados",
                                   systemImage: "music.note",
                                   description: Text("Prueba con otro artista o álbum."))
        case .failed(let message):
            errorContent(message)
        }
    }

    // REQUISITO [NAVEGACION]: La selección se comunica al Coordinator mediante esta acción.
    private func albumButton(_ album: Album) -> some View {
        Button {
            onSelect(album)
        } label: {
            HStack {
                albumRow(album)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Muestra los detalles del álbum")
    }

    private func albumRow(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(album.title)
                .font(.headline)
            Text(album.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func errorContent(_ message: String) -> some View {
        ContentUnavailableView {
            Label("No se ha podido buscar", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Reintentar") {
                interactor.retry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func announce(_ state: SearchPresenter.State) {
        let message: String
        switch state {
        case .loaded(let albums):
            message = albums.count == 1 ? "Un álbum encontrado." : "\(albums.count) álbumes encontrados."
        case .empty:
            message = "No se han encontrado álbumes."
        case .failed(let errorMessage):
            message = errorMessage
        case .idle, .loading:
            return
        }
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview {
    let presenter = SearchPresenter()
    let interactor = SearchInteractor(searchAlbums: SearchAlbums(repository: PreviewAlbumRepository()), presenter: presenter)
    AlbumNavigationView(coordinator: AlbumCoordinator(), interactor: interactor, presenter: presenter)
}

// Datos de muestra para usar la preview sin depender de la red.
private struct PreviewAlbumRepository: AlbumRepository {
    func search(query: String) async throws -> [Album] {
        [Album(id: 1, title: "A Night at the Opera", artist: "Queen", genre: "Rock", trackCount: 12, releaseDate: nil)]
    }
}

// Resumen de accesibilidad y cómo comprobarla.
// - Búsqueda, lista y botón de reintento nativos, compatibles con VoiceOver y ayudas del sistema.
// - Cada fila abre el detalle y agrupa título y artista; la flecha es decorativa. Se anuncian resultados y errores sin cambiar el foco.
// - Fuentes del sistema y texto sin truncar para respetar todos los tamaños de Dynamic Type.
// - Colores del sistema para modo oscuro y contraste aumentado. Ningún estado depende solo del color.
// Cómo probarlo: con VoiceOver, buscar, abrir un resultado y volver al listado. Probar también
// una búsqueda sin resultados y un error con reintento. Repetir con el texto de accesibilidad más grande,
// en horizontal y modo oscuro. Comprobar que todo se puede leer y recorrer con Voice Control y Switch Control.
