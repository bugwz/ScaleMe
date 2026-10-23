<div align="center">

<img src="../../Design/Logo/readme-logo.svg" width="96" height="96" alt="观我 · ScaleMe">

# 观我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![Almacenamiento en el dispositivo](https://img.shields.io/badge/Data-On%20Device-2E8B57)](#data-storage-and-privacy)

Una app nativa de iOS para seguir el peso y la composición corporal

**Observa los cambios de tu cuerpo y sigue tu evolución de salud.**

[简体中文](../../README.md) | [繁體中文](README-zh-Hant.md) | [English](README-en.md) | [日本語](README-ja.md) | [Français](README-fr.md) | [Deutsch](README-de.md) | [**Español**](README-es.md) | [Português](README-pt.md) | [Русский](README-ru.md) | [한국어](README-ko.md)

</div>

观我 (ScaleMe) es una app nativa de iOS para registrar el peso y la composición corporal de personas y familias. Conecta básculas Bluetooth compatibles o introduce mediciones manualmente y consulta el historial y las tendencias por perfil, dispositivo y periodo.

No requiere registrar una cuenta. Los perfiles, ajustes y mediciones se guardan en el dispositivo, sin enviarse a servidores del desarrollador ni disponer de sincronización propia en la nube. El usuario activa el acceso a Salud de Apple y realiza las importaciones y exportaciones de archivos.

<div align="center">

<a href="https://apps.apple.com/app/id6808930548">
  <img src="../../Design/Download/AppStoreQRCode.png" width="100%" alt="Escanea el código QR para descargar ScaleMe en el App Store">
</a>

</div>

## Funciones principales

### Mediciones y registros

- Detectar y asociar básculas Bluetooth compatibles, mostrar el progreso y los datos disponibles del dispositivo y guardar resultados estables.
- Introducir el peso manualmente, seleccionar fecha y hora y añadir, si hace falta, los valores de composición corporal mostrados por el dispositivo, incluidas mediciones anteriores.
- Consultar detalles, reasignar registros a otro perfil o eliminarlos. Los protocolos compatibles pueden leer el historial de la báscula, asociar perfiles y eliminar duplicados.
- Las mediciones en directo se guardan primero en un archivo local antes de convertirse en registros definitivos y activar el envío a Salud habilitado. Si falla el guardado, se muestra el estado sin guardar y una opción para reintentar.

### Perfiles familiares y tendencias

- Crear varios perfiles, gestionar varios dispositivos y consultar los registros de cada persona por separado.
- Elegir y ordenar los indicadores de salud en el inicio, con sus últimos valores, significado y rangos de referencia aplicables.
- Filtrar tendencias por perfil, dispositivo, periodo e indicador, y observar cambios mediante gráficos e historial.
- Widgets de tendencias pequeños, medianos y grandes para la pantalla de inicio, cada uno con ajustes independientes de indicador, periodo, dispositivo, perfil y visualización.

### Gestión de datos y Salud de Apple

- Importar y exportar ajustes y mediciones por separado o juntos mediante JSON, y eliminar datos locales.
- Leer opcionalmente el peso y el porcentaje de grasa corporal de Salud de Apple en el perfil propio, y escribir nuevas mediciones que cumplan los requisitos.
- Los interruptores de sincronización y los permisos del sistema se gestionan por separado. Las mediciones Bluetooth, entradas manuales y tendencias siguen disponibles sin sincronización.

### Interfaz y accesibilidad

- Chino simplificado y tradicional, inglés, japonés, francés, alemán, español, portugués, ruso y coreano, siguiendo el sistema o seleccionando el idioma en la app.
- Temas predeterminado y adaptado a dificultades de percepción del color, con apariencia clara, oscura o del sistema.
- VoiceOver para estados de medición, gráficos, menús y formularios, con adaptación a Dynamic Type y Reducir movimiento. El alcance real se detalla en la [validación de accesibilidad](../Accessibility.md).
- Datos familiares simulados para probar la interfaz sin báscula. Los cambios de registros en este modo no se guardan en los datos de mediciones reales; los datos predefinidos se restauran al reiniciar.

