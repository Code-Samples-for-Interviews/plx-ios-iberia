import SwiftUI

@main
struct AlbumSearchApp: App {
    var body: some Scene {
        WindowGroup {
            AlbumSearchView()
        }
    }
}

// - La escena respeta el tamaño de texto y la apariencia elegidos por el usuario.
// - El comportamiento de la pantalla se explica al final de AlbumSearchView.
// Cómo probarlo: abrir con VoiceOver y un tamaño de texto de accesibilidad; comprobar que se puede leer la pantalla.
