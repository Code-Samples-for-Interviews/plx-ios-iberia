# Buscador de álbumes

<!-- REQUISITO [DOC-01, ENT-01]: Entregar código, tests y README con API, ejecución y decisiones. -->

Prueba técnica de iOS para buscar álbumes en iTunes y consultar su detalle.

La idea es hacerlo sencillo, separar bien las responsabilidades y explicar las decisiones según vayamos avanzando. Vamos por partes, con cambios pequeños que se puedan revisar y defender.

## Qué hay ahora

La búsqueda ya está conectada: escribimos un artista o un álbum y vemos los resultados de iTunes en una lista. Se muestran los estados de carga, lista vacía y error, con opción de reintentar. Al seleccionar un resultado abrimos su detalle. El Coordinator mantiene el estado de navegación.

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
- **ITunesSearchResponse:** adapta el JSON al modelo Album. Los nombres del servicio no salen de Data. Si faltan los campos opcionales, el género indica que no está disponible, el número de pistas queda en 0 y la fecha en nil. El detalle muestra ese 0 y la fecha ausente como datos no disponibles.
- **ITunesAlbumRepository:** implementa el contrato de Domain. Su búsqueda solo coordina tres pasos: consultar la caché, pedir datos si hacen falta y guardarlos. La petición HTTP y la decodificación están separadas en métodos propios.
- **AlbumSearchCache:** guarda los resultados y se encarga de su caducidad y del límite de entradas. Es un actor para proteger ese estado; el repositorio no necesita serlo porque no tiene estado mutable propio.

El enunciado pide que los resultados duren un tiempo limitado en caché, por ejemplo entre dos y cinco minutos. Hemos elegido **tres minutos**, configurables al crear AlbumSearchCache. No es una restricción de iTunes: sirve para evitar consultas repetidas sin conservar los datos indefinidamente.

Por ejemplo, si buscamos «queen» otra vez antes de esos tres minutos, reutilizamos el resultado. Después, volvemos a pedirlo. El plazo empieza al guardar los datos, no al iniciar la petición. Si sigue vigente, devolvemos el resultado sin llamar al cliente HTTP; al caducar, consultamos la red y reemplazamos la entrada. Las listas vacías también se guardan. Los errores y las respuestas canceladas no se guardan.

Usamos un reloj monotónico para que un cambio en la hora del dispositivo no afecte a la vigencia. En los tests adelantamos ese reloj sin esperar tres minutos. Las entradas caducadas se limpian al consultar y después de recibir una respuesta; no hay un temporizador de limpieza.

Limitamos la caché a 50 queries. Si se llena, eliminamos la entrada con el vencimiento más próximo. Es un límite sencillo para no acumular búsquedas indefinidamente; no es una política LRU. La sesión no usa URLCache, así mantenemos una sola política de caché.

Por ahora no hay persistencia en disco, datos caducados como alternativa sin conexión ni peticiones compartidas: dos consultas simultáneas sin caché pueden hacer dos llamadas. El actor de la caché protege sus lecturas y escrituras; no gestiona las peticiones de red ni deduplica búsquedas.

## Tests

En Xcode, seleccionamos el esquema **AlbumSearch** y ejecutamos **Product → Test** o **⌘U**. El target **AlbumSearchTests** usa Swift Testing para Domain y Data, y XCTest para Presenter, Interactor y Coordinator. Ninguno de estos tests hace llamadas de red.

Comprobamos búsquedas vacías, normalización, resultados, errores y cancelación antes y durante la consulta. Usamos repositorios de prueba y controlamos cuándo termina una petición; no hay que esperar a la red ni usar pausas para reproducir la cancelación. En Data también comprobamos la petición, el mapeo, el uso y la expiración de la caché, sus límites y que no guarde errores o respuestas canceladas. La caché tiene además sus propias pruebas de capacidad y cancelación al leer o guardar. Los tests del Presenter comprueban los estados de resultados, lista vacía, carga, reinicio y mensajes de error. Los del Interactor fuerzan respuestas fuera de orden, errores antiguos, limpieza del texto, cancelación y reintento. Los del Coordinator comprueban el álbum que se abre y que solo haya un nivel de detalle.

## Integración continua

<!-- REQUISITO PROPIO [CI]: Job de tests en GitHub Actions con Swift Testing y XCTest. -->

El workflow `.github/workflows/tests.yml` ejecuta el job **Tests iOS** al abrir o actualizar una pull request y al subir cambios a `main`. También podemos lanzarlo desde **Actions → CI iOS → Run workflow**, cuando el archivo esté en la rama principal.

Usamos `xcodebuild test` con el esquema compartido AlbumSearch. Ese comando compila la app y ejecuta los tests de Swift Testing y XCTest. Si falla la compilación o alguna prueba, el job falla. No necesita certificados ni secretos porque corre en simulador.

