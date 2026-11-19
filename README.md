# Buscador de álbumes

<!-- REQUISITO [DOC-01, ENT-01]: Entregar código, tests y README con API, ejecución y decisiones. -->

Prueba técnica de iOS para buscar álbumes en iTunes y consultar su detalle.

La idea es hacerlo sencillo, separar bien las responsabilidades y explicar las decisiones según vayamos avanzando. Vamos por partes, con cambios pequeños que se puedan revisar y defender.

## Qué hay ahora

Tenemos Domain y Data con sus tests: la lógica de entrada de búsqueda, la conexión con iTunes y la caché en memoria. La pantalla sigue siendo la inicial; conectaremos la búsqueda cuando añadamos VIP.

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

Comprobamos la cancelación antes y después de consultar el repositorio. Así tampoco devolvemos resultados si una implementación termina la consulta sin atender la cancelación. El debounce y el control de respuestas antiguas de la pantalla se añadirán con la búsqueda en Presentation.

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

En Xcode, seleccionamos el esquema **AlbumSearch** y ejecutamos **Product → Test** o **⌘U**. El target **AlbumSearchTests** usa Swift Testing para probar Domain y Data sin hacer llamadas de red.

Comprobamos búsquedas vacías, normalización, resultados, errores y cancelación antes y durante la consulta. Usamos repositorios de prueba y controlamos cuándo termina una petición; no hay que esperar a la red ni usar pausas para reproducir la cancelación. En Data también comprobamos la petición, el mapeo, el uso y la expiración de la caché, sus límites y que no guarde errores o respuestas canceladas. La caché tiene además sus propias pruebas de capacidad y cancelación al leer o guardar.

## Presentación y navegación

Usaremos **VIP con Coordinator**. La vista muestra el estado, el Interactor coordina la búsqueda, el Presenter prepara lo que se muestra y el Coordinator gestiona la navegación.

Lo iremos añadiendo cuando implementemos cada parte. Ahora mismo solo está la vista inicial.

## Accesibilidad

Cada archivo de interfaz lleva al final un resumen de accesibilidad y cómo probarlo. La idea es que quien toque una vista sepa qué debe respetar y comprobar.

Revisaremos VoiceOver, texto grande, modo oscuro y orientación horizontal. Por ahora están las indicaciones de prueba; queda hacer esas comprobaciones.

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
| API-01 | Consumir una API pública | Data consulta iTunes; conectar la pantalla está pendiente. |
| UI-01 | Pantallas en SwiftUI | La pantalla inicial usa SwiftUI; faltan búsqueda y detalle. |
| BUS-01 | Campo de texto para buscar | Pendiente. |
| BUS-02 | Mostrar resultados en una lista | Pendiente. |
| CAN-01 | Lógica asíncrona que respete la cancelación | Implementada y probada en Domain y Data. |
| CAN-02 | Cancelar la búsqueda anterior y evitar resultados antiguos | Pendiente en Presentation. |
| DET-01 | Navegar al seleccionar un resultado | Pendiente. |
| DET-02 | Mostrar al menos tres campos en el detalle | Pendiente; el modelo ya contiene los datos. |
| CACHE-01 | Caché en memoria por query | Implementada. |
| CACHE-02 | Vigencia limitada | Implementada; tres minutos es nuestra elección. |
| CACHE-03 | Caché válida sin llamada de red | Implementado y probado. |
| CACHE-04 | Renovar desde red cuando caduque | Implementado y probado. |
| CACHE-05 | Persistencia en disco (opcional) | No implementada; la caché en memoria cubre la prueba. |
| TEST-01 | Tests de Domain con repositorios de prueba | Implementados. |
| TEST-02 | Tests de Data sobre caché | Implementados. |
| TEST-04 | Tests de Presentation (opcionales, valorados) | Pendientes; se harán con XCTest. |
| ENT-01 | Repositorio con código y tests | Código y pruebas incluidos. |
| DOC-01 | README con API, ejecución y decisiones | Se actualiza con cada tanda. |
| ARQ-02 | VIP con Coordinator (petición propia) | Pendiente. |
| DIS-01 | SOLID e inyección de dependencias (petición propia) | Contratos e inyección en Domain y Data; se mantendrán en Presentation. |
| TEST-03 | Swift Testing y XCTest (petición propia) | Swift Testing implementado; XCTest pendiente. |
| A11Y-01 | Accesibilidad y resumen al pie de cada vista (petición propia) | Resúmenes incluidos en la pantalla inicial; faltan las nuevas vistas y las comprobaciones. |
| CI-01 | Jobs de tests y entrega a TestFlight (petición propia) | Pendiente. |
| SWIFT-01 | Swift 6 (perfil) | Configurado en Debug y Release. |

<!-- PENDIENTE [TEST-04]: Marcar los tests de Presentation cuando se añadan. -->
<!-- PENDIENTE PROPIO [CI-01]: Marcar los jobs y su dependencia cuando se implemente el workflow. -->

## Lo siguiente

1. Búsqueda con VIP, cancelación y control de respuestas antiguas, incluyendo tests con XCTest.
2. Detalle y navegación con Coordinator.
3. Jobs de GitHub para tests y entrega a TestFlight.

Iremos actualizando este README con las decisiones y las instrucciones de cada tanda. El `.gitignore` deja fuera archivos locales de Xcode, compilaciones y credenciales.
