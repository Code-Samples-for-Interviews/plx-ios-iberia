import Foundation
import Observation

// El Presenter prepara el estado visual, sin buscar ni gestionar tareas.
// REQUISITO [ARQ]: Esta responsabilidad pertenece a Presentation.
@MainActor
@Observable
final class SearchPresenter {
    enum State: Equatable {
        case idle
        case loading
        case loaded([Album])
        case empty
        case failed(String)
    }

    private(set) var state: State = .idle

    func presentIdle() {
        state = .idle
    }

    func presentLoading() {
        state = .loading
    }

    func present(albums: [Album]) {
        state = albums.isEmpty ? .empty : .loaded(albums)
    }

    func present(error: any Error) {
        state = .failed(message(for: error))
    }

    private func message(for error: any Error) -> String {
        let connectionErrors: [URLError.Code] = [.notConnectedToInternet, .networkConnectionLost, .timedOut]
        if let urlError = error as? URLError, connectionErrors.contains(urlError.code) {
            return Strings.connectionError
        }
        return Strings.unexpectedError
    }
}

private enum Strings {
    static var connectionError: String { String(localized: "search.error.connection") }
    static var unexpectedError: String { String(localized: "search.error.unexpected") }
}
