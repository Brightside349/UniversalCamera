# Universal Camera Pro v10.5 · Reorganizacion de estructura

Camara libre cinematografica para Roblox con modos de camara, espectador,
Director, Replay Pro local, filtros, guias de composicion, Clean Shot,
escenas y herramientas locales para creadores.

> Version estable: `v10.5`.
>
> Esta version reorganiza el workspace por dominios sin cambiar el contrato
> principal: un Loader, carga secuencial y estado compartido en `_G.UCam`.

## Uso

Pega el contenido de `Loader.lua` en el entorno de ejecucion. El Loader
descarga las partes de `src/` desde GitHub raw y usa jsDelivr como fallback.
La version publicada apunta al tag `v10.5`.

Para probar una rama de desarrollo, cambia temporalmente:

```lua
local VERSION = "main"
```

Para una ejecucion reproducible, conserva un tag:

```lua
local VERSION = "v10.5"
```

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
    │   ├── 06_i18n.lua          # idiomas
    │   ├── 10_utils.lua         # helpers y cleanup transversal
    │   └── 90_init.lua          # persistencia, UI y Unload final
    ├── visuals/
    │   └── 20_filters.lua       # filtros y postprocesado
    ├── actors/
    │   ├── 30_fun.lua           # diversion, escala y efectos locales
    │   ├── 32_bodycolor.lua     # colores y materiales
    │   ├── 33_poses.lua         # poses y morphs
    │   └── 35_playermod.lua     # modificaciones locales a jugadores
    ├── camera/
    │   ├── 50_spectate.lua      # espectador
    │   ├── 55_replay.lua         # grabacion y reproduccion
    │   ├── 60_director.lua       # waypoints y director
    │   └── 70_camcore.lua        # nucleo de camara y render loop
    ├── presets/
    │   └── 57_profiles.lua      # perfiles completos
    ├── runtime/
    │   ├── 85_performance.lua  # diagnostico de frame budget
    │   ├── 88_v9extras.lua      # eventos, gamepad, escenas y timelapse
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
core → visuals → actors → camera → presets → runtime/extensions
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

- `v10.0.1`: ultima estructura anterior.
- `v9.0.0`: version V9.
- `v6.0.0`: primera modularizacion.

## Licencia y creditos

- Script original: Cocoa Feliz.
- UI: [Rayfield](https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua).
