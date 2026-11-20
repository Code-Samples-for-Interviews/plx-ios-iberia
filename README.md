# Buscador de álbumes

<!-- REQUISITO [DOC-01, ENT-01]: Entregar código, tests y README con API, ejecución y decisiones. -->

Prueba técnica de iOS para buscar álbumes en iTunes y consultar su detalle.

La idea es hacerlo sencillo, separar bien las responsabilidades y explicar las decisiones según vayamos avanzando. Vamos por partes, con cambios pequeños que se puedan revisar y defender.

## Qué hay ahora

La búsqueda ya está conectada: escribimos un artista o un álbum y vemos los resultados de iTunes en una lista. Se muestran los estados de carga, lista vacía y error, con opción de reintentar. El detalle y la navegación con Coordinator son la siguiente tanda.

## Cómo arrancarlo

Necesitamos Xcode 16.4 o superior y un simulador con iOS 18 o superior.

Abrimos `AlbumSearch/AlbumSearch.xcodeproj`, seleccionamos el esquema **AlbumSearch** y ejecutamos en el simulador. Para probar en un dispositivo hay que configurar el equipo de desarrollo y un identificador de la app propio en Xcode.

## Cómo está organizado

Todo está dentro de un único target, separado en estas carpetas:

- **App:** entrada de la aplicación y creación de dependencias.
- **Domain:** modelos, contratos de repositorio y casos de uso.
- **Data:** llamadas a la API y caché.
- **Presentation:** pantallas y lógica de presentación.

No vamos a modularizar de entrada. Para el tamaño de esta prueba, las carpetas son suficientes. Si más adelante tiene sentido extraer un módulo, lo haremos. Mientras tanto, cuidaremos las dependencias mediante protocolos e inyección por inicializador.

## Búsqueda: Domain

- **Album:** los datos que necesitamos para el listado y el detalle: identificador, título, artista, género, número de pistas y fecha de lanzamiento. La fecha puede no estar disponible.
- **AlbumRepository:** el contrato de búsqueda. Es asíncrono, puede devolver errores y debe respetar la cancelación. La implementación con iTunes está en Data.
- **SearchAlbums:** recibe el texto, quita espacios y saltos de línea de los extremos y lo pasa a minúsculas. Si queda vacío, devuelve una lista vacía sin consultar el repositorio.

La normalización vive en el caso de uso para que la interfaz y la caché utilicen la misma query. No cambiamos los espacios interiores ni los acentos.

Comprobamos la cancelación antes y después de consultar el repositorio. Así tampoco devolvemos resultados si una implementación termina la consulta sin atender la cancelación. El Interactor añade el debounce y descarta respuestas antiguas; la vista lo ejecuta dentro de su tarea de búsqueda.

## Datos: iTunes y caché

