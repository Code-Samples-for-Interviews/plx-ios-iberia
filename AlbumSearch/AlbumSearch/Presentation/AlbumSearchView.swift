import SwiftUI

struct AlbumSearchView: View {
    var body: some View {
        ContentUnavailableView(
            "Buscador de álbumes",
            systemImage: "music.note",
            description: Text("Encuentra tu próximo álbum.")
        )
    }
}

#Preview {
    AlbumSearchView()
}

// Resumen de accesibilidad:
// - Los textos y estilos del sistema son compatibles con VoiceOver y Dynamic Type.
// - El contenido se adapta al espacio disponible, sin tamaños de letra ni alturas fijas.
// - La información no depende del color, de animaciones ni del símbolo decorativo de música.
// Cómo probarlo: activar VoiceOver y leer el título y la descripción. Repetir con el tamaño
// de texto de accesibilidad más grande, en horizontal y en modo oscuro; comprobar que ambos textos se leen completos.
