import Foundation
import Testing

// REQUISITO PROPIO [TEXTOS]: El catálogo resuelve el plural de los anuncios accesibles.
@Suite("Textos de búsqueda")
struct SearchLocalizationTests {
    @Test("El anuncio usa el singular y el plural del catálogo en español")
    func resultsAnnouncementUsesCatalogPluralForms() {
        let examples = [
            (0, "0 álbumes encontrados."),
            (1, "Un álbum encontrado."),
            (2, "2 álbumes encontrados.")
        ]
        for (count, expected) in examples {
            let message = String(localized: "search.results_count \(count)", locale: Locale(identifier: "es"))
            #expect(message == expected)
        }
    }
}