El entorno es `macos-15`, Xcode 26.3 y un iPhone 16 con iOS 26.2. Fijamos Xcode y el destino en lugar de depender de la versión predeterminada del runner. Ambos están disponibles en la [imagen de GitHub](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md); habrá que revisar esos valores cuando se actualice el entorno. Usamos la misma versión de Xcode para tests y entrega. Para subir builds, [Apple exige Xcode 26 o superior](https://developer.apple.com/news/upcoming-requirements/?id=04282026a); esto no cambia el mínimo de iOS 18 de la app.

Para repetir las pruebas desde la raíz del repositorio:

```sh
xcodebuild test \
  -project AlbumSearch/AlbumSearch.xcodeproj \
  -scheme AlbumSearch \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.2' \
  CODE_SIGNING_ALLOWED=NO
```

En local hay que tener ese simulador instalado o cambiar el destino por uno disponible. Podemos verlos con `xcodebuild -showdestinations -project AlbumSearch/AlbumSearch.xcodeproj -scheme AlbumSearch`.

Guardamos el `.xcresult` durante siete días como artefacto **resultados-tests-ios**, también si falla alguna prueba. Se descarga desde la ejecución en Actions y se abre con Xcode para revisar los fallos y la cobertura. Si la compilación falla antes de generarlo, el diagnóstico estará en el log del job. Una nueva revisión cancela la ejecución anterior de la misma PR. En `main` no interrumpimos una entrega en curso.

El job está preparado y su configuración se ha validado en local. Falta comprobar su primera ejecución real en GitHub después de subir este commit. Para exigirlo antes de integrar una PR, hay que configurar **Tests iOS** como comprobación obligatoria en las reglas de la rama; el archivo por sí solo no bloquea una integración.

## Entrega a TestFlight

<!-- REQUISITO PROPIO [CI]: Job de entrega dependiente de los tests. -->

El job **Entrega a TestFlight** depende de `tests` mediante `needs`. Se ejecuta en `main`, después de pasar las pruebas, al subir cambios o lanzar el workflow manualmente. En las PRs solo se ejecutan los tests. Mientras la variable del repositorio `TESTFLIGHT_ENABLED` no sea `true`, la entrega se omite y los tests siguen funcionando.

El script `scripts/deliver-testflight.sh` prepara la firma, archiva en Release y sube el archivo con `xcodebuild -exportArchive`. Usamos **firma manual** con un certificado Apple Distribution y un perfil de App Store Connect. Así quedan claras las credenciales necesarias. El proyecto conserva la firma automática para trabajar en Xcode; el script la cambia solo para esa compilación. No añadimos Fastlane ni otra herramienta de distribución.

### Qué hay que configurar

1. Tener una cuenta activa del Apple Developer Program, registrar un Bundle ID propio y crear la app en App Store Connect con ese mismo identificador. El `com.example.AlbumSearch` del proyecto es de ejemplo; el job lo sustituye con `APP_BUNDLE_ID`.
2. Revisar los datos de la app en App Store Connect. El icono ya está incluido y seleccionado en el target. La declaración de cifrado se explica más abajo; hay que revisarla si se añaden librerías o cambia el uso de cifrado.
3. Exportar el certificado **Apple Distribution con su clave privada** como `.p12` protegido con contraseña. Crear y descargar un perfil **App Store Connect** para ese certificado, equipo y Bundle ID; no sirve uno de desarrollo ni Ad Hoc.
4. Crear una clave de equipo de App Store Connect con permisos para subir builds (por ejemplo, App Manager). Guardar su `.p8`, Key ID e Issuer ID. Se usa para autenticar la subida, no sustituye al certificado de firma.
5. En GitHub, crear el environment `testflight`, limitado a `main`, y añadir estas variables y secretos. Crear `TESTFLIGHT_ENABLED` a nivel de **repositorio**, porque decide si el job llega a ejecutarse.

| Tipo | Nombre | Contenido |
| --- | --- | --- |
| Variable del repositorio | `TESTFLIGHT_ENABLED` | `true` cuando esté todo preparado; inicialmente ausente. |
| Variable de `testflight` | `APPLE_TEAM_ID` | Identificador del equipo de Apple Developer. |
| Variable de `testflight` | `APP_BUNDLE_ID` | Bundle ID registrado para la app. |
| Variable de `testflight` | `ASC_KEY_ID` | Key ID de la clave de App Store Connect. |
| Variable de `testflight` | `ASC_ISSUER_ID` | Issuer ID de esa clave de equipo. |
| Secreto de `testflight` | `IOS_CERTIFICATE_BASE64` | Contenido del `.p12` codificado en Base64. |
| Secreto de `testflight` | `IOS_CERTIFICATE_PASSWORD` | Contraseña del `.p12`. |
| Secreto de `testflight` | `IOS_PROFILE_BASE64` | Contenido del `.mobileprovision` codificado en Base64. |
| Secreto de `testflight` | `ASC_PRIVATE_KEY` | Contenido completo del `.p8`, con encabezado, pie y saltos de línea; sin Base64. |

En macOS podemos copiar cada archivo codificado con `base64 -i certificado.p12 | pbcopy` y `base64 -i perfil.mobileprovision | pbcopy`. Para la clave usamos `pbcopy < AuthKey.p8`. Se pegan en los secretos de GitHub; no van en el repositorio ni en el README. La instalación de la firma sigue el [procedimiento de GitHub para runners de macOS](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).

El script crea un llavero temporal y elimina el certificado, el perfil y la clave al terminar, también si falla. Está pensado para runners efímeros de GitHub, no para ejecutarlo en el Mac de trabajo ni en un runner compartido. Si caduca el certificado o el perfil, hay que renovar los secretos correspondientes.

### Icono y configuración de la app

El icono es un disco sencillo, dibujado con círculos. El catálogo incluye un PNG de 1024 × 1024, sin transparencia, y `AppIcon` está seleccionado en Debug y Release. Xcode genera los tamaños necesarios a partir de ese recurso. No añadimos variantes propias para modo oscuro ni una herramienta de diseño al proyecto.

El PNG está versionado: ni la compilación ni el job de entrega necesitan regenerarlo. Para cambiar los colores o el dibujo, editamos `scripts/generate-app-icon.swift` y lo ejecutamos desde la raíz del repositorio con `swift scripts/generate-app-icon.swift`. Solo utiliza frameworks de macOS. Hay que incluir el PNG actualizado en el mismo commit que el script.

Configuramos `ITSAppUsesNonExemptEncryption = NO` en el Info.plist generado. La app solo usa HTTPS mediante URLSession y no incorpora cifrado propio ni librerías de terceros. Según la [documentación de Apple sobre exportación de cifrado](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations), ese uso del cifrado del sistema está exento de aportar documentación de cifrado. La declaración no significa que las conexiones vayan sin cifrar; hay que revisarla si cambia la implementación.

Se ha comprobado un archivo Release para dispositivo **sin firma**: incluye el icono y la declaración como valor booleano. Esto verifica la compilación y los recursos; no sustituye la firma, la validación de Apple ni la primera subida real.

El número de build usa `GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT`, por ejemplo `12.1`; un reintento del mismo run pasa a `12.2`. La versión comercial sigue siendo la del proyecto. Si ya existen builds subidos por otro proceso, hay que comprobar que el número siguiente sea mayor para esa versión y evitar relanzar runs antiguos.

La subida termina cuando Apple acepta el envío. El procesamiento, las preguntas de cumplimiento, la asignación a grupos y una posible revisión para testers externos se consultan en App Store Connect. No publicamos la app en la App Store. Apple explica ese paso en [cómo subir builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

**Estado actual:** workflow y script preparados; validación local de configuración y flujo con comandos simulados. La firma y la subida reales siguen pendientes de cuenta, credenciales y primera ejecución en GitHub. No damos por completado un deploy que todavía no hemos hecho.

## Presentación y navegación

Usamos **VIP con Coordinator**. La vista muestra el estado, el Interactor coordina la búsqueda, el Presenter prepara lo que se muestra y el Coordinator gestiona la navegación.

**SearchPresenter** recibe resultados o errores y prepara un estado: inicial, cargando, con resultados, vacío o con error. Se actualiza en MainActor y no conoce el repositorio ni gestiona tareas.

**SearchInteractor** recibe el texto y ejecuta el caso de uso. Espera 300 ms antes de buscar para evitar una petición por letra; este debounce es una decisión nuestra y se puede configurar.

Cada cambio de texto invalida el intento anterior y limpia el estado del Presenter inmediatamente. Antes de presentar el resultado se comprueba la cancelación y el identificador del intento. También se descartan los errores antiguos. Cancelar no muestra un error, y se puede reintentar sin cambiar el texto.

La tarea es de la vista mediante `.task(id: interactor.requestID)`: SwiftUI cancela la anterior cuando cambia el identificador o desaparece la pantalla. El Interactor es una operación async y no crea tareas independientes. Sus tests reproducen esa cancelación y también una respuesta tardía que llega sin haberla cancelado.

La app crea el repositorio, el caso de uso, el Presenter y el Interactor. La vista recibe esas piezas, envía el texto al Interactor y dibuja el estado del Presenter. No hace peticiones por su cuenta. La preview usa datos de muestra sin red.

**AlbumCoordinator** conserva la ruta y recibe la selección de un álbum. **AlbumNavigationView** contiene el NavigationStack y decide qué pantalla corresponde a ese destino. La búsqueda solo comunica la selección mediante una acción; no construye el detalle.

Solo hay un destino posible, por eso la ruta es una lista de álbumes con un único elemento al abrir el detalle. Album conforma a Hashable, que es lo que necesita NavigationStack para representar sus destinos como valores. El botón de volver del sistema actualiza la ruta.

**AlbumDetailView** muestra título, artista, género, pistas y fecha con los datos que ya teníamos. No hace otra petición y no necesita un Interactor ni un Presenter propios. Los campos se colocan en vertical para dar espacio al texto grande; la fecha respeta el formato regional y se muestra en UTC para conservar el día de lanzamiento.

## Accesibilidad

Cada archivo de interfaz lleva al final un resumen de accesibilidad y cómo probarlo. La idea es que quien toque una vista sepa qué debe respetar y comprobar.

El buscador y la lista usan controles nativos. Cada fila agrupa título y artista y explica que abre el detalle. En el detalle, el título es un encabezado y cada campo agrupa etiqueta y valor. Los textos se adaptan a Dynamic Type y se anuncian resultados y errores sin mover el foco. Usamos colores del sistema y no comunicamos estados solo con color.

Se ha comprobado en simulador la búsqueda real, el cambio y la limpieza del texto y el estado sin resultados. También se ha revisado abrir dos álbumes distintos, volver al listado conservando la búsqueda y leer la lista y el detalle con el texto de accesibilidad más grande en modo oscuro. Queda hacer la revisión completa con VoiceOver, Voice Control y Switch Control en dispositivo, además de la orientación horizontal. Repetiremos las comprobaciones cuando cambie la pantalla.

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
| UI-01 | Pantallas en SwiftUI | Búsqueda, detalle y contenedor de navegación en SwiftUI. |
| BUS-01 | Campo de texto para buscar | Implementado con searchable. |
| BUS-02 | Mostrar resultados en una lista | Implementado con List y ForEach. |
| CAN-01 | Lógica asíncrona que respete la cancelación | Implementada y probada en Domain, Data e Interactor. |
| CAN-02 | Cancelar la búsqueda anterior y evitar resultados antiguos | Tarea de SwiftUI conectada con el identificador de cada intento; comprobaciones en Interactor. |
| DET-01 | Navegar al seleccionar un resultado | Implementado con Coordinator y NavigationStack. |
| DET-02 | Mostrar al menos tres campos en el detalle | Título, artista, género, pistas y fecha. |
| CACHE-01 | Caché en memoria por query | Implementada. |
| CACHE-02 | Vigencia limitada | Implementada; tres minutos es nuestra elección. |
| CACHE-03 | Caché válida sin llamada de red | Implementado y probado. |
| CACHE-04 | Renovar desde red cuando caduque | Implementado y probado. |
| CACHE-05 | Persistencia en disco (opcional) | No implementada; la caché en memoria cubre la prueba. |
| TEST-01 | Tests de Domain con repositorios de prueba | Implementados. |
| TEST-02 | Tests de Data sobre caché | Implementados. |
| TEST-04 | Tests de Presentation (opcionales, valorados) | Presenter, Interactor y Coordinator probados con XCTest. |
| ENT-01 | Repositorio con código y tests | Código y pruebas incluidos. |
| DOC-01 | README con API, ejecución y decisiones | Se actualiza con cada tanda. |
| ARQ-02 | VIP con Coordinator (petición propia) | VIP y Coordinator conectados. |
| DIS-01 | SOLID e inyección de dependencias (petición propia) | Contratos en Domain y Data; Interactor recibe caso de uso y Presenter por inicializador. |
| TEST-03 | Swift Testing y XCTest (petición propia) | Ambos frameworks incluidos. |
| A11Y-01 | Accesibilidad y resumen al pie de cada vista (petición propia) | Medidas y resúmenes incluidos; auditoría completa pendiente. |
| CI-01 | Jobs de tests y entrega a TestFlight (petición propia) | Jobs de tests y entrega preparados; firma y ejecución reales pendientes de configuración. |
| SWIFT-01 | Swift 6 (perfil) | Configurado en Debug y Release. |

<!-- REQUISITO [TEST]: Presenter, Interactor y Coordinator tienen tests de XCTest. -->
<!-- PENDIENTE PROPIO [CI]: Configurar firma y comprobar el flujo real en GitHub. -->

## Lo siguiente

1. Comprobar el job de tests en GitHub.
2. Configurar la firma y comprobar la entrega real a TestFlight.
3. Completar la revisión manual de accesibilidad en dispositivo.

Iremos actualizando este README con las decisiones y las instrucciones de cada tanda. El `.gitignore` deja fuera archivos locales de Xcode, compilaciones y credenciales.