Usamos la [API pública de iTunes](https://performance-partners.apple.com/search-api). No necesita claves. Buscamos álbumes en la tienda española, con un máximo de 30 resultados por petición. La API también puede devolver singles y EPs.

- **HTTPClient:** el contrato de transporte permite probar Data sin usar la red. La implementación real usa URLSession, HTTPS y un timeout de petición de 15 segundos.
- **ITunesSearchResponse:** adapta el JSON al modelo Album. Los nombres del servicio no salen de Data. Si faltan los campos opcionales, el género indica que no está disponible, el número de pistas queda en 0 y la fecha en nil. En el detalle trataremos ese 0 como dato no disponible.
- **ITunesAlbumRepository:** implementa el contrato de Domain. Su búsqueda solo coordina tres pasos: consultar la caché, pedir datos si hacen falta y guardarlos. La petición HTTP y la decodificación están separadas en métodos propios.
- **AlbumSearchCache:** guarda los resultados y se encarga de su caducidad y del límite de entradas. Es un actor para proteger ese estado; el repositorio no necesita serlo porque no tiene estado mutable propio.

El enunciado pide que los resultados duren un tiempo limitado en caché, por ejemplo entre dos y cinco minutos. Hemos elegido **tres minutos**, configurables al crear AlbumSearchCache. No es una restricción de iTunes: sirve para evitar consultas repetidas sin conservar los datos indefinidamente.

Por ejemplo, si buscamos «queen» otra vez antes de esos tres minutos, reutilizamos el resultado. Después, volvemos a pedirlo. El plazo empieza al guardar los datos, no al iniciar la petición. Si sigue vigente, devolvemos el resultado sin llamar al cliente HTTP; al caducar, consultamos la red y reemplazamos la entrada. Las listas vacías también se guardan. Los errores y las respuestas canceladas no se guardan.

Usamos un reloj monotónico para que un cambio en la hora del dispositivo no afecte a la vigencia. En los tests adelantamos ese reloj sin esperar tres minutos. Las entradas caducadas se limpian al consultar y después de recibir una respuesta; no hay un temporizador de limpieza.

Limitamos la caché a 50 queries. Si se llena, eliminamos la entrada con el vencimiento más próximo. Es un límite sencillo para no acumular búsquedas indefinidamente; no es una política LRU. La sesión no usa URLCache, así mantenemos una sola política de caché.

Por ahora no hay persistencia en disco, datos caducados como alternativa sin conexión ni peticiones compartidas: dos consultas simultáneas sin caché pueden hacer dos llamadas. El actor de la caché protege sus lecturas y escrituras; no gestiona las peticiones de red ni deduplica búsquedas.

## Tests

En Xcode, seleccionamos el esquema **AlbumSearch** y ejecutamos **Product → Test** o **⌘U**. El target **AlbumSearchTests** usa Swift Testing para Domain y Data, y XCTest para Presenter e Interactor. Ninguno de estos tests hace llamadas de red.

Comprobamos búsquedas vacías, normalización, resultados, errores y cancelación antes y durante la consulta. Usamos repositorios de prueba y controlamos cuándo termina una petición; no hay que esperar a la red ni usar pausas para reproducir la cancelación. En Data también comprobamos la petición, el mapeo, el uso y la expiración de la caché, sus límites y que no guarde errores o respuestas canceladas. La caché tiene además sus propias pruebas de capacidad y cancelación al leer o guardar. Los tests del Presenter comprueban los estados de resultados, lista vacía, carga, reinicio y mensajes de error. Los del Interactor fuerzan respuestas fuera de orden, errores antiguos, limpieza del texto, cancelación y reintento.

## Presentación y navegación

Usaremos **VIP con Coordinator**. La vista muestra el estado, el Interactor coordina la búsqueda, el Presenter prepara lo que se muestra y el Coordinator gestiona la navegación.

**SearchPresenter** recibe resultados o errores y prepara un estado: inicial, cargando, con resultados, vacío o con error. Se actualiza en MainActor y no conoce el repositorio ni gestiona tareas.

**SearchInteractor** recibe el texto y ejecuta el caso de uso. Espera 300 ms antes de buscar para evitar una petición por letra; este debounce es una decisión nuestra y se puede configurar.

Cada cambio de texto invalida el intento anterior y limpia el estado del Presenter inmediatamente. Antes de presentar el resultado se comprueba la cancelación y el identificador del intento. También se descartan los errores antiguos. Cancelar no muestra un error, y se puede reintentar sin cambiar el texto.

La tarea es de la vista mediante `.task(id: interactor.requestID)`: SwiftUI cancela la anterior cuando cambia el identificador o desaparece la pantalla. El Interactor es una operación async y no crea tareas independientes. Sus tests reproducen esa cancelación y también una respuesta tardía que llega sin haberla cancelado.

La app crea el repositorio, el caso de uso, el Presenter y el Interactor. La vista recibe esas piezas, envía el texto al Interactor y dibuja el estado del Presenter. No hace peticiones por su cuenta. La preview usa datos de muestra sin red.

Las filas todavía no navegan. El Coordinator llegará con el detalle en la siguiente tanda.

## Accesibilidad

Cada archivo de interfaz lleva al final un resumen de accesibilidad y cómo probarlo. La idea es que quien toque una vista sepa qué debe respetar y comprobar.

El buscador y la lista usan controles nativos. Cada fila agrupa título y artista, los textos se adaptan a Dynamic Type y se anuncian resultados y errores sin mover el foco. Usamos colores del sistema y no comunicamos estados solo con color.

Se ha comprobado en simulador la búsqueda real, el cambio y la limpieza del texto, el estado sin resultados y la lista con el texto de accesibilidad más grande en modo oscuro. Queda hacer la revisión completa con VoiceOver, Voice Control y Switch Control en dispositivo, además de la orientación horizontal. Repetiremos las comprobaciones cuando cambie la pantalla.

## Cómo marcamos los requisitos

En el código usamos comentarios con una referencia que se puede buscar en Xcode:

- `REQUISITO [ID]`: viene del enunciado de la prueba.
- `REQUISITO PROPIO [ID]`: es algo que hemos pedido para esta propuesta.
- `REQUISITO DEL PERFIL [ID]`: corresponde a una condición técnica del perfil.
- `DECISIÓN`: explica una elección nuestra, como usar tres minutos o limitar la caché a 50 queries.
- `PENDIENTE [ID]`: todavía falta implementarlo; no lo damos por cumplido.

Los comentarios van junto al código que cumple cada punto y, cuando corresponde, junto al test que lo comprueba. Mantendremos estas marcas en las siguientes tandas.

| Referencia | Qué pide | Estado actual |
| --- | --- | --- |
| ARQ-01 | Separar Data, Domain y Presentation | Capas organizadas en carpetas dentro del mismo target. |
| API-01 | Consumir una API pública | Búsqueda de iTunes conectada con la pantalla. |
| UI-01 | Pantallas en SwiftUI | Búsqueda en SwiftUI; detalle pendiente. |
| BUS-01 | Campo de texto para buscar | Implementado con searchable. |
| BUS-02 | Mostrar resultados en una lista | Implementado con List y ForEach. |
| CAN-01 | Lógica asíncrona que respete la cancelación | Implementada y probada en Domain, Data e Interactor. |
| CAN-02 | Cancelar la búsqueda anterior y evitar resultados antiguos | Tarea de SwiftUI conectada con el identificador de cada intento; comprobaciones en Interactor. |
| DET-01 | Navegar al seleccionar un resultado | Pendiente. |
| DET-02 | Mostrar al menos tres campos en el detalle | Pendiente; el modelo ya contiene los datos. |
| CACHE-01 | Caché en memoria por query | Implementada. |
| CACHE-02 | Vigencia limitada | Implementada; tres minutos es nuestra elección. |
| CACHE-03 | Caché válida sin llamada de red | Implementado y probado. |
| CACHE-04 | Renovar desde red cuando caduque | Implementado y probado. |
| CACHE-05 | Persistencia en disco (opcional) | No implementada; la caché en memoria cubre la prueba. |
| TEST-01 | Tests de Domain con repositorios de prueba | Implementados. |
| TEST-02 | Tests de Data sobre caché | Implementados. |
| TEST-04 | Tests de Presentation (opcionales, valorados) | Presenter e Interactor probados con XCTest. |
| ENT-01 | Repositorio con código y tests | Código y pruebas incluidos. |
| DOC-01 | README con API, ejecución y decisiones | Se actualiza con cada tanda. |
| ARQ-02 | VIP con Coordinator (petición propia) | VIP conectado; Coordinator pendiente con el detalle. |
| DIS-01 | SOLID e inyección de dependencias (petición propia) | Contratos en Domain y Data; Interactor recibe caso de uso y Presenter por inicializador. |
| TEST-03 | Swift Testing y XCTest (petición propia) | Ambos frameworks incluidos. |
| A11Y-01 | Accesibilidad y resumen al pie de cada vista (petición propia) | Medidas y resumen de búsqueda incluidos; detalle y auditoría completa pendientes. |
| CI-01 | Jobs de tests y entrega a TestFlight (petición propia) | Pendiente. |
| SWIFT-01 | Swift 6 (perfil) | Configurado en Debug y Release. |

<!-- REQUISITO [TEST]: Presenter e Interactor tienen tests de XCTest. -->
<!-- PENDIENTE PROPIO [CI-01]: Marcar los jobs y su dependencia cuando se implemente el workflow. -->

## Lo siguiente

1. Detalle y navegación con Coordinator.
2. Jobs de GitHub para tests y entrega a TestFlight.

Iremos actualizando este README con las decisiones y las instrucciones de cada tanda. El `.gitignore` deja fuera archivos locales de Xcode, compilaciones y credenciales.
