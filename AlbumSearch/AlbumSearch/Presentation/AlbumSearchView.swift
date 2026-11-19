import SwiftUI

// REQUISITO [UI]: Todas las pantallas se implementan con SwiftUI.
// PENDIENTE [BUS-01, BUS-02, CAN-02]: Campo de búsqueda, lista y cancelación de búsquedas anteriores.
// PENDIENTE [DET-01, DET-02]: Navegar al detalle y mostrar al menos tres campos del álbum.
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

// - Los textos y estilos del sistema son compatibles con VoiceOver y Dynamic Type.
// - El contenido se adapta al espacio disponible, sin tamaños de letra ni alturas fijas.
// - La información no depende del color, de animaciones ni del símbolo decorativo de música.
// Cómo probarlo: activar VoiceOver y leer el título y la descripción. Repetir con el tamaño
// de texto de accesibilidad más grande, en horizontal y en modo oscuro; comprobar que ambos textos se leen completos.
