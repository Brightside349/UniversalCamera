# Universal Camera Pro v13 · Interfaz WindUI

Camara libre cinematografica para Roblox con modos de camara, espectador,
Director, filtros, iluminacion, guias de composicion, Clean Shot, escenas,
**Props** locales por ID de asset, **Animador** con timeline de keyframes y
**Clones**: copias locales de cualquier jugador para grabar tomas con mucha
gente.

### v12.1

- Intensidad global del look entre 0% y 100%, aplicable a filtros built-in y custom.
- Intensidad de desenfoque cercano del DOF configurable.
- Guias exactas para 16:9, 9:16, 1:1 y 4:5 que se recalculan al redimensionar el viewport.
- Parche: la intensidad global tambien se respeta al seleccionar filtros custom.

### v12.2

- Shot Builder integrado al Director: Dolly In/Out, Orbit, Crane y Reveal.
- Las plantillas generan waypoints editables y no comienzan la reproducción automáticamente.

### v12.3

- Biblioteca local de tomas con nombre, descripción, duración y rutas editables.
- Preparación de captura con cuenta atrás configurable.
- Ocultación opcional de guías durante la toma y restauración del estado anterior.

### v12.4

- Clones locales de jugadores: copia a cualquiera las veces que quieras, sin
  contar para el límite de jugadores de la partida y sin enviar nada al servidor.
- Los clones copian movimiento, saltos y emotes en tiempo real, con modos
  "Seguir movimiento" y "Fijar en el sitio".
- Colocación con clic en el mapa, snap al suelo, rotación y formaciones
  (cuadricula, fila, circulo) al clonar.

### v12.5

- **Inicio** sin "Recuperacion V10" ni "Acciones rapidas". El HUD tiene un solo
  comportamiento: se oculta al activar la camara libre y vuelve al salir, con un
  toggle manual para ocultarlo sin cámara libre.
- **Cámaras** muestra solo los controles del modo elegido y añade el modo
  **Personalizada** (distancia, altura, giro, inclinacion, sway, roll y FOV).
- **Espectador** y **Cinematografico** unificados: encuadre condicional, un solo
  boton de shake y Director condensado.
- **Filtros** sin la parrilla de 30 botones; **Iluminacion** con presets en
  selectores.
- **Estudio** mejorado: croma unificado, rotacion y ajuste automatico al encuadre.
- **Props** con empuje por ejes y duplicado. Nueva pestaña **Animador**:
  timeline de keyframes para animar props en conjunto o por separado, con
  duracion, easing, loop, reproduccion y tecla rapida.
- **Diversion** y **Cuerpo** unificados.
- Eliminadas las pestañas **Poses**, **Mod Jugadores**, **Replay**, **Perfiles**
  y **Demo** (y su estado, persistencia y referencias).

### v12.6

- **Clones**: el espejo de movimiento ya no copia a 60 Hz. Se limita a la tasa
  elegida (60/30/20), solo escribe las partes que cambiaron, agrupa todas las
  escrituras en un `BulkMoveTo` por tick y actualiza menos a los clones lejanos
  (LOD por distancia, configurable).
- Los clones llevan el **Humanoid apagado**, sin `Animator`, sin colisión, sin
  raycast, sin eventos de toque y con sombras opcionales: menos trabajo por
  personaje sin cambiar su aspecto.
- Nueva sección **Rendimiento** en la pestaña Clones con tasa del espejo,
  distancia de detalle, sombras, Humanoid y un botón **Ver coste actual**
  (clones, partes, CFrames/s y si el lote está activo).

### v12.6.1

- Corregido el error `table index is nil` en el espejo de clones: el jugador de
  origen no se guardaba al crear cada clon, así que la caché de inversas
  fallaba en cada tick.
- Efecto secundario arreglado: los clones vuelven a mostrar el nombre del
  jugador en la lista, se borran correctamente al liberar el seguimiento y se
  reconstruyen solos cuando el original respawnea.

### v12.7

- **Diseño capturado en los clones**: cada clon guarda el modelo que tenía el
  jugador al crearlo. Si el juego permite cambiar de personaje con su propio
  panel (por ejemplo 10 diseños y 7 cupos), el clon sigue mostrando el diseño
  viejo y aun así copia el movimiento del personaje nuevo.
- El emparejamiento de partes es por **rol de rig** (cabeza, torso, brazos,
  piernas) en vez de por ruta exacta, así que funciona aunque el jugador pase
  de R6 a R15, de R15 a R6 o a un modelo con otro orden de partes. Las piezas
  sin equivalente se mueven rígidas junto a su parte de apoyo.
