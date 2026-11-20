import Foundation
import XCTest
@testable import AlbumSearch

// REQUISITO [TEST]: Tests de Presentation con XCTest y repositorios de prueba.
// REQUISITO [CANCELACION]: Controlar el orden de las respuestas sin red ni pausas reales.
@MainActor
final class SearchInteractorTests: XCTestCase {
    func testEmptyQueriesDoNotReachRepository() async {
        for query in ["", "   ", "\n\t"] {
            let (interactor, presenter, repository) = makeSearch()
            interactor.query = query
            await interactor.search()

            XCTAssertEqual(presenter.state, .idle)
            let count = await repository.requestCount
            XCTAssertEqual(count, 0)
        }
    }

    func testLoadingThenResults() async {
        let (interactor, presenter, repository) = makeSearch()
        let task = await startSearch("queen", interactor: interactor, repository: repository)
        XCTAssertEqual(presenter.state, .loading)

        await repository.complete("queen", with: .success([sampleAlbum]))
        await task.value

        XCTAssertEqual(presenter.state, .loaded([sampleAlbum]))
    }

    func testOlderResponseCannotReplaceNewerResults() async {
        for cancelOldTask in [false, true] {
            await assertOldResponseIsIgnored(.success([sampleAlbum]), cancelOldTask: cancelOldTask)
        }
    }

    func testOlderErrorCannotReplaceNewerResults() async {
        await assertOldResponseIsIgnored(.failure(RepositoryError.unavailable), cancelOldTask: false)
    }

    func testClearingInputRejectsPendingResults() async {
        let (interactor, presenter, repository) = makeSearch()
        let task = await startSearch("queen", interactor: interactor, repository: repository)
        interactor.query = ""
        XCTAssertEqual(presenter.state, .idle)

        await repository.complete("queen", with: .success([sampleAlbum]))
        await task.value

        XCTAssertEqual(presenter.state, .idle)
    }

    func testCancellationDuringRequestDoesNotShowError() async {
        let (interactor, presenter, repository) = makeSearch()
        let task = await startSearch("queen", interactor: interactor, repository: repository)
        task.cancel()
        await repository.complete("queen", with: .success([sampleAlbum]))
        await task.value

        XCTAssertEqual(presenter.state, .idle)
    }

    func testCancelledDebounceDoesNotReachRepository() async {
        let (interactor, presenter, repository) = makeSearch(debounce: .milliseconds(300))
        interactor.query = "queen"
        // La tarea hereda MainActor; la cancelamos antes de cederle la ejecución.
        let task = Task { await interactor.search() }
        task.cancel()
        await task.value

        XCTAssertEqual(presenter.state, .idle)
        let count = await repository.requestCount
        XCTAssertEqual(count, 0)
    }

    func testAlreadyCancelledTaskDoesNotChangePresentedResults() async {
        let (interactor, presenter, repository) = makeSearch()
        interactor.query = "queen"
        presenter.present(albums: [sampleAlbum])
        let task = Task { await interactor.search() }
        task.cancel()
        await task.value

        XCTAssertEqual(presenter.state, .loaded([sampleAlbum]))
        let count = await repository.requestCount
        XCTAssertEqual(count, 0)
    }

    func testRetryAfterFailureKeepsQueryAndStartsAnotherAttempt() async {
        let (interactor, presenter, repository) = makeSearch()
        let task = await startSearch("queen", interactor: interactor, repository: repository)
        await repository.complete("queen", with: .failure(RepositoryError.unavailable))
        await task.value
        guard case .failed = presenter.state else {
            XCTFail("Se esperaba un estado de error")
            return
        }

        let previousID = interactor.requestID
        interactor.retry()
        XCTAssertNotEqual(interactor.requestID, previousID)
        XCTAssertEqual(interactor.query, "queen")
        let retryTask = await startSearch("queen", interactor: interactor, repository: repository)
        await repository.complete("queen", with: .success([sampleAlbum]))
        await retryTask.value

        XCTAssertEqual(presenter.state, .loaded([sampleAlbum]))
    }

    private func assertOldResponseIsIgnored(
        _ oldResult: Result<[Album], any Error>,
        cancelOldTask: Bool
    ) async {
        let (interactor, presenter, repository) = makeSearch()
        let oldTask = await startSearch("queen", interactor: interactor, repository: repository)
        let previousID = interactor.requestID
        interactor.query = "adele"
        XCTAssertNotEqual(interactor.requestID, previousID)
        XCTAssertEqual(presenter.state, .idle)
        if cancelOldTask { oldTask.cancel() }

        let newTask = await startSearch("adele", interactor: interactor, repository: repository)
        await repository.complete("adele", with: .success([]))
        await newTask.value
        await repository.complete("queen", with: oldResult)
        await oldTask.value

        XCTAssertEqual(presenter.state, .empty)
    }

    private func makeSearch(debounce: Duration = .zero) -> (SearchInteractor, SearchPresenter, ControlledRepository) {
        let repository = ControlledRepository()
        let presenter = SearchPresenter()
        let interactor = SearchInteractor(
            searchAlbums: SearchAlbums(repository: repository),
            presenter: presenter,
            debounce: debounce
        )
        return (interactor, presenter, repository)
    }

    private func startSearch(
        _ query: String,
        interactor: SearchInteractor,
        repository: ControlledRepository
    ) async -> Task<Void, Never> {
        interactor.query = query
        let task = Task { await interactor.search() }
        await repository.waitUntilRequested(query)
        return task
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

private enum RepositoryError: Error {
    case unavailable
}

private actor ControlledRepository: AlbumRepository {
    private var pending: [String: CheckedContinuation<[Album], any Error>] = [:]
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    private(set) var requestCount = 0

    func search(query: String) async throws -> [Album] {
        requestCount += 1
        // Ignora la cancelación a propósito: el test decide cuándo llega la respuesta antigua.
        return try await withCheckedThrowingContinuation { continuation in
            pending[query] = continuation
            waiters.removeValue(forKey: query)?.resume()
        }
    }

    func waitUntilRequested(_ query: String) async {
        guard pending[query] == nil else { return }
        await withCheckedContinuation { waiters[query] = $0 }
    }

    func complete(_ query: String, with result: Result<[Album], any Error>) {
        guard let continuation = pending.removeValue(forKey: query) else {
            preconditionFailure("No hay una búsqueda pendiente para \(query)")
        }
        continuation.resume(with: result)
    }
}
