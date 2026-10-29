# Universal Camera Pro v12.5 · Cámaras por modo + animador de props

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

> Version estable: `v12.5.0`.
>
> Novedades v11: pestaña 🪑 Props (spawn por ID, mover con cámara, rotar,
> escalar, snap al suelo, colisión y persistencia), eliminación de opciones
> muertas (i18n, FunV6, MotionBlur, duplicados) y autosave real.

## Uso

Pega el contenido de `Loader.lua` en el entorno de ejecucion. El Loader
descarga las partes de `src/` desde GitHub raw y usa jsDelivr como fallback.
La version publicada apunta al tag `v12.5.0`.

Para probar una rama de desarrollo, cambia temporalmente:

```lua
local VERSION = "main"
```

Para una ejecucion reproducible, conserva un tag:

```lua
local VERSION = "v12.5.0"
```

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

## Clones locales (v12.4)

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

## Estructura del workspace

```text
Universal Camera/
├── Loader.lua                  # unico script que se pega en el juego
├── README.md
├── LICENSE.md
└── src/
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
    │   └── 36_clones.lua        # clones locales de jugadores (v12.4)
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
        ├── 00_registry.lua      # registro de builders y tabs de plugins
        ├── 90_builder.lua        # ventana, tabs y autosave
        └── tabs/                 # un builder por pestaña
```

## Orden de carga

El orden canonico esta en `Loader.lua`. Las carpetas organizan la propiedad
de cada dominio, pero no sustituyen el orden de dependencias de Luau:

```text
core → visuals → actors → props → camera → runtime/extensions
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
- UI: [Rayfield](https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua).