- Toggle **Conservar diseño capturado** y botones para recapturar el diseño del
  clon seleccionado o de todos.
- **Cuerpo** acepta clones como objetivo: aparecen en la lista como
  `Clon 03 · Nombre` y se les aplica color, material, transparencia, HEX,
  presets y restaurar igual que a un jugador.

### v12.8

- **Cinematografico → Director: ir a un waypoint**: vuelve el salto individual
  que se habia perdido al simplificar la pestaña. Lista de waypoints, boton
  **🎯 Ir al waypoint seleccionado** y botones **◀ anterior / siguiente ▶**
  que recorren la ruta de uno en uno con ciclo.
- El salto no reproduce la ruta: detiene el Director si estaba activo, entra en
  camara libre y deja el encuadre exacto del waypoint para ajustarlo a mano
  (aplica FOV y roll cuando esos toggles estan activos).
- La lista se refresca al guardar, deshacer o limpiar waypoints, y se
  autocorrige cuando la seleccion ya no existe.

### v12.9

- **FOV y zoom con la rueda arreglados en camara libre** y auditados en los 17
  modos. El valor se aplica al instante (mitad del recorrido en el mismo frame)
  en vez de depender de que corra el suavizado, y la rueda se atiende antes del
  filtro de "evento procesado" de Roblox, que era lo que la anulaba.
- Elegir un modo en el selector **enciende de verdad** ese modo (antes solo
  cambiaba la etiqueta y `updateCamera` salia sin hacer nada).
- **Personalizada** y **Vertigo** conservan la rueda: mueve su FOV propio en vez
  de perderse al frame siguiente.
- Pestaña **Camaras → Lente**: nuevos controles *Zoom con la rueda* y
  *Grados por muesca* (1-10).

### v13

- **Nueva interfaz sobre WindUI** (MIT, `1.6.66` vendorizado en `src/lib/`):
  tema propio, barra lateral agrupada en 5 secciones (Camara, Escena,
  Personajes, Creacion, Sistema), **buscador integrado**, iconos Lucide en vez
  de emojis y **imagen de fondo** configurable (`rbxassetid://8741056068`).
- Las 16 pestañas y sus 527 controles **no cambiaron de codigo**: un adaptador
  (`ui/05_adapter.lua`) traduce la API anterior a WindUI.
- **Ajustes → Tema de UI** con cuatro temas (UCam Pro, Claro, Aqua, Amatista),
  **Imagen de fondo de la UI** y **Opacidad de la imagen** de 0% a 100%
  (sustituyen al "Modo compacto", que no aplicaba nada).
- **Boton flotante solo para moviles** para abrir la UI sin teclado.
- Los paneles por modo de **Camaras** y **Espectador** ahora se ocultan por
  `ElementFrame` en vez de escarbar el arbol de la GUI: ya no dependen de
  nombres internos de la libreria.
- La libreria se carga con version fija y copia local, asi que una actualizacion
  de la UI no puede romper el script a mitad de partida.
- Clean Shot oculta la UI por su propia API (`UCam.UI.setVisible`) y `Unload`
  destruye las cuatro ScreenGui de WindUI antes de recargar.

### v13.0.1

- Corregido el fallo que dejaba el script **sin interfaz** al arrancar
  (`[string "windui"]:15482: attempt to index nil with 'Value'`): el gradiente
  del tema propio se llamaba con punto en vez de dos puntos, así que la librería
  recibía los argumentos desplazados y no encontraba ni un punto de color.
- Instalar los temas ya no puede tumbar la ventana: un fallo de color o de
  gradiente se registra en el log y el tema cae a un color plano.
- Elegir un tema que no exista ya no viaja hasta `CreateWindow` como `nil`: se
  usa `Dark` y se avisa en la consola.
- El mensaje final del Loader muestra la versión real que se cargó.

### v13.1

- **Imagen de fondo arreglada**: el tema propio se instala en cuanto se pide
  (la configuracion se aplica antes de que exista la ventana, asi que antes se
  quedaba en `Dark`, con el panel opaco tapando la foto) y el fondo se aplica
  al abrir la ventana, no solo al tocar Ajustes. Opacidad por defecto 65 %.
- **Buscador sin tirones**: agrupa la busqueda mientras escribes en vez de
  reconstruir la lista de resultados en cada tecla (causa de los bajones de FPS).
- **Inicio** abre con un bloque de bienvenida: version, tecla `Delete`, como
  funciona la barra lateral y donde estan el tema y el fondo.

### v13.2

