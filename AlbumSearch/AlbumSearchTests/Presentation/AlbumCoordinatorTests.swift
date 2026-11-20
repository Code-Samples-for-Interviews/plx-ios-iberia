import XCTest
@testable import AlbumSearch

// REQUISITO [TEST]: Probar la navegación de Presentation con XCTest.
// REQUISITO [NAVEGACION]: El detalle recibe todos los datos del álbum seleccionado.
@MainActor
final class AlbumCoordinatorTests: XCTestCase {
    func testSelectionOpensTheSelectedAlbumWithItsData() async {
        let coordinator = AlbumCoordinator()
        XCTAssertTrue(coordinator.path.isEmpty)

        coordinator.showDetail(firstAlbum)

        XCTAssertEqual(coordinator.path, [firstAlbum])
    }

    func testAnotherSelectionKeepsOnlyOneDetailDestination() async {
        let coordinator = AlbumCoordinator()
        coordinator.showDetail(firstAlbum)
        coordinator.showDetail(secondAlbum)

        XCTAssertEqual(coordinator.path, [secondAlbum])
    }
}

private let firstAlbum = Album(
    id: 1, title: "A Night at the Opera", artist: "Queen",
    genre: "Rock", trackCount: 12, releaseDate: nil
)

private let secondAlbum = Album(
    id: 2, title: "21", artist: "Adele",
    genre: "Pop", trackCount: 11, releaseDate: nil
)
