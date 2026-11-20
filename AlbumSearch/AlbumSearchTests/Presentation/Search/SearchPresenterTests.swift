import Foundation
import XCTest
@testable import AlbumSearch

// REQUISITO [TEST]: Añadir tests de Presentation, opcionales y valorados en el enunciado. Usode XCTEst en lugar de swift test a propósito.
@MainActor
final class SearchPresenterTests: XCTestCase {
    func testEmptyResultsHaveTheirOwnState() async {
        let presenter = SearchPresenter()
        presenter.present(albums: [])

        XCTAssertEqual(presenter.state, .empty)
    }

    func testNonEmptyResultsPreserveAlbums() async {
        let presenter = SearchPresenter()
        presenter.present(albums: [sampleAlbum])

        XCTAssertEqual(presenter.state, .loaded([sampleAlbum]))
    }

    func testStartingAnotherSearchClearsPreviousResults() async {
        let presenter = SearchPresenter()
        XCTAssertEqual(presenter.state, .idle)
        presenter.present(albums: [sampleAlbum])
        presenter.presentLoading()

        XCTAssertEqual(presenter.state, .loading)
    }

    func testReturningToIdleClearsTheError() async {
        let presenter = SearchPresenter()
        presenter.present(error: UnexpectedError.invalidResponse)
        presenter.presentIdle()

        XCTAssertEqual(presenter.state, .idle)
    }

    func testConnectionErrorsSuggestCheckingTheConnection() async {
        for code in [URLError.notConnectedToInternet, .networkConnectionLost, .timedOut] {
            let presenter = SearchPresenter()
            presenter.present(error: URLError(code))

            XCTAssertEqual(presenter.state, .failed(
                "No hemos podido conectar con iTunes. Comprueba tu conexión y vuelve a intentarlo."
            ))
        }
    }

    func testUnexpectedErrorsHaveAGenericMessage() async {
        let presenter = SearchPresenter()
        presenter.present(error: UnexpectedError.invalidResponse)

        XCTAssertEqual(presenter.state, .failed(
            "No se ha podido completar la búsqueda. Inténtalo de nuevo."
        ))
    }
}

private let sampleAlbum = Album(
    id: 1,
    title: "A Night at the Opera",
    artist: "Queen",
    genre: "Rock",
    trackCount: 12,
    releaseDate: nil
)

private enum UnexpectedError: Error {
    case invalidResponse
}