- **Arranque sin tirones**: las 16 pestañas ya no se rellenan de golpe. Se crean
  vacías y el contenido se construye la primera vez que abres cada una, así que
  el pico de ~7 s del arranque desaparece. El buscador integrado, en cambio, solo
  encuentra controles de pestañas que ya hayas abierto.
- **Fondo más presente**: opacidad por defecto al 85 % (las configuraciones
  guardadas con el 50 % se migran una sola vez) y panel al 50 % de transparencia
  en los cuatro temas, para que la imagen se vea detrás de los controles.
- El log de arranque imprime `UI lista en N ms` y el aspecto real aplicado
  (tema, transparencia del panel e imagen con su transparencia).

> Version estable: `v13.2.0`.
>
> Novedades v11: pestaña 🪑 Props (spawn por ID, mover con cámara, rotar,
> escalar, snap al suelo, colisión y persistencia), eliminación de opciones
> muertas (i18n, FunV6, MotionBlur, duplicados) y autosave real.

## Uso

Pega el contenido de `Loader.lua` en el entorno de ejecucion. El Loader
descarga las partes de `src/` desde GitHub raw y usa jsDelivr como fallback.
La version publicada apunta al tag `v13.2.0`.

Para probar una rama de desarrollo, cambia temporalmente:

```lua
local VERSION = "main"
```

Para una ejecucion reproducible, conserva un tag:

```lua
local VERSION = "v13.2.0"
```

## Interfaz (v13)

- `Delete` abre/cierra la ventana. En movil aparece un **boton flotante**
  ("Universal Camera") porque no hay teclado.
- La barra lateral agrupa las pestañas en **Camara / Escena / Personajes /
  Creacion / Sistema** y el **buscador** filtra controles de todas ellas.
- **Ajustes → Tema de UI**: UCam Pro, Claro, Aqua y Amatista.
- **Ajustes → Imagen de fondo de la UI** (on/off) y **Opacidad de la imagen**
  (0%-100%) controlan el fondo `rbxassetid://8741056068`.
- Los controles conservan los nombres y valores de v12: la configuracion
  guardada se sigue cargando igual, y los plugins que usan
  `Window:CreateTab` siguen funcionando.

## Props locales (v11)

1. Abre la pestaña **🪑 Props**, pega el ID del asset (mesh/modelo) y colocalo.
2. Todo se crea en tu cliente: **nadie mas lo ve** y no se envia al servidor.
3. Muevelo con **Mover con camara** (rueda = acercar/alejar), **Colocar donde
   miro** (raycast) o **Apoyar en el suelo**.
4. Empuja por ejes, rota en yaw/pitch/roll, escala 0.1x–20x, duplica y activa
   colision si lo necesitas.
5. Los props se guardan en tu config por juego y **reaparecen solos** la
   proxima sesion. `Eliminar TODOS` los borra y tambien limpia el guardado.

## Animador de props (v12.5)

1. Coloca y posiciona los props que quieras animar.
2. Abre **🎬 Animador** y elige el alcance: `Todos` (conjunto) o
   `Prop seleccionado` (cada uno con su propio ritmo).
3. Mueve el slider de tiempo, mueve los props a la pose deseada y pulsa
   **Guardar keyframe**. Repite para cada momento.
4. Ajusta duracion, easing y loop, y pulsa **Reproducir** (o la tecla `P`).
   `Volver al inicio` devuelve los props a la primera pose.

La animacion vive en la sesion actual; los props en si siguen guardandose.

## Clones locales (v12.7)

1. Abre la pestaña **👥 Clones** y elige a quien clonar (tu o cualquier jugador).
2. Ajusta cantidad, formacion y separacion, y pulsa **Clonar jugador**.
   El tope por partida (por ejemplo 8 jugadores) no aplica: los clones son
   locales, **nadie mas los ve** y no se envían al servidor.
3. **Seguir movimiento** copia caminar, saltar y emotes desplazando el clon
   igual que el original. **Fijar en el sitio** reproduce la pose pero deja
   al clon quieto donde lo pusiste.
4. Activa **Colocar con clic en el mapa**, selecciona un clon en la lista y
   haz clic sobre el suelo para moverlo ahi. Tambien puedes usar
   **Colocar donde miro**, **Apoyar en el suelo** y girar ±15°.
5. Si el jugador original respawnea, sus clones se reconstruyen solos en la
   misma posicion. `Eliminar TODOS` los borra de tu cliente.
6. **Diseño capturado**: con `Conservar diseño capturado` activo, el clon
   mantiene el modelo con el que se creó aunque el jugador cambie de personaje
   en el panel del juego, y sigue copiando su movimiento. Los clones también
   se pintan desde la pestaña **Cuerpo** (`Clon 03 · Nombre`).
