# Buscador de álbumes

Prueba técnica de iOS para buscar álbumes en iTunes y consultar su detalle.

La idea es hacerlo sencillo, separar bien las responsabilidades y explicar las decisiones según vayamos avanzando. Vamos por partes, con cambios pequeños que se puedan revisar y defender.

## Qué hay ahora

De momento tenemos la estructura inicial y una pantalla básica en SwiftUI. El proyecto compila, pero todavía no hace búsquedas ni llamadas a la API.

## Cómo arrancarlo

Necesitamos Xcode 16.4 o superior y un simulador con iOS 18 o superior.

Abrimos `AlbumSearch/AlbumSearch.xcodeproj`, seleccionamos el esquema **AlbumSearch** y ejecutamos en el simulador. Para probar en un dispositivo hay que configurar el equipo de desarrollo y un identificador de la app propio en Xcode.

## Cómo está organizado

Todo está dentro de un único target, separado en estas carpetas:

- **App:** entrada de la aplicación y creación de dependencias.
- **Domain:** modelos, contratos de repositorio y casos de uso.
- **Data:** llamadas a la API y caché.
- **Presentation:** pantallas y lógica de presentación.

Domain y Data están vacías por ahora. Los archivos `.gitkeep` sirven para que Git conserve esas carpetas.

No vamos a modularizar de entrada. Para el tamaño de esta prueba, las carpetas son suficientes. Si más adelante tiene sentido extraer un módulo, lo haremos. Mientras tanto, cuidaremos las dependencias mediante protocolos e inyección por inicializador.

## Presentación y navegación

Usaremos **VIP con Coordinator**. La vista muestra el estado, el Interactor coordina la búsqueda, el Presenter prepara lo que se muestra y el Coordinator gestiona la navegación.

Lo iremos añadiendo cuando implementemos cada parte. Ahora mismo solo está la vista inicial.

## Accesibilidad

Cada archivo de interfaz lleva al final un resumen de accesibilidad y cómo probarlo. La idea es que quien toque una vista sepa qué debe respetar y comprobar.

Revisaremos VoiceOver, texto grande, modo oscuro y orientación horizontal. Por ahora están las indicaciones de prueba; queda hacer esas comprobaciones.

## Lo siguiente

1. Modelo, contrato de repositorio y caso de uso, con tests de Swift Testing.
2. Integración con iTunes y caché en memoria, con sus tests.
3. Búsqueda con VIP, cancelación y control de respuestas antiguas, incluyendo tests con XCTest.
4. Detalle y navegación con Coordinator.
5. Jobs de GitHub para tests y entrega a TestFlight.

Iremos actualizando este README con las decisiones y las instrucciones de cada tanda. Este primer cambio incluye el `.gitignore` para dejar fuera archivos locales de Xcode, compilaciones y credenciales.