## Compatibilidad de dispositivos

El proyecto implementa el análisis de características estándar Bluetooth SIG de peso y composición corporal, además del análisis de anuncios o sesiones de medición GATT de varios fabricantes. Las funciones y niveles de validación varían según el protocolo; una marca no garantiza compatibilidad con todos sus modelos.

- Detectar un dispositivo, reconocer su nombre o registrar un protocolo no equivale a admitir mediciones.
- Las pruebas con muestras verifican el análisis de datos, no el funcionamiento completo entre un iPhone y una báscula real.
- La medición en directo, composición corporal, lectura del historial y configuración de autenticación dependen del protocolo. Los campos sin confirmar no se guardan como indicadores conocidos.
- Se pueden importar reglas declarativas de comunicación válidas desde archivos JSON locales. La app no descarga protocolos desde direcciones remotas.

Consulta la [matriz de compatibilidad de protocolos](../BluetoothProtocolSupport.md) para conocer capacidades, niveles de validación y fuentes de investigación, y las [reglas de comunicación externas](../ExternalCommunicationRules.md) para el formato de extensión.

## Indicadores y estimaciones

La app distingue los valores originales del dispositivo de los calculados por ella. El peso, la composición corporal del dispositivo, el IMC calculado a partir del perfil y las estimaciones condicionales tienen distintas fuentes y ámbitos de aplicación.

En las básculas de composición corporal reconocidas se priorizan los valores del dispositivo o protocolo. Solo se estiman experimentalmente valores ausentes cuando hay una impedancia principal válida, información del perfil y condiciones de modelo adecuadas. Las básculas que solo miden peso, los registros manuales y las importaciones de Salud no activan estas estimaciones predeterminadas. Sin impedancia principal no se usa el IMC como sustituto para estimar la composición corporal ausente.

Los cálculos se guardan con cada medición, separados de los valores originales. Modificar el perfil no recalcula automáticamente el historial; reasignar un registro a otro perfil sí. Las estimaciones no se escriben en Salud de Apple. Los rangos de edad, supuestos de adaptación a dispositivos y reglas empíricas tienen limitaciones; las estimaciones no son algoritmos oficiales del fabricante ni mediciones clínicas.

La sección de información de datos y las páginas de cálculo de cada indicador ofrecen fórmulas, fuentes y ámbitos de aplicación. Los detalles técnicos están en [datos, sincronización y privacidad](../DataAndPrivacy.md). Los resultados de composición corporal sirven para observar tendencias, no para diagnóstico, tratamiento o decisiones médicas.

<a id="data-storage-and-privacy"></a>

## Almacenamiento y privacidad

### Almacenamiento en el dispositivo

Perfiles, ajustes y mediciones se guardan en archivos JSON versionados dentro del entorno aislado de la app. Los ajustes y registros se almacenan por separado con iOS Complete File Protection. Los secretos de vinculación y autenticación se guardan en el Keychain del sistema.

Los widgets leen una instantánea compacta de tendencias mediante un App Group local. La instantánea se cifra con AES-GCM y las claves se gestionan en un Keychain compartido. Es un intercambio entre la app y su extensión dentro del mismo dispositivo.

La app no incluye cuentas, publicidad ni servicios de envío de datos analíticos. No envía perfiles o mediciones de salud a servidores del desarrollador ni sincroniza estos datos en tiempo real mediante iCloud.

### Transferencias controladas por el usuario

- **Copias de seguridad del sistema**: los archivos de ajustes y mediciones pueden incluirse en las copias del dispositivo que active el usuario. El sistema gestiona la copia y restauración.
- **Salud de Apple**: lectura y escritura desactivadas por defecto, con configuración y autorización necesarias. Las lecturas se importan solo al perfil propio; las escrituras incluyen únicamente nuevas mediciones estables propias de dispositivos reales seleccionados. Historiales importados, registros manuales, datos simulados y estimaciones no se escriben en Salud. Desactivar la sincronización no elimina datos ya escritos o importados.
- **Importación y exportación de archivos**: iniciadas por el usuario. El JSON exportado es texto sin cifrar y puede contener perfiles, información de dispositivos y mediciones. El usuario elige dónde guardarlo y con quién compartirlo.
- **Exportación de diagnósticos**: recopilados y exportados por el usuario; pueden contener identificadores de dispositivos y cargas de datos de medición. No se deben compartir públicamente los archivos originales.