7. Con muchos clones, abre **Rendimiento**: baja la tasa del espejo a 20/s,
   reduce la distancia de detalle, desactiva sombras y pulsa **Ver coste
   actual** para ver cuantas partes se estan moviendo realmente. El coste que
   queda es de dibujado: cada clon sigue siendo un personaje completo.

## Estructura del workspace

```text
Universal Camera/
├── Loader.lua                  # unico script que se pega en el juego
├── README.md
├── LICENSE.md
└── src/
    ├── lib/
    │   ├── 00_windui.lua        # carga de WindUI (copia local + fallbacks)
    │   └── windui.lua           # libreria vendorizada 1.6.66 (MIT)
    ├── core/
    │   ├── 00_config.lua       # namespace, servicios y estado base
    │   ├── 05_persistence.lua  # guardado, carga, export e import
    │   ├── 10_utils.lua         # helpers y cleanup transversal
    │   └── 90_init.lua          # persistencia, UI y Unload final
    ├── visuals/
    │   └── 20_filters.lua       # filtros y postprocesado
    ├── actors/
    │   ├── 30_fun.lua           # diversion, escala y efectos locales
    │   ├── 32_bodycolor.lua     # colores y materiales
    │   └── 36_clones.lua        # clones locales, espejo optimizado y diseño (v12.7)
    ├── camera/
    │   ├── 50_spectate.lua      # espectador
    │   ├── 60_director.lua      # waypoints y director
    │   └── 70_camcore.lua       # nucleo de camara y render loop
    ├── props/
    │   ├── 45_props.lua         # props locales por ID de asset (v11)
    │   └── 46_propsanim.lua     # timeline de keyframes (v12.5)
    ├── runtime/
    │   ├── 85_performance.lua  # diagnostico de frame budget
    │   ├── 88_v9extras.lua      # eventos, gamepad y escenas
    │   └── 89_v10extras.lua     # captura, guias y recovery
    ├── extensions/
    │   └── 85_plugins.lua       # API y carga de plugins
    └── ui/
        ├── 05_adapter.lua        # adaptador a WindUI (API estilo Rayfield)
        ├── 00_registry.lua      # registro de builders y tabs de plugins
        ├── 90_builder.lua        # ventana, tabs y autosave
        └── tabs/                 # un builder por pestaña
```

## Orden de carga

El orden canonico esta en `Loader.lua`. Las carpetas organizan la propiedad
de cada dominio, pero no sustituyen el orden de dependencias de Luau:

```text
core/00_config → lib (WindUI) → ui/05_adapter → core (resto)
     → visuals → actors → props → camera → runtime/extensions
     → ui/00_registry → ui/tabs → ui/90_builder → core/90_init
```

Cada modulo puede usar APIs publicas de modulos anteriores y debe exponer
solo lo que otros modulos necesitan bajo `UCam`.

## Reglas para futuras features

1. Coloca la logica en el dominio que la posee.
2. Crea el estado inicial en `core/00_config.lua` o en su estado de dominio.
3. Publica una API pequena en `UCam`.
4. Registra conexiones con `UCam.trackConnection` e instancias con
   `UCam.trackInstance`.
5. Anade serializacion en `core/05_persistence.lua` si debe sobrevivir.
6. Anade controles en `ui/tabs/`, sin poner logica de runtime en la UI.
7. Anade el archivo al `ORDER` del Loader en su posicion correcta.
8. Prueba activacion, desactivacion, respawn, recarga y `Unload()`.

Los helpers privados deben permanecer como `local function`. Los loops por
frame deben tener un unico propietario y un objetivo medible.

## Plugins

Los plugins pueden registrar una pestaña mediante:

```lua
UCam.registerTabBuilder("mi_tab", function(Window)
    local Tab = Window:CreateTab("Mi tab", "star")
    -- controles del plugin
end)
```

La API se registra en `ui/00_registry.lua` antes de cargar
`extensions/85_plugins.lua`. Las pestañas se construyen en
`ui/90_builder.lua`.

## Versiones anteriores

Los tags historicos permanecen disponibles en Git:

- `v10.5`: estructura por dominios + Creator tools.
- `v10.0.1`: ultima estructura anterior.
- `v9.0.0`: version V9.
- `v6.0.0`: primera modularizacion.

## Licencia y creditos

- Script original: Cocoa Feliz.
- UI: [WindUI](https://github.com/Footagesus/WindUI) 1.6.66 de Footagesus,
  licencia MIT. Copia vendorizada en `src/lib/windui.lua`; no se modifica.
