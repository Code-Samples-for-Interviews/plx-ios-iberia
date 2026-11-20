import SwiftUI

// REQUISITO [UI]: La pantalla de detalle está implementada con SwiftUI.
struct AlbumDetailView: View {
    let album: Album
    @Environment(\.locale) private var locale

    var body: some View {
        // REQUISITO [DETALLE]: Mostrar al menos tres campos del elemento seleccionado.
        List {
            Section {
                Text(album.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
            }
            Section("Información del álbum") {
                field("Artista", value: album.artist)
                field("Género", value: album.genre)
                field("Pistas", value: album.trackCount > 0 ? String(album.trackCount) : "No disponible")
                field("Lanzamiento", value: releaseDateText)
            }
        }
        .navigationTitle("Detalle del álbum")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var releaseDateText: String {
        guard let date = album.releaseDate else { return "No disponible" }
        // Mostrar el día en UTC evita desplazarlo por el huso horario del dispositivo.
        let format = Date.FormatStyle(date: .long, time: .omitted, locale: locale, timeZone: .gmt)
        return date.formatted(format)
    }

    private func field(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        AlbumDetailView(album: Album(
            id: 1, title: "A Night at the Opera", artist: "Queen",
            genre: "Rock", trackCount: 0, releaseDate: nil
        ))
    }
}

// Resumen de accesibilidad y cómo comprobarla.
// - El título del álbum es un encabezado; VoiceOver puede encontrarlo con el rotor de encabezados.
// - Cada campo agrupa su etiqueta y su valor para leerlos juntos.
// - Fuentes del sistema, texto sin truncar y campos en vertical dentro de una lista desplazable.
// - Colores del sistema para modo oscuro y contraste aumentado; no hay información solo visual.
// Cómo probarlo: con VoiceOver, leer todos los campos, navegar por encabezados y activar volver.
// Repetir con el texto de accesibilidad más grande, en horizontal y modo oscuro. Comprobar
// los campos no disponibles y recorrer la pantalla con Voice Control y Switch Control.
