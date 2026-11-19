# Buscador de álbumes

Prueba técnica de iOS para buscar álbumes en iTunes y consultar su detalle.

La idea es hacerlo sencillo, separar bien las responsabilidades y explicar las decisiones según vayamos avanzando. Vamos por partes, con cambios pequeños que se puedan revisar y defender.

## Qué hay ahora

Tenemos la estructura inicial, una pantalla básica en SwiftUI y la lógica de entrada de la búsqueda en Domain, con sus tests. La pantalla todavía no busca ni hace llamadas a la API.

## Cómo arrancarlo

Necesitamos Xcode 16.4 o superior y un simulador con iOS 18 o superior.

Abrimos `AlbumSearch/AlbumSearch.xcodeproj`, seleccionamos el esquema **AlbumSearch** y ejecutamos en el simulador. Para probar en un dispositivo hay que configurar el equipo de desarrollo y un identificador de la app propio en Xcode.

## Cómo está organizado

Todo está dentro de un único target, separado en estas carpetas:

- **App:** entrada de la aplicación y creación de dependencias.
- **Domain:** modelos, contratos de repositorio y casos de uso.
- **Data:** llamadas a la API y caché.
- **Presentation:** pantallas y lógica de presentación.

Data sigue vacía por ahora. Su archivo `.gitkeep` sirve para que Git conserve la carpeta.

No vamos a modularizar de entrada. Para el tamaño de esta prueba, las carpetas son suficientes. Si más adelante tiene sentido extraer un módulo, lo haremos. Mientras tanto, cuidaremos las dependencias mediante protocolos e inyección por inicializador.

## Búsqueda: Domain

- **Album:** los datos que necesitamos para el listado y el detalle: identificador, título, artista, género, número de pistas y fecha de lanzamiento. La fecha puede no estar disponible.
- **AlbumRepository:** el contrato de búsqueda. Es asíncrono, puede devolver errores y debe respetar la cancelación. La implementación con iTunes vendrá en Data.
- **SearchAlbums:** recibe el texto, quita espacios y saltos de línea de los extremos y lo pasa a minúsculas. Si queda vacío, devuelve una lista vacía sin consultar el repositorio.

La normalización vive en el caso de uso para que la interfaz y la futura caché utilicen la misma query. No cambiamos los espacios interiores ni los acentos.

Comprobamos la cancelación antes y después de consultar el repositorio. Así tampoco devolvemos resultados si una implementación termina la consulta sin atender la cancelación. El debounce y el control de respuestas antiguas de la pantalla se añadirán con la búsqueda en Presentation.

## Tests

En Xcode, seleccionamos el esquema **AlbumSearch** y ejecutamos **Product → Test** o **⌘U**. El target **AlbumSearchTests** usa Swift Testing para probar Domain sin hacer llamadas de red.

Comprobamos búsquedas vacías, normalización, resultados, errores y cancelación antes y durante la consulta. Usamos repositorios de prueba y controlamos cuándo termina una petición; no hay que esperar a la red ni usar pausas para reproducir la cancelación.

## Presentación y navegación

Usaremos **VIP con Coordinator**. La vista muestra el estado, el Interactor coordina la búsqueda, el Presenter prepara lo que se muestra y el Coordinator gestiona la navegación.

Lo iremos añadiendo cuando implementemos cada parte. Ahora mismo solo está la vista inicial.

## Accesibilidad

Cada archivo de interfaz lleva al final un resumen de accesibilidad y cómo probarlo. La idea es que quien toque una vista sepa qué debe respetar y comprobar.

Revisaremos VoiceOver, texto grande, modo oscuro y orientación horizontal. Por ahora están las indicaciones de prueba; queda hacer esas comprobaciones.

## Lo siguiente

1. Integración con iTunes y caché en memoria, con sus tests.
2. Búsqueda con VIP, cancelación y control de respuestas antiguas, incluyendo tests con XCTest.
3. Detalle y navegación con Coordinator.
4. Jobs de GitHub para tests y entrega a TestFlight.

Iremos actualizando este README con las decisiones y las instrucciones de cada tanda. El `.gitignore` deja fuera archivos locales de Xcode, compilaciones y credenciales.