Consulta la [política de privacidad](../PrivacyPolicy.md) y la [guía de validación de HealthKit](../AppReviewHealthKit.md) para más detalles y procedimientos de autorización y validación.

## Tecnología y estructura del proyecto

Requiere iOS 17 o posterior y utiliza Swift, SwiftUI, Charts, CoreBluetooth, HealthKit, WidgetKit y CryptoKit. La interfaz, los cálculos de dominio, el análisis de protocolos y los servicios del sistema se separan por responsabilidad.

```text
ScaleMe/
├── App/              # Entrada, navegación, inicio y estado global
├── Core/             # Bases comunes como la localización
├── Domain/           # Modelos de dominio, cálculos y análisis de tendencias
├── Infrastructure/   # Bluetooth, persistencia, salud, diagnósticos y exportación a widgets
├── Features/         # Inicio, medición, tendencias, dispositivos y ajustes
├── Shared/           # Sistema de diseño y componentes compartidos
└── Resources/        # Assets, String Catalog y recursos de configuración
ScaleMeWidget/        # Widgets de tendencias para la pantalla de inicio
ScaleMeWidgetShared/  # Contratos de datos y almacenamiento compartidos entre app y widgets
Docs/                # Documentación de implementación y validación
└── readme/           # Traducciones completas del README
Tests/Smoke/         # Comprobaciones deterministas de protocolos, cálculos e idiomas
Tools/               # Herramientas de desarrollo y generación de recursos
```

Consulta [arquitectura e implementación](../Architecture.md) para las capas, transiciones de estado y el flujo de Bluetooth.

## Ejecutar el proyecto

1. Abre `ScaleMe.xcodeproj` con Xcode 26 o posterior y selecciona el scheme `ScaleMe`.
2. Ejecuta en el simulador y activa los datos simulados en Ajustes → Gestión de datos para explorar perfiles, dispositivos, registros y gráficos.
3. Para probar mediciones Bluetooth reales, configura un equipo de desarrollo, instala en un iPhone y permite Bluetooth al buscar dispositivos.
4. Para probar widgets, configura capacidades App Groups y Keychain Sharing coincidentes para la app y la extensión `ScaleMeWidget`.

El simulador y las pruebas automatizadas no sustituyen la validación de Bluetooth, HealthKit y cada modelo de báscula en dispositivos reales. Consulta [desarrollo y validación](../Development.md) para requisitos, comandos de compilación y puntos de entrada de pruebas.

## Documentación y contribuciones

- [Índice de documentación](../README.md)
- [Arquitectura e implementación](../Architecture.md)
- [Matriz de compatibilidad de protocolos](../BluetoothProtocolSupport.md)
- [Datos, sincronización y privacidad](../DataAndPrivacy.md)
- [Desarrollo y validación](../Development.md)
- [Convenciones de desarrollo para agentes](../../AGENTS.md)

El nombre chino es «观我»; el nombre inglés y el del proyecto Xcode son «ScaleMe». El logotipo de referencia está en [`Design/Logo/logo.svg`](../../Design/Logo/logo.svg). Las marcas de terceros describen compatibilidad o fuentes técnicas y no implican respaldo de sus fabricantes.

## Licencia

La distribución del código fuente del proyecto en conjunto utiliza **[GNU GPL v3 o posterior](../../LICENSE)** (`GPL-3.0-or-later`). Contribuciones originales: Copyright (C) 2026 bugwz. Las partes de terceros conservan sus derechos y licencias originales; consulta el [aviso del proyecto](../../NOTICE) y las [licencias y avisos de terceros](../../LICENSES/README.md).
