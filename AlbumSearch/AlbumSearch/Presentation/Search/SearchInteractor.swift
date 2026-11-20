import Foundation
import Observation

// REQUISITO [ARQ]: El Interactor coordina la búsqueda; el Presenter prepara el estado visual.
@MainActor
@Observable

// REQUISITO [CANCELACION]: Un texto nuevo invalida el intento anterior inmediatamente.
final class SearchInteractor {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            invalidateSearch()
        }
    }
    private(set) var requestID = UUID()

    private let searchAlbums: SearchAlbums
    private let presenter: SearchPresenter
    private let debounce: Duration

    init(searchAlbums: SearchAlbums, presenter: SearchPresenter, debounce: Duration = .milliseconds(300)) {
        self.searchAlbums = searchAlbums
        self.presenter = presenter
        self.debounce = debounce
    }

    func retry() {
        invalidateSearch()
    }

    // REQUISITO [CANCELACION]: La tarea que llama a este método puede cancelar todo el flujo.
    // La vista será su dueña con .task(id:); aquí no creamos tareas independientes.
    func search() async {
        guard !Task.isCancelled else { return }
        let id = requestID
        let text = query
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            presenter.presentIdle()
            return
        }
        presenter.presentLoading()
        do {
            let albums = try await fetchAlbums(query: text)
            try Task.checkCancellation()
            guard requestID == id else { return }
            presenter.present(albums: albums)
        } catch {
            present(error: error, for: id)
        }
    }

    private func fetchAlbums(query: String) async throws -> [Album] {
        // El debounce es una decisión para evitar una petición por cada letra, no un requisito.
        try await Task.sleep(for: debounce)
        return try await searchAlbums.execute(query: query)
    }

    // REQUISITO [CANCELACION]: Un error antiguo tampoco puede sustituir la búsqueda actual.
    private func present(error: any Error, for id: UUID) {
        guard requestID == id else { return }
        if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
            presenter.presentIdle()
        } else {
            presenter.present(error: error)
        }
    }
    
    // REQUISITO [CANCELACION]: No dejar resultados de la búsqueda anterior en pantalla.
    private func invalidateSearch() {
        requestID = UUID()
        presenter.presentIdle()
    }
}
